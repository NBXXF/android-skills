# 响应式设计与组合：让 AI 从业务约束推导链路

## 目录

- [先建立事件与状态模型](#先建立事件与状态模型)
- [操作符选型流程](#操作符选型流程)
- [可编译的搜索链路](#可编译的搜索链路)
- [保序写入与错误隔离](#保序写入与错误隔离)
- [缓存为空与缓存失败](#缓存为空与缓存失败)
- [轮询的两种时钟](#轮询的两种时钟)
- [按钮与状态组合](#按钮与状态组合)
- [原生 Flow 补足能力](#原生-flow-补足能力)
- [取消与资源所有权](#取消与资源所有权)
- [诊断与行为验证](#诊断与行为验证)

## 先建立事件与状态模型

不要从“套一段 map + subscribe”开始。把业务输入、输出和约束写成一条契约，再选择操作符：

```text
输入是什么：用户查询词（可重复、可清空、无限事件）
输出是什么：当前查询的 Idle / Loading / Data / Failure 状态
时效规则：仅最新查询能更新页面
错误规则：一次失败不影响下一次输入
线程规则：请求 IO，UI Main
停止规则：Fragment View 销毁取消
验证规则：旧请求迟到不覆盖新状态；失败后还能搜索
```

| 概念 | 推导方式 | 常见错误 |
|---|---|---|
| 事件 event | 每次到达都可能有意义，如点击、保存命令 | 对点击全局 distinct，导致之后相同按钮再也不触发 |
| 状态 state | 当前快照，如查询条件、表单、连接状态 | 用瞬时事件表达长期状态，晚订阅者拿不到当前值 |
| 冷源 | 订阅启动一次工作，如 fromCallable/defer | 两处 subscribe 默认执行两次请求 |
| 热源 | 上游在外部持续运行，如 StateFlow/SDK listener 所属服务 | 以为 dispose 一个订阅就关闭整个共享服务 |
| 值变换 | `T -> R` | map 返回 Flow，结果成了 Flow<Flow<R>> |
| 异步任务变换 | `T -> Flow<R>` 然后选择 inner 策略 | 为了调用 suspend，在 subscribe 里 launch，导致取消与错误脱离主链 |
| 副作用 | 看见值/信号时记录、计数或清理 | 把 doOnNext 当转换返回结果，或在 transform 构建时直接执行写入 |
| 结束 | completed、failed、disposed 分开 | 把取消当成功，或用 onComplete 承担所有清理 |

一条流失败后即终止，无法靠下次输入“复活”。要让长期事件源在单次工作失败后继续，错误恢复必须放进对应 inner；对整条流 retry 会重新订阅事件源，可能丢事件、重复注册或重做副作用。

## 操作符选型流程

| 业务问题 | 选择 | 决策理由 |
|---|---|---|
| 同步一对一转换 | map | 保持项数；同步 lambda 不调用 suspend |
| 调用一次 suspend/阻塞函数 | fromCallable/fromSuspend | 把执行推迟到订阅时；显式处理调度 |
| 条件不满足的项忽略 | filter | 不终止源；清空输入若应清页面，不能直接过滤 |
| 连续相同状态不用刷新 | distinctUntilChanged | 只去连续重复；先 normalize 再去重 |
| 新任务取消旧任务 | switchMap | 适合只读搜索/切换；不承诺撤销已提交的写操作 |
| 每个任务都必须保序执行 | concatMap + 惰性 inner | 适合写入；同时需要考虑排队上限和失败后的队列策略 |
| 多项并行且限制并发 | 原生 flatMapMerge(concurrency) | 当前本库无 flatMap 参数族；不能虚构 `.flatMap(maxConcurrency=...)` |
| 任一条件改变就重算 | combineLatest | 两侧首值是启动条件 |
| 仅按钮点击触发，附带最新状态 | clicks.withLatestFrom(state) | state 变化不自动提交 |
| A 完成之后做 B | concat/concatWith/concatMap | 不能用 merge 表达顺序 |
| 等准备好才允许副作用启动 | delaySubscription(ready) | skipUntil 仍执行上游 |
| 到达终点且要保留该项 | takeUntil(predicate) | 当前项先发送；不是原生 takeWhile |
| 无项正常完成才回退 | switchIfEmpty/defaultIfEmpty | 错误不是空流 |
| 输入稳定一段时间后搜索 | throttleWithTimeout | 要加 inner 错误隔离；distinct 的位置依业务 |
| 窗口首点击通过 | throttleFirst | 只防短时间重复，不防长请求期间重复提交 |
| 进度 UI 降频 | throttleLast | 会丢尾值，最终成功由独立结果信号确认 |
| 保证所有退出方式资源释放 | using/doFinally | doFinally 的 dispose 路径无 Main 保证；资源释放须幂等 |

先处理正确性，再压缩写法。不要为了“响应式风格”把简单的一次 suspend 顺序逻辑拆成难以解释的多个信号；也不要在已有事件流里用嵌套 subscribe 搭一个无法统一取消的异步树。

## Flow 链路不可随意拆断

当业务已经以 `Flow` 表达输入、状态或事件时，默认让后续处理继续留在同一条 Flow 链。不要为了在普通 suspend 代码中“拿到一个值”，对中间流调用 `first()`、`firstOrNull()`、`single()`、`last()`、`toList()` 或 `collect()`，然后再 `launch`、重新 `flow {}` 或 `Flows.just(...)` 接下一步。这样会把取消、错误、调度和生命周期所有权切成两段，并常常悄悄丢掉后续更新。

| 要表达的意图 | 保持在 Flow 中的做法 | 不应采用的拆断方式 |
|---|---|---|
| 上游每次值变化都计算新结果 | `map` / `transform`；异步结果用 `switchMap`、`concatMap` 或原生 `flatMap*` | `val value = upstream.first()` 后只计算一次 |
| 读取两个持续状态的最新组合 | `combine` / `withLatestFrom` | 在一个 `collect` 中对另一 Flow 调 `first()` |
| 每个事件触发挂起单值任务 | `switchMap { Flows.fromSuspend { work(it) } }`，或使用支持 suspend transform 的原生 operator | `events.collect { launch { work(it) } }` |
| 每个事件接入一个返回 Flow 的任务 | 直接 `switchMap { repository.observe(it) }` / `concatMap { ... }` | `repository.observe(it).first()` 后再 `Flows.just(...)` |
| 仅需要符合契约的一次快照 | 在明确终端函数/边界调用 `first()`，并定义空流、错误、取消与不再观察后续值 | 用 `first()` 规避 operator 的签名或临时“接上”同步代码 |

“一次性快照”是少数例外，而不是 Flow 与 suspend 之间的默认桥梁：例如 repository API 明确要求当前配置的一个值，且调用完成后不应继续订阅更新。此时把提取放在该 API 的边界，并在名称、KDoc 或调用点体现单次语义；不要把它藏在 ViewModel/UseCase 的中间步骤。

如果某个 RxStyle operator 的 transform 是同步的，不能直接调用 suspend 函数，也不能因此先对 Flow 取 `first()`。将挂起工作放进惰性 `Flows.fromCallable` / `Flows.fromSuspend` / `Flows.defer` 返回的 inner Flow，再用 `switchMap` 或 `concatMap` 组合；若需要的语义属于原生 Flow，则明确保留 native Flow 类型、import 和 operator 边界。这样取消、错误恢复与生命周期仍能沿整条链传播。

## 可编译的搜索链路

下面是一份可放入 Android 业务模块的 Kotlin 示例。假设已按目标工程现有 Gradle 接入两个模块与 AndroidX Lifecycle；不猜 Maven 版本。UI 回调接受状态模型，由调用方负责 strings.xml 文案。函数在非 suspend 入口调用，owner 对应页面/View 生命周期；每次调用只建立一份订阅。

```kotlin
package example.reactive

import androidx.lifecycle.LifecycleOwner
import com.nbxxf.kpower.coroutines.rxstyle.flow.Flows
import com.nbxxf.kpower.coroutines.rxstyle.flow.RxFlow
import com.nbxxf.kpower.coroutines.rxstyle.flow.distinctUntilChanged
import com.nbxxf.kpower.coroutines.rxstyle.flow.map
import com.nbxxf.kpower.coroutines.rxstyle.flow.onErrorReturn
import com.nbxxf.kpower.coroutines.rxstyle.flow.startWithItem
import com.nbxxf.kpower.coroutines.rxstyle.flow.subscribeOn
import com.nbxxf.kpower.coroutines.rxstyle.flow.switchMap
import com.nbxxf.kpower.coroutines.rxstyle.flow.disposables.FlowDisposable
import com.nbxxf.kpower.coroutines.rxstyle.flow.schedulers.Schedulers
import com.xxf.coroutines.android.autodispose.bindLifecycle
import com.xxf.coroutines.android.schedulers.observeOnMain
import kotlinx.coroutines.flow.Flow
import kotlin.time.Duration.Companion.milliseconds

/** 查询结果条目。 */
data class SearchItem(val id: String)

/** 查询接口，具体数据实现由业务模块提供。 */
interface SearchRepository {
    suspend fun search(query: String): List<SearchItem>
}

/** 当前查询对应的页面状态，错误作为可渲染的数据。 */
sealed interface SearchState {
    data object Idle : SearchState
    data class Loading(val query: String) : SearchState
    data class Data(val query: String, val items: List<SearchItem>) : SearchState
    data class Failure(val query: String, val cause: Throwable) : SearchState
}

/** 仅最新查询生效；单次失败不会终止查询输入源。 */
fun bindSearch(
    queries: Flow<String>,
    repository: SearchRepository,
    owner: LifecycleOwner,
    render: (SearchState) -> Unit,
    onUnexpectedError: (Throwable) -> Unit
): FlowDisposable {
    return Flows.wrap(queries)
        .map { it.trim() }
        .distinctUntilChanged()
        .switchMap { query ->
            if (query.isEmpty()) {
                // 空词也到达 switchMap，立即取消旧请求并清空页面。
                Flows.just<SearchState>(SearchState.Idle)
            } else {
                // 把等待放进 inner：新原始输入到达即取消旧 inner，
                // 新请求则等输入静默 300ms 才启动。
                Flows.timer(300.milliseconds)
                    .switchMap {
                        val request: RxFlow<SearchState> = Flows.fromCallable {
                            repository.search(query)
                        }
                            .subscribeOn(Schedulers.io())
                            .map { items -> SearchState.Data(query, items) as SearchState }
                            .onErrorReturn { error -> SearchState.Failure(query, error) }
                        request.startWithItem(SearchState.Loading(query))
                    }
            }
        }
        .observeOnMain()
        .bindLifecycle(owner)
        .subscribe(render, onUnexpectedError)
}
```

此示例使用 timer 作为每个最新查询的等待。更常见的 `.throttleWithTimeout(300.milliseconds).switchMap { request(it) }` 也有效，但**防抖期间旧请求仍可能返回**，要先决定业务是否接受。不要宣称防抖自动实现“原始输入一变化就取消旧请求”。

状态的泛型需要明确扩大到 `SearchState`：若推断成 `RxFlow<SearchState.Data>`，就不能 fallback 为 Failure 或 startWith Loading。当前示例使用显式状态上转；也可定义返回 SearchState 的 mapper，避免不必要 cast。

轨迹验收：A 输入 → 等待 → Loading(A) → A 请求；B 输入立即取消 A → 等待 → Loading(B)；即使 A 迟到也不能覆盖 B；B 失败输出 Failure(B)；C 输入仍可成功；空词立即 Idle；owner 销毁停止订阅与计时。不可取消的 SDK/阻塞 IO 仍可能继续做实际工作，链路只能约束信号交付，不能保证撤销外部操作。

## 保序写入与错误隔离

链路片段，`commands: Flow<Command>`、`repository.save(Command): suspend Receipt` 和 `SaveState` 是业务接口/模型占位；导入 core 的 concatMap/map/onErrorReturn/subscribeOn、Android observeOnMain/bindLifecycle，以及 Flows/Schedulers。

```kotlin
Flows.wrap(commands)
    .concatMap { command ->
        Flows.fromCallable { repository.save(command) }
            .subscribeOn(Schedulers.io())
            .map { receipt -> SaveState.Success(receipt) as SaveState }
            .onErrorReturn { error -> SaveState.Failure(command, error) }
    }
    .observeOnMain()
    .bindLifecycle(owner)
    .subscribe(::renderSaveState, ::reportUnexpectedError)
```

inner 失败恢复使队列继续；若业务要求某一步失败就停止整个批次，则移除 inner 恢复，直接让错误终止并清空待执行任务。写操作重试要先确认幂等 key/去重策略。concatMap 无有界队列，持续命令输入还需入口限制或业务队列。页面销毁取消是否允许丢掉未执行写入，由任务归属决定；必须完成的持久任务不应归属页面 View。

不要用 throttleFirst 模拟“整个请求期间禁止重入”：窗口过后旧请求可能仍未完成。此版本没有 exhaustMap；可通过应用已有的提交状态门禁，或原生结构化并发/Mutex 设计此业务规则，不发明本库 API。

## 缓存为空与缓存失败

`readCache(): Flow<Model>` 假定 **miss 为 empty，命中发一项并完成**；`fetch(): suspend Model`。如果缓存是长期 Room/StateFlow 观察源，它可能从不完成，switchIfEmpty 永不执行，concat 后的网络也不会开始。先用业务的单次缓存查询或原生 take(1) 明确边界。

```kotlin
val network = Flows.fromCallable { repository.fetch() }
    .subscribeOn(Schedulers.io())

val cacheFirst = repository.readCache()
    .switchIfEmpty { network }
```

- 缓存 miss：正常空完成 → network。
- 缓存失败：直接 onError；是否允许降级网络需要另写 `.onErrorResumeNext { error -> ... }`，按错误类型决定，而不是把所有错都当 miss。
- 缓存命中：发缓存并完成，不请求网络。
- 要“缓存先显示、网络再刷新”：`Flows.concat(cacheOnce, network)`；不要用 switchIfEmpty。
- 写回缓存：使用可挂起的 `Flows.fromCallable { val fresh=fetch(); saveCache(fresh); fresh }`；不能在同步 doOnNext 直接调用 suspend save。

缓存和网络不是同一 T 时先映射共同领域模型/状态。网络结果同缓存相等时是否抑制，用末端 distinct 由 UI 规则决定。多个消费者共享一次加载，应单独定义共享层，不能认为保存 `val network` 就缓存了结果。

## 轮询的两种时钟

| 时钟 | 链路 | 慢请求时发生什么 |
|---|---|---|
| 固定 tick，最新优先 | interval → switchMap(request) | 每次 tick 取消旧请求；请求总比周期慢可能永远拿不到结果 |
| 固定 tick，每轮必做 | interval → concatMap(request) | 请求依次执行，积压越来越多，不是固定间隔完成 |
| 完成后等待再请求 | fromCallable(request) → repeatUntil { delay(period); stop() } | 不重叠；开始间隔为请求耗时加等待；失败直接结束，需显式恢复/重试 |

固定完成间隔片段，`period` 是 Duration，`shouldStop()` 是业务的同步条件；import core repeatUntil、subscribeOn，`kotlinx.coroutines.delay`。对 suspend lambda 可用标准协程 delay，这与同步 retry predicate 不同。

```kotlin
Flows.fromCallable { repository.refresh() }
    .subscribeOn(Schedulers.io())
    .repeatUntil {
        if (shouldStop()) {
            true
        } else {
            kotlinx.coroutines.delay(period)
            shouldStop()
        }
    }
    .observeOnMain()
    .bindLifecycle(owner)
    .subscribe(::renderRefresh, ::showRefreshError)
```

需要单轮失败后继续，先把这一轮错误映射为结果或按策略重试，再 repeat；错误恢复位置决定是否继续。`repeatUntil` 至少执行首轮，开始前就不该运行时要先判断。禁止 `repeat()` 包装同步 empty 或无等待的立即任务造成忙循环。

## 按钮与状态组合

```kotlin
clicks.withLatestFrom(formState) { _, state -> state }
    .filter { it.canSubmit }
    .concatMap { state ->
        Flows.fromCallable { repository.submit(state) }
            .subscribeOn(Schedulers.io())
    }
```

导入 core withLatestFrom/filter/concatMap/subscribeOn；`withLatestFrom` 返回 RxFlow，filter 为同步。本例仅表达“每次点击取当时状态并保序提交”，尚未加错误隔离、去重/重入规则、Main、owner 和终端。formState 未有值时点击丢弃；如果它是带初值 StateFlow，则应确认初始状态是否允许提交。参数方向调反会造成表单修改自动触发提交。

表单能否提交属于状态推导，可用字段流 combineLatest；真正提交属于事件，不要直接订阅有效表单状态就自动写服务端。执行时要快照 state，不在排队任务真正开始后再读取已变化的 mutable form。

## 原生 Flow 补足能力

本库没有实现全部 Rx 操作符。用原生 API 时显式标出边界和 import，保留其协程语义，不把同名函数当作同实现。

| 需求 | 原生工具（非本库 RxStyle operator） | 边界 |
|---|---|---|
| 有界并发执行 N 个 inner | kotlinx Flow flatMapMerge(concurrency=N) | callback 支持 suspend；是否需 opt-in 以项目版本为准 |
| 带退避重试 | kotlinx Flow retryWhen + kotlinx.coroutines.delay | attempt 通常从 0 开始，查目标依赖签名；避免与 Rx retry 同名误解析 |
| 单次 suspend 超时 | kotlinx.coroutines.withTimeout | TimeoutCancellationException 是否转换业务失败需显式定义；主动取消继续传播 |
| 只取首 N 项 / 不含终点的条件截断 | kotlinx Flow take / takeWhile | 本库 takeUntil(predicate) 包含触发项 |
| 可重放/共享状态 | stateIn/shareIn 或本模块 asStateFlow | 定义 scope、初值、启动策略与错误状态；不是一次性缓存默认替代 |
| 只在 STARTED 活跃且自动恢复 | AndroidX repeatOnLifecycle 等 | scope launch/collect 的结构化并发范式；不等于 filterWhen 或单次 AutoDispose |

显式 alias 示例（链路片段，`requests: Flow<Request>`）：

```kotlin
import kotlinx.coroutines.flow.map as nativeMap
import kotlinx.coroutines.flow.retryWhen as nativeRetryWhen
import com.nbxxf.kpower.coroutines.rxstyle.flow.Flows

val native: Flow<Response> = requests.nativeMap { request ->
    repository.fetch(request) // suspend
}.nativeRetryWhen { cause, attempt ->
    if (cause is java.io.IOException && attempt < 2L) {
        kotlinx.coroutines.delay(200L * (attempt + 1L))
        true
    } else {
        false
    }
}
val rx = Flows.wrap(native) // 此后需要同步 map / Observer / Disposable 时明确进入 Rx 链。
```

上述 retryWhen 会重做整条 requests 冷源，是否适合长期事件源取决于输入；单请求重试优先放到该请求的 inner 中。以 Kotlin Flow 静态类型隔离边界，再用 alias 可以消除扩展冲突；只改变量名不能改变 receiver 的解析。

## 取消与资源所有权

订阅所属 owner 决定的是“此消费者是否继续接收”，不等于业务工作是否必须持久完成。区分页面展示、ViewModel 计算、服务监听、持久任务。

| owner | 绑定选择 | 额外约束 |
|---|---|---|
| Fragment View | bindLifecycle(viewLifecycleOwner) | owner 在 onViewCreated 后可用；不把已销毁 View 捕获到 ViewModel 流 |
| 自定义 View attach 段 | bindLifecycle(view) | attach 后订阅；detach 取消，再 attach 需重新订阅 |
| ViewModel | bindLifecycle(viewModel) | ViewModel 清除才取消，页面不可见时仍可能工作 |
| 有 Job 的 scope | to(autoDisposable(scope)) | 只用 Job，数据调度单独安排；无直接 Flow.bindLifecycle(scope) |
| 手工一组订阅 | CompositeFlowDisposable | clear 可重用，dispose 关闭；重建 owner 时重建容器 |
| 手工当前任务 | SerialFlowDisposable.set | 替换即取消旧任务；同步返回与重入需考虑，优先 operator 表达任务切换 |

callback 适配用 fromCallback(register, unregister)，需要注销 API 时不能沿用默认空 unregister。高频事件默认 trySend 失败不反馈，关键命令不能默认接受丢失。using 的 disposer、fromCallback 的 unregister、SDK listener 的解绑在同一所有权模型下必须幂等；注销若必须 Main，显式安排而不是假设生命周期绑定替你切线程。

## 诊断与行为验证

把 debug 放在歧义边界前后：normalize 后、switchMap 前、inner 内、observeOn 前后。日志会记录 subscribed/next/error/completed/disposed；当前 FlowDebugEvent 本身没有线程名或时间戳，需要日志 handler 自己补。trimOutput 只截断，不脱敏，不默认输出业务敏感模型。

| 症状 | 先检查 | 修正与验收 |
|---|---|---|
| 操作符无法解析或 suspend 编译错 | receiver 静态类型 + import + 快照签名 | 显式 alias/Flow 或 RxFlow 类型；suspend 放 fromCallable/create 或原生 operator |
| 一次失败后按钮永远没反应 | 错误恢复是在 inner 外吗 | inner 内恢复；连续触发失败/成功两次验收 |
| 网络调用发生在搭链时 | just 参数、transform 内直接副作用 | defer/fromCallable；未订阅前调用计数必须 0 |
| 串行任务仍然乱序执行 | concatMap transform 是否提前做了工作 | inner 惰性执行；断言实际执行期间没有重叠 |
| UI 偶发线程异常 | 时间尾值、onSubscribe、dispose/finally 路径 | UI 通知 observeOnMain；清理单独调度，分别验收成功/错/取消 |
| 内存一直涨 | observeOn/concatMap/collect bridge 队列 | 不把 bufferSize 当上限；检查生产速率、队列与共享策略 |
| 页面回来没有新数据 | AutoDispose 已结束还是 filterWhen 丢过值 | 显式重订阅或状态重放；进入/退出两轮验收 |
| interval 请求一直没完成 | 周期小于请求耗时且 switchMap | 选择完成后间隔或业务并发策略；慢请求注入验收 |
| 进度最后不到 100% | throttleLast 丢尾项 | 独立完成结果驱动最终状态；源完成前后验收 |

给 AI 的交付格式：说明输入/输出、inner 策略、错误范围、线程、owner，给出完整 import 和有类型的关键链路；附值/错误/取消轨迹及实际运行的验证。代码未编译或仅静态核对时如实注明。不要把“源码中有测试”写成“这次已经运行通过”。
