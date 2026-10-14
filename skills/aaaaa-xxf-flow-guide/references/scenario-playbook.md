# RxStyle Flow 场景手册

先按业务目标选场景，再组合共同规则。示例 package 来自参考实现；若目标工程版本/import 不同，先查当前源码。除特别说明外，示例都应显式处理 `onError`。

扩展场景：完整 import 的搜索状态链、串行写入、缓存策略、两种轮询时钟和原生 Flow 能力边界见 [响应式设计与组合](reactive-design.md)；逐项函数行为见 [操作符参考](operator-reference.md)。本页未给 import 的片段需按 [API 包索引](api-catalog.md) 导入；repository/render 等为业务占位，不是库 API。

## 场景索引

| 场景 | 推荐路径 | 取消方式 |
|---|---|---|
| 一次性同步值/本地计算 | `Flows.just/fromCallable` → `subscribe` | 自然完成；需中途停才保存 disposable |
| 一次性阻塞 IO | `fromCallable` → `subscribeOn(io)` → UI `observeOn(main)` | disposable 或 Lifecycle AutoDispose |
| 挂起数据源/原生 Flow | 保持 native Flow 或进入 RxStyle adapter | 根据 cold/hot source 选择 collect / disposable |
| 连续状态、数据库、网络事件 | Flow/StateFlow source → Rx operator → subscribe | Lifecycle、容器或明确 owner |
| callback/listener SDK | `Flows.fromCallback` | 收集结束后 `unregister` |
| Activity/Fragment 页面订阅 | `to(autoDisposable(owner))` | owner 到指定事件后 dispose |
| View attach 区间订阅 | `bindLifecycle(view)` | View detach；注意初始未 attach 策略 |
| ViewModel/服务 Scope 订阅 | 核心 `autoDisposable(scope)` | Scope Job 结束时 dispose |
| 一组订阅一起管理 | `CompositeFlowDisposable` | `clear` 或 `dispose` |
| 替换轮询/搜索任务 | `SerialFlowDisposable` 或 `switchMap` | 替换时按 set/replace 语义释放 |
| 错误恢复、有限重试 | `onErrorResumeNext` / `retry(times, predicate)` | 终止后自然释放或外部 dispose |
| 计时、节流、多个流组合 | 时间/gate/combine operator | Disposable / lifecycle；测试用 scheduler |

## 1. 一次性值或同步计算

适合常量、内存映射和短小同步逻辑。不需要为了“响应式”强制增加 scheduler：

```kotlin
Flows.just(user)
    .map(::toUiModel)
    .subscribe(::render, ::showError)
```

source 是 cold 的，每次 `subscribe` 都会重新执行。同步有限 source 可能在 `subscribe` 返回前就触发 callback。若调用方需要在结束前取消，保存返回的 `FlowDisposable`。

## 2. 一次性阻塞 IO / 请求

阻塞 callable 默认仍运行在订阅线程；明确把上游放到 IO，通知 UI 前再切 Main：

```kotlin
Flows.fromCallable { repository.loadUser(userId) } // 若 loadUser 是阻塞函数
    .subscribeOn(Schedulers.io())
    .map(::toUiModel)
    .observeOn(AndroidSchedulers.mainThread())
    .subscribe(
        onNext = ::render,
        onError = ::showError,
        onComplete = ::hideLoading
    )
```

如果 repository 已返回挂起结果，可在 `fromCallable` 的 suspend lambda 中调用；若它已返回 Flow，直接从那个 Flow 构造链路，不要把 Flow 本身误当结果值。`fromCallable` 的 callback 类型允许 suspend，但这不代表它自动切 IO。

页面销毁前请求不应再更新 UI 时，使用第 6 节的 AutoDispose 模式；不绑定 UI 的后台调用则由 owner 保存并 dispose。

## 3. 挂起函数和原生 Flow 互操作

Kotlin 协程代码若主要需要 suspend operator 和结构化并发，可保持 native Flow：

```kotlin
repository.observeUser(userId)
    .map { user -> toUiModel(user) }
    .collect { model -> render(model) }
```

当调用点明确需要本库的非 suspend Observer/Disposable 终端 API 时，再让 Flow 进入 RxStyle 链：

