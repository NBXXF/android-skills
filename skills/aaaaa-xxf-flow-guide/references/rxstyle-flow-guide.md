# RxStyle Flow 核心概念与使用指南

本文整理核心订阅模型、线程/错误语义和 RxJava 迁移边界。业务场景示例在 [场景手册](scenario-playbook.md)，完整扩展名与签名目录在 [API 目录](api-catalog.md)。

## 目录

- [资料范围与核对原则](#资料范围与核对原则)
- [心智模型](#心智模型)
- [订阅生命周期](#订阅生命周期)
- [线程与调度](#线程与调度)
- [错误与取消协议](#错误与取消协议)
- [Flow 与 RxFlow 的类型边界](#flow-与-rxflow-的类型边界)
- [背压、缓存与重订阅](#背压缓存与重订阅)
- [RxJava 迁移对照](#rxjava-迁移对照)
- [设计代码时的核对清单](#设计代码时的核对清单)
- [源码与测试入口](#源码与测试入口)

## 资料范围与核对原则

结论取自：

- `KPower/core/reactive-coroutines`：模块 `README.md`、`src/jvmMain/.../rxstyle/flow` 实现、`src/jvmTest/.../rxstyle/flow` 行为测试。
- `xxf_android/core/reactive-coroutines-android`：`autodispose`、`schedulers`、`lifecycle` 扩展与模块 Gradle 文件。

当前资料展示的是某次本地源码快照。实际任务要先检查目标工程依赖版本和 import，再读同版本源代码或 API 文档。不得把快照的签名和行为无条件套到其他版本。

## 心智模型

```text
Assembly（只搭链，不开始收集）
source -> operator -> subscribeOn -> observeOn -> [to(autoDisposable)]
                                                     |
Subscription（每次 subscribe 单独建立）             |
subscribe -> FlowObserver + FlowDisposable <--------+
                                                     |
Runtime（运行信号）                                  |
onSubscribe -> onNext* -> onError/onComplete         |
       \\ dispose / 生命周期结束 ---------------------> 取消，不伪造完成
```

| 概念 | 本库含义 | 易混点 |
|---|---|---|
| `Flow<T>` | Kotlin 原生冷数据流协议 | 以 suspend `collect` 为终端；operator 可有 suspend 回调。 |
| `RxFlow<T>` | `AbstractFlow` 子类，同时实现 `Flow` 与 `FlowSubscribeSource`；Rx operator 在内部以 Observer/Disposable 协议组合 | 静态类型为 `RxFlow` 才能优先使用专用 RxFlow overload；赋值到 `Flow` 后扩展解析可能变化。 |
| assembly | 构建 operator 链 | 通常不启动 source、不收集数据。 |
| subscription | 每次调用 `subscribe` 建立一份独立订阅 | cold source 每次重新执行；不要把构建链和订阅混为一谈。 |
| `FlowDisposable` | 一份订阅的取消句柄 | `dispose` 幂等取消，不等同于完成，也不等待所有异步清理结束。 |
| `FlowObserver<T>` | `onSubscribe`、`onNext`、`onError`、`onComplete` 协议 | null 不属于 RxStyle signal；类型约束为 `T : Any`。 |
| AutoDispose proxy | converter 与订阅协议的桥接 | converter 调用不启动订阅；真正的 scope 解析发生在每次 `subscribe`。 |

信号顺序约束为 `onSubscribe` 先于其他信号，之后零个或多个 `onNext`，最后最多一个 `onError` 或 `onComplete`。取消不产生 terminal 信号。普通有限 cold source 可能在 `subscribe` 返回前同步完成，所以不要假设 callback 一定晚于返回执行。

## 订阅生命周期

### 手动订阅

```kotlin
val disposable: FlowDisposable = source.subscribe(
    onNext = ::render,
    onError = ::showError,
    onComplete = ::finish
)
```

订阅所有者负责选择何时停止，并保留句柄。一次性请求一般自然结束；轮询、监听器、socket 或 `never()` 一类无限源必须有清晰的停止路径。

### 多资源订阅

```kotlin
private val disposables = CompositeFlowDisposable()

fun start() {
    disposables.add(firstFlow.subscribe(::renderFirst, ::showError))
    disposables.add(secondFlow.subscribe(::renderSecond, ::showError))
}

fun stop() {
    disposables.dispose()
}
```

`clear()` 释放当前集合但容器可继续使用；`dispose()` 永久关闭容器，之后添加的句柄会立即释放。`remove` 会删除并 dispose 对应成员，`delete` 只移除不 dispose。若 dispose 成员时抛异常，容器会同步抛单个异常或 `CompositeFlowException`，调用方不能假定释放一定无异常。

`SerialFlowDisposable.set(next)` 会释放旧句柄；`replace(next)` 替换但不释放旧值。用哪个取决于资源所有权，不能互换。

### 生命周期订阅

核心层 `autoDisposable(scope)` / `autoDisposable(scopeProvider)` 和 Android 层 `autoDisposable(owner/lifecycle/view)` 都是在订阅时绑定生命周期。Android Lifecycle observer 由 Main 注册和移除，发出 ready 前 upstream 不启动。生命周期正常结束只取消订阅，不给业务发完成回调。

AutoDispose 限定的是**一份订阅何时取消**，不会自动在生命周期重新进入活跃状态时重订阅。需要停止后恢复的页面流，必须设计明确的重新订阅触发点；不要把 AutoDispose 当成 repeat-on-state 容器。

## 线程与调度

| API | 改变什么 | 不改变什么 |
|---|---|---|
| 无 `subscribeOn` | 同步 source 默认从调用 `subscribe()` 的线程开始 | 不自动选择 IO、Default 或 Main。 |
| `subscribeOn(scheduler)` | 上游订阅/source 执行位置 | 不保证下游 observer 永远在该线程。 |
| `observeOn(scheduler)` | 链路该位置之后的信号通知线程 | 不负责启动 source 的线程。 |
| `unsubscribeOn(scheduler)` | 上游 dispose/释放动作的调度 | 不切换 `onNext`、`onError`、`onComplete` 通知线程。 |
| Android `bindLifecycle` | Lifecycle/View 控制面的注册与结束监听 | 不切换业务数据或 UI callback 线程。 |

```kotlin
repository.load()
    .subscribeOn(Schedulers.io())
    .map(::toUiModel)
    .observeOn(AndroidSchedulers.mainThread())
    .subscribe(::render, ::showError)
```

source 若是阻塞调用，`subscribeOn(Schedulers.io())` 放在 source 附近且在订阅前完成 assembly。UI 更新由明确的 `observeOn(AndroidSchedulers.mainThread())` 或 Android 便捷扩展负责。多个 `observeOn` 是多个边界；README 说明多次 `subscribeOn` 中靠近 source 的一次生效，若依赖复杂嵌套边界，必须按当前版本源码/测试复核。

Scheduler 可从 `Schedulers.computation()`、`io()`、`single()`、`newThread()`、`trampoline()` 和 `from(dispatcher)` 取得。Android 扩展还提供 `AndroidSchedulers.mainThread()` 及 `subscribeOnMain`、`observeOnMain`、`unsubscribeOnMain`。具体语义以相应模块实现为准。

`observeOn(scheduler, delayError = false, bufferSize = 128)` 使用 Observable 风格缓冲队列，不是 Flowable 背压。慢下游可积压。不要仅靠增加 bufferSize 解决持续生产快于消费的问题。

## 错误与取消协议

| 事件 | 处理方式 |
|---|---|
| 上游失败，订阅提供 `onError` | 异常交给此订阅的错误回调。 |
| 省略 `onError` | 交给 `FlowPlugins`；未安装 handler 时进入当前线程 uncaught exception handler。 |
| `onErrorReturn` / `onErrorResumeNext` | 在链路内恢复，并以替代值/备用流继续或完成。 |
| retry predicate 抛错 | 源错误与 predicate 错误组合；具体异常类型查当前实现。 |
| 手动 `dispose()` | 取消上游，不发 `onComplete`，不把 coroutine cancellation 当普通业务错误。 |
| scope 正常完成 | AutoDispose dispose 本次订阅，不发业务 `onComplete`。 |
| scope 建立错误 | 由 scope 错误协议终止；outside-scope 还受 `FlowAutoDisposePlugins` 处理策略影响。 |
| terminal 之后无法交付的错误 | 作为 undeliverable 走插件路径。 |

每条生产链路要显式决定错误归属。优先使用订阅级 `onError`；全局 `FlowPlugins` 适合应用级兜底或日志，并应按应用全局状态管理规则安装/恢复，不要在局部业务代码频繁覆盖。

`onErrorComplete()` 默认会把任意源错误变成正常完成。只有业务明确允许降级时才用，通常提供 predicate 过滤可忽略的错误，避免把程序错误伪装为成功。

## Flow 与 RxFlow 的类型边界

`RxFlow` 兼容 `Flow` 返回声明，业务不需要公开转换 API。但 Kotlin 扩展按编译期 receiver 选函数：

```kotlin
val strictChain = Flows.just(1, 2)
    .map { it * 2 }           // RxFlow.map，回调是同步函数

val typedAsFlow: Flow<Int> = strictChain
val interop = typedAsFlow.map { suspendTransform(it) } // kotlinx Flow operator
```

确认同名 API 的来源要看 import 和 receiver 类型。不要靠 IDE 自动补全函数名推断运行语义。普通 `Flow<T>` 上，本库若有相应扩展会内部适配到 RxFlow；但并非每个 RxJava operator 都存在，也不是每个操作符 callback 都一致。

RxStyle 的 operator callback 通常是非 suspend 函数；明确存在 suspend 版本时才可挂起。例如参考源码中 `Flow<T>.takeUntil(predicate)` 的 predicate 是 suspend，严格 RxFlow 上其他 operator 不应默认支持 suspend callback。

Nullable `Flow<T?>` 继续用原生 Flow 的 collect/operators；进入 `subscribe`、Rx operator 或 AutoDispose 之前先过滤或转非空类型。`combineLatest`、`zipWith` 的某些 other 类型允许 nullable，源类型与输出类型仍受 `T : Any` 约束，具体查签名。

## 背压、缓存与重订阅

- 该库目标是 Observable 风格 Observer/Disposable API，不提供 `Flowable.request(n)` 背压协议。
- `observeOn` 有缓冲队列；缓冲只能吸收有限速度差，不能让无限生产长期安全。
- `Flows.interval(period)` 的默认 source 使用 computation scheduler；显式 scheduler 重载需进一步检查实现。README 和工厂 KDoc 特别区分普通顺序 Flow 行为与 scheduler 定时 source，不能将两者概括为相同的背压/时钟行为。
- `Flows.fromCallback` 借助 `callbackFlow`。参考实现的 `FlowCallback.onNext` 调用 `trySend`，但接口返回 `Unit` 且忽略发送结果；默认 buffer 满时，调用方无法从这个方法获知失败，事件可能被丢弃。注册、取消和 unregister 是资源边界；调用方需要检查 callback API 的事件速率与缓冲策略，并处理注册失败、重复 terminal 和取消后的迟到回调。
- `retry(times)` 的 `times` 是最多重试次数，因此最大 source 订阅次数是 `times + 1`；`retry()` 是无限重试。网络错误重试应限定次数/错误类型并考虑退避，不要无条件永久重试。
- `defer`、`fromCallable` 等 cold source 每次订阅会再次执行。多处订阅不会自动共享一次请求结果；需要缓存/共享时使用工程已有的 StateFlow/share/cache 设计并明确失效语义。

## RxJava 迁移对照

| RxJava | 本库对应 | 迁移时必须重查 |
|---|---|---|
| `Observable` | `Flow` / `RxFlow` | 原生 Flow 和 RxStyle observer 链不是同一终端协议。 |
| `subscribe(...)` | 普通 Flow 扩展 `subscribe(...)` | 非 suspend；检查 callback、错误处理、返回 disposable。Observer overload 返回值行为不同。 |
| `Disposable` | `FlowDisposable` | dispose 取消而不完成；只在有取消责任时保存。 |
| `CompositeDisposable` | `CompositeFlowDisposable` | `clear` 可复用、`dispose` 永久关闭；成员释放异常可同步抛出。 |
| `SerialDisposable` | `SerialFlowDisposable` | `set` 会 dispose 旧值，`replace` 不会。 |
| `subscribeOn` | 同名扩展 | source 默认不自动 IO；多处调用边界依当前版本实现。 |
| `observeOn` | 同名扩展 | 显式控制通知边界；缓冲不等于背压。 |
| AutoDispose | `to(autoDisposable(...))` 或 Android `bindLifecycle` | converter 必须放末端；scope 结束只取消；不会自行重启。 |
| `Observable.create` | 顺序生成可用 `Flows.create`；跨线程 callback 用 `Flows.fromCallback` | `Flows.create` 是 FlowCollector suspend block，不是 Rx emitter。callback 要注册和注销成对。 |
| `Flowable` | 无直接等价 | 设计生产者速率、采样/节流、缓冲上限和消费策略。 |
| `blocking*` | 本库 blocking 扩展 | 测试或允许阻塞的后台线程；Android 主线程禁止。 |

只对源码和对应测试覆盖的操作符说“兼容 RxJava”。对外描述行为时要指出所依据的 RxJava 版本；版本未指定就只陈述本库行为。

## 设计代码时的核对清单

- [ ] source 是 cold、callback、定时、还是长连接？每次订阅是否应重新执行？
- [ ] 阻塞工作是否显式在合适 scheduler；UI callback 是否显式回 Main？
- [ ] 订阅由谁停止：自然完成、`FlowDisposable`、Composite、Lifecycle scope 或 View detach？
- [ ] 失败归订阅 `onError`、链内恢复还是应用级 plugin？有无误吞异常？
- [ ] 是否出现 nullable 元素、同名 operator、静态类型收窄或 suspend callback？
- [ ] 有没有把节流/缓存/队列参数误当作背压或共享订阅？
- [ ] 生命周期结束后需不需要重启？若需要，重订阅由谁触发？
- [ ] blocking operator 是否只在允许阻塞的后台/测试使用？

## 源码与测试入口

| 主题 | 文件 |
|---|---|
| Factory | `rxstyle/flow/Flows.kt` |
| RxFlow 和 `subscribe` adapter | `RxFlow.kt`、`FlowRxInterop.kt` |
| Observer 与错误插件 | `FlowObserver.kt`、`FlowPlugins.kt` |
| Disposable 家族 | `disposables/FlowDisposable.kt`、`CompositeFlowDisposable.kt`、`SerialFlowDisposable.kt` |
| Scheduler | `RxFlowScheduling.kt`、`schedulers/Schedulers.kt` |
| AutoDispose 核心层 | `autodispose/FlowAutoDispose.kt`、`FlowSubscribeProxy.kt`、`FlowScopeProvider.kt` |
| Android Lifecycle/View | `LifecycleAutoDispose.kt`、`ViewAutoDispose.kt`、`FlowLifecycle.kt`、`FlowDisposableLifecycleExtensions.kt` |
| Android scheduler/filter | `AndroidSchedulers.kt`、`MainThreadSchedulerExtensions.kt`、`FlowLifecycleFilterExtensions.kt` |
| 行为测试 | `FlowAutoDisposeTest`、`FlowDisposableTest`、`FlowBlockingTest`、`FlowCombineGateTest`、`FlowTimeExtensionsTest`、`RxFlowCoreTest`、`RxFlowRetryDistinctTest`、`RxFlowSemanticsTest`、`RxFlowTransformTest`、`RxFlowTimeSourceTest`、`TestFlowSchedulerTest` |