```kotlin
repository.observeUser(userId)
    .map { user -> toUiModel(user) }
    .subscribeOn(Schedulers.io())
    .observeOn(AndroidSchedulers.mainThread())
    .subscribe(::render, ::showError)
```

优先在进入 RxStyle 前处理 `Flow<T?>` 的 null。进入 RxStyle 的 source/output 受 `T : Any` 限制。不要把原生 `collect` 和本库 `subscribe` 混为同一套生命周期或错误协议。

## 4. 连续状态流 / 数据库 / 服务事件

适合 `StateFlow`、Room Flow、连接状态、进度或监听数据。决定重放语义、重复值策略和 owner：

```kotlin
repository.observeStatus()
    .distinctUntilChanged()
    .observeOn(AndroidSchedulers.mainThread())
    .to(autoDisposable(viewLifecycleOwner))
    .subscribe(::renderStatus, ::showError)
```

如果上游已是 hot shared flow，订阅不会令其冷化；订阅者从订阅时开始接收，具体是否有 replay 由上游配置决定。若要仅在页面可见时接收，选合适 Lifecycle 结束点，并记住一次 AutoDispose 结束后不会自己恢复。

## 5. 将 callback API 转为数据流

`Flows.fromCallback` 的 register/unregister 都按一次订阅配对。下例假定 SDK 的 listener API 接受并回调 `FlowCallback`；实际 SDK 签名不同就按其注册契约适配：

```kotlin
val eventFlow = Flows.fromCallback<Event>(
    register = { callback -> sdk.register(callback) },
    unregister = { callback -> sdk.unregister(callback) }
)

eventFlow
    .observeOn(AndroidSchedulers.mainThread())
    .subscribe(::renderEvent, ::showError)
```

注册期间抛出的错误会成为该订阅的错误；取消/结束会执行 unregister。异步失败必须通过 `callback.onError(error)`，不能在外部 callback 线程直接 throw。参考实现 `onNext` 内部使用 `trySend`，但不暴露发送结果；默认 callback buffer 满时可能丢事件，需检查来源速率与消费能力。若业务不能接受丢事件，应设计有界流控/暂停生产方案，或改用可处理发送结果的适配层。另需处理重复 terminal 与取消后的迟到事件。

顺序生成值可用 `Flows.create { emit(value) }`；它接收 suspend `FlowCollector` block，不是可跨线程并发调用的 Rx emitter。并发 callback 不要捕获 collector 后在任意线程直接 emit。

## 6. Activity / Fragment / 页面 Lifecycle

### 页面销毁时结束

```kotlin
repository.observePageData()
    .subscribeOn(Schedulers.io())
    .observeOn(AndroidSchedulers.mainThread())
    .to(autoDisposable(viewLifecycleOwner))
    .subscribe(::render, ::showError)
```

默认结束事件是 `ON_DESTROY`。Fragment 的 View 相关订阅通常使用 `viewLifecycleOwner`，避免绑定到 Fragment 对象生命周期而长于 View。数据 callback 线程仍由 `observeOn` 决定。

### 页面离开前台时结束

```kotlin
repository.observeVisibleData()
    .observeOn(AndroidSchedulers.mainThread())
    .to(autoDisposable(viewLifecycleOwner, Lifecycle.Event.ON_STOP))
    .subscribe(::render, ::showError)
```

`ON_STOP` 结束后该订阅已取消；页面重新 `ON_START` 时此链不会自动重建。需要恢复就由页面状态/启动入口再次创建订阅，并避免重复订阅泄漏。`ON_ANY` 不能用作 until event。

如果只是某些 Lifecycle 状态不显示数据但后台仍继续处理，使用 `filterWhen(owner, Lifecycle.State.STARTED)` 等过滤 API；它只过滤 onNext，不停止 upstream。

## 7. View attach / detach 区间

```kotlin
viewEvents
    .observeOn(AndroidSchedulers.mainThread())
    .bindLifecycle(view, checkAttached = true)
    .subscribe(::render, ::showError)
```

默认 `checkAttached = true`：订阅建立时 View 已 detach，会按 outside-scope 处理，不启动 upstream。若要先订阅后 attach 并等待之后的 detach，可评估 `checkAttached = false`。listener 注册和 ready 握手在 Main；它不会把数据通知改到 Main。

订阅前 converter（`.to(autoDisposable(view))`）提供订阅时 listener-ready 屏障。把已经创建的 `FlowDisposable` 再 `.bindLifecycle(view)` 是订阅后包装，不能提供相同的建立前屏障；它还需要调用方保存包装后的返回句柄以便主动移除 listener。

## 8. ViewModel、Service 或 SDK Scope

核心层可以用带 Job 的 `CoroutineScope` 作为结束信号。Android ViewModel 可以直接绑定 ViewModel，也可以将 `viewModelScope` 交给静态 facade：

```kotlin
// RxStyle Flow 扩展：ViewModel.onCleared 后自动取消本次订阅
source
    .subscribeOn(Schedulers.io())
    .bindLifecycle(this)
    .subscribe(::updateState, ::reportFailure)

// Java/静态调用风格，适合手动组装 converter
source.to(FlowLifecycle.bindLifecycle(viewModelScope))
    .subscribe(::updateState, ::reportFailure)
```

也可以直接使用核心 AutoDispose converter：

```kotlin
source
    .subscribeOn(Schedulers.io())
    .to(autoDisposable(viewModelScope))
    .subscribe(::updateState, ::reportFailure)
```

Scope 适配只读取其中 Job 的完成信号，不借用它的 dispatcher 来调度 RxStyle 数据链。若要 Main 通知，仍然使用 `observeOn`。选择 scope 时确认它的 Job 生命周期正好覆盖订阅；不要把过长的 application scope 误当页面 scope。

没有生命周期 Scope 的 SDK/manager 用 `CompositeFlowDisposable` 并在 close/shutdown 时释放。不要为省略 disposable 管理而引入全局共享 Scope。

## 9. 手动取消一个或多个任务

### 一个可取消任务

```kotlin
private var request: FlowDisposable? = null

fun load() {
    request?.dispose()
    request = Flows.fromCallable { repository.load() }
        .subscribeOn(Schedulers.io())
        .subscribe(::render, ::showError)
}

fun cancel() {
    request?.dispose()
    request = null
}
```

如果想原子替换旧句柄，可持有 `SerialFlowDisposable`；`set(next)` 会释放旧任务，`replace(next)` 不释放旧任务。避免两者语义选错。

### 一组独立订阅

```kotlin
private val bag = CompositeFlowDisposable()

fun observe() {
    bag.add(flowA.subscribe(::renderA, ::showError))
    bag.add(flowB.subscribe(::renderB, ::showError))
}

fun disposeAll() = bag.dispose()
```

短暂重用的 owner 可在一轮后 `clear()`；owner 永久关闭时用 `dispose()`。用 Android `collectTo` / `bindDisposableContainer` 扩展时，查对应 Android 模块并确认目标容器的结束责任。

## 10. 错误、fallback 和有限重试

### 按错误恢复

```kotlin
source
    .onErrorResumeNext { error ->
        if (error is CacheableFailure) cache.asFlow()
        else Flows.error(error)
    }
    .subscribe(::render, ::showError)
```

`onErrorReturn` 用替代的非空值后正常完成；`onErrorResumeNext` 换备用流；`onErrorComplete(predicate)` 按 predicate 是否接受来吞错完成。只对业务认可的错误降级，程序错误要继续暴露。

### 有限重试

```kotlin
source
    .retry(times = 2) { error -> error is IOException }
    .subscribe(::render, ::showError)
```

最多重试 2 次，最多尝试 3 次。此 API 不隐含退避；需要延时、随机抖动或服务端 Retry-After 时，应显式构造策略并确认库中实际操作符可表达。不要对非幂等请求无条件无限重试。

### 全局兜底

不带 `onError` 的订阅调用 `FlowPlugins`。局部业务仍优先传 `onError`；全局 handler 只承担集中兜底/诊断，并确保测试或临时替换后恢复原状态。

## 11. 动态 inner 流：switchMap 与 concatMap

输入值来了就立即换成最新请求、旧请求过期时用 `switchMap`：

```kotlin
queryFlow
    .map(String::trim)
    .filter(String::isNotEmpty)
    .switchMap { query -> repository.search(query) }
    .observeOn(AndroidSchedulers.mainThread())
    .subscribe(::renderResults, ::showError)
```

当前实现会在新 outer 值到来时 dispose 上一个 inner。concatMap 的 transform 在 outer 到达时同步执行，只把返回的 inner 排队；副作用必须放在惰性 inner 内。适合搜索输入或选择变化。若每个请求都必须执行且按顺序完整输出，选择 `concatMap`；它逐个订阅 inner，不允许并发交错，outer 值可能排队等待。核对输入速率和队列增长，不要把两者交换。

## 12. 多源组合、先后顺序与 gate

| 需求 | 操作符 | 发射触发点 |
|---|---|---|
| 任一 source 更新就用双方最新值计算 | `combineLatest` | 两路各有首值后，任一路更新 |
| 主 source 发值时附带另一路最近值 | `withLatestFrom` | 只由主 source 触发；other 尚无值时跳过主值 |
| 按位置成对配对 | `zipWith` | 两侧各有一个值时输出一对 |
| gate 打开前跳过主流 | `skipUntil(other)` | other 首次值或正常完成打开 gate；other 错误终止链路 |
| other 触发后停止主流 | `takeUntil(other)` | other 首次值或正常完成停止；other 错误终止链路 |
| 一个值达到条件后停止 | `takeUntil(predicate)` | 当前实现先发送该值，再检查 predicate |
| 顺序追加 source | `concatWith` | 当前 source 完成后订阅另一条 |
| 同时合并 source | `mergeWith` | 来源值交错到达，顺序不应假设固定 |

确认哪条流是触发源，以及空完成/错误意味着什么。`combineLatest`、`withLatestFrom` 等核心函数在资料版本中允许 suspend transform；其他同名 operator 不应因此被推断为支持 suspend。

## 13. 定时、延迟、节流与防抖

```kotlin
Flows.intervalRange(
    start = 1L,
    count = 5L,
    initialDelay = 0.seconds,
    period = 1.seconds
)
    .subscribe(::renderTick, ::showError)
```

```kotlin
queryChanges
    .throttleWithTimeout(300.milliseconds) // debounce/timeout 语义
    .switchMap(repository::search)
    .observeOn(AndroidSchedulers.mainThread())
    .subscribe(::renderResults, ::showError)
```

`timer` 延迟后发出一次 `0L` 并完成；`interval(period)` 第一项在一个 period 后；`interval(initialDelay, period)` 可分别指定首延迟和周期。`throttleFirst` 保留窗口第一个值；`throttleLast` 是周期 sample，参考实现默认不补发窗口末尾遗留项；`throttleWithTimeout` 对应 debounce/timeout 行为。时间 operator 可有 scheduler 重载，生产测试优先使用可控 Scheduler，不靠真实等待。

防抖期间旧请求可能继续返回；该例中的 repository.search 必须是同步返回 Flow 的函数，而非 suspend 返回结果。若要求原始输入一变化就取消旧请求，使用 [搜索状态示例](reactive-design.md#可编译的搜索链路) 的 switchMap + timer 模式。单次失败需在 inner 内恢复，才能继续响应下一次查询。

持续 interval 需要明确释放：保存 `FlowDisposable`、放入 Composite，或绑定到生命周期。不得把 `timer` 与 `interval` 的完成行为混为一谈。

## 14. 创建与释放成对的资源

```kotlin
Flows.using(
    resourceFactory = { openSession() },
    flowFactory = { session -> session.events() },
    disposer = { session -> session.close() }
)
    .subscribe(::render, ::showError)
```

每次收集时创建 resource，完成、异常或取消都会执行同步 disposer。清理逻辑应可安全调用；若 source 和 disposer 都失败，错误会组合。耗时或必须挂起的清理不要假设这个同步 disposer 能 suspend。

## 15. 测试、阻塞读取与调度验证

- 终端回调、错误、完成、dispose 语义：用 `subscribe` 捕获事件顺序并断言取消后不再收到信号。
- Scheduler 和时间算子：用库测试里的 `TestFlowScheduler` / 可控 Scheduler 推进虚拟时间；避免真实 sleep。
- callback 注册清理：分别断言注册、正常完成、错误、dispose 路径的 unregister 次数。
- 多源组合：覆盖无首值、空完成、错误和取消竞态。
- `blockingFirst/Last/ForEach/Subscribe` 仅用于允许阻塞的测试/后台线程，Android 主线程绝不可调用。

测试 scheduler API 要从当前版本源码读取；不要自行编造 `advanceTimeBy` 等测试方法。

## 16. 常见误用与诊断

| 表现 | 先检查 | 修正方向 |
|---|---|---|
| 阻塞导致卡 UI | 是否缺少 `subscribeOn(io)` | 在订阅前明确安排上游；Main 只承载 UI 工作。 |
| callback 更新 UI 崩线程 | 是否缺少 `observeOn(main)` | 在 UI observer 前添加 Main 边界。 |
| 页面退出仍收到回调 | AutoDispose 是否放在链末端且绑对 owner；是否其实只用 filter | 使用正确 Lifecycle/View scope；filter 只屏蔽值，不取消 source。 |
| 返回页面后不再更新 | 一次订阅已在 ON_STOP/结束事件被取消 | 在新 active 周期重新组装/订阅；AutoDispose 不负责 restart。 |
| 错误没有进 callback | 是否选了无 `onError` 重载 | 提供 `onError`，或检查 `FlowPlugins`。 |
| 操作符 callback 无法调用 suspend | 当前 receiver 解析到了 RxFlow operator | 看签名；先在 native Flow 阶段挂起处理或选明确支持 suspend 的 API。 |
| nullable 泛型不通过编译 | 是否将 `Flow<T?>` 直接交给 RxStyle | 进入 RxStyle 前过滤/映射为非空。 |
| 连续操作符行为变了 | 中间变量是否把 `RxFlow` 收窄到 `Flow`；是否 import 了 kotlinx 同名扩展 | 检查每步静态类型与 import。 |
| 慢消费者后内存增长/数据缺失 | `observeOn` 队列或 callback 缓冲是否跟不上 | 用节流/合并/限速或有界生产策略；确认业务是否允许丢弃。 |
| 重试仍重复失败/重复副作用 | `times` 是否理解为额外重试次数；source 是否 cold/非幂等 | 限制错误类别与次数，评估副作用幂等性和退避。 |

## 17. RxJava 迁移核对

将 Observable 链逐段迁移，逐项记录 source、operator、scheduler、terminal callback、Disposable 所有者和 lifecycle。常见映射：

| RxJava API | 本库方向 | 迁移提醒 |
|---|---|---|
| `Observable.just/defer/fromCallable` | `Flows.just/defer/fromCallable` | defer/callable 每次订阅重新计算；just 的参数在搭链前已求值；callable 不自动切 IO。 |
| `subscribe` | Flow 扩展 `subscribe` | 非 suspend，返回 disposable；Observer overload 交付取消句柄。 |
| `Disposable` | `FlowDisposable` | dispose 不发 complete。 |
| `CompositeDisposable` | `CompositeFlowDisposable` | 区分可重用 `clear` 与永久 `dispose`。 |
| `SerialDisposable` | `SerialFlowDisposable` | 区分会取消旧值的 `set` 和不取消的 `replace`。 |
| `subscribeOn/observeOn` | 同名 scheduler operator | 分别定义 source 订阅和下游通知，不互换。 |
| RxAndroid Main | `AndroidSchedulers.mainThread()` | Android-only 模块，显式放到 UI 回调之前。 |
| AutoDispose | `to(autoDisposable(...))` | 生命周期结束只取消，不自动重订阅。 |
| `Observable.create` | `Flows.create` 或 `fromCallback` | collector 顺序 suspend emit 与跨线程回调不是同一种 source。 |
| `Flowable` | 没有直接等价保证 | 重新设计背压/缓存/丢弃策略。 |

迁移结果要以业务行为对照，不是只让 Kotlin 编译通过。若要求严格 RxJava 一致，指定 RxJava 版本并比较值、terminal、线程和 dispose 行为；本库 README 明确 operator 覆盖不是完整的 RxJava 1:1 实现。
