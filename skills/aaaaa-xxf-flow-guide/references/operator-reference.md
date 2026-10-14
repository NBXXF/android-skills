# 操作符选型与完整语义参考

## 阅读方式与契约

适用：知道业务意图但不知道选哪个函数，或能写函数名但不确定链路行为。精确重载、泛型、默认参数、包路径查 [完整签名快照](api-signatures.md)；信号、线程和类型基础查 [核心概念](rxstyle-flow-guide.md)；端到端组合查 [响应式设计与组合](reactive-design.md)。

下文签名用 `T/R : Any` 表示非空元素，用 `D` 表示 `kotlin.time.Duration`。除特别注明，转换结果为 `RxFlow`，构建链不执行任务，每次订阅的状态独立；回调抛出的普通异常进入错误路径，fatal JVM 错误遵从库的 `throwIfFatal`。所有代码短式都是链路片段，最终需明确 `onError` 和取消所有者。

源码事实范围是随附签名快照对应的本地模块，不承诺 RxJava 的所有重载/边界兼容。**不要推导未列出的重载**；例如这里没有核心 `flatMap`、`retryWhen` 或 `timeout` 的 RxStyle 实现，它们需要显式进入原生 Flow 或另查目标版本。

## 1. Source：值什么时候产生

所有条目来自 `Flows.kt`，调用形式为 `Flows.xxx`。这里 factory 的 suspend 能力与 operator 的同步 lambda 要分开理解。

| 函数 / 重载 | 输出与完成 | 选用方式 / 关键边界 |
|---|---|---|
| `just(value)`；`just(first, second, vararg others)` | 按参数顺序发值后完成 | 参数在搭链时已经求值；`just(load())` 不会延迟 `load()`；无零参数 overload，用 `empty<T>()` |
| `empty<T>()` | 无值、正常完成 | 表示“允许无结果”，会触发 empty fallback、repeat 和 gate 的完成语义 |
| `error<T>(throwable)`；`error<T>(supplier: suspend () -> Throwable)` | 无值、失败 | supplier 每次收集重新运行；用于延迟决定错误 |
| `never<T>()` | 不发值，不完成 | 只能取消；不能放在需要正常完成才能推进的 concat 前面 |
| `create(block: suspend FlowCollector<T>.() -> Unit)` | `emit` 顺序发值，block 返回后完成 | 同一协程内生成，可挂起；不是跨线程 emitter，不向任意 callback 暴露 collector |
| `defer(factory: suspend () -> Flow<T>)` | 每次订阅创建实际 source，转发其信号 | factory 返回 Flow，适合订阅时读取状态/建立请求，不缓存结果 |
| `fromCallable(callable: suspend () -> T)` | 成功发一个 T 后完成 | 阻塞/挂起函数均可；不自动 IO，异常作为 onError |
| `fromSupplier(supplier: suspend () -> T)` | 同上 | 委托 callable 的语义；不是 Java Supplier 对象参数 |
| `fromSuspend(block: suspend () -> T)` | 同上 | 把 suspend 调用变成单次 source；不是循环执行 |
| `fromAction(action: suspend () -> Unit)`；`fromRunnable(runnable: suspend () -> Unit)` | 只执行动作，无 onNext，正常完成或失败 | 返回 `RxFlow<Nothing>`；想得到 Unit 信号用 `fromCallable { action(); Unit }`，否则下游 map 不会运行 |
| `fromResult(result: Result<T>)` | success 发值，failure 报错 | Result 在搭链前已存在；重试不会重新计算原来的 Result |
| `fromArray(vararg values)`；`fromIterable(source)`；`fromSequence(source)` | 遍历发值后完成 | source 的可重复遍历性由调用方保证；Sequence 可能只能消费一次 |
| `wrap(source: Flow<T>)` | 保留源的冷/热语义 | 已是 RxFlow 时复用；非空约束；不共享、不启动、不缓存 |
| `range(start: Int, count: Int)`；`rangeLong(start: Long, count: Long)` | 连续 count 个数 | count 是数量；0 为空；负数与终点溢出 assembly 校验失败 |
| `timer(delayDuration: D[, scheduler])` | 延迟后发 `0L` 并完成 | 默认 computation；delay ≥ 0；只能计时，不能当业务请求结果 |
| `interval(period: D[, scheduler])` | 首次在 period 后发 0，之后递增，不自然完成 | period > 0；默认 computation；必须有取消边界 |
| `interval(initialDelay: D, period: D[, scheduler])` | 首次延迟可独立设置 | initialDelay ≥ 0；scheduler 驱动 tick，慢消费者可能积压 |
| `intervalRange(start, count, initialDelay, period[, scheduler])` | 有限 Long 序列后完成 | count ≥ 0；count=0 返回 empty；范围溢出校验；默认 computation |
| `using(resourceFactory: suspend () -> R, flowFactory: suspend (R) -> Flow<T>, disposer: (R) -> Unit)` | 转发资源流，结束/失败/取消后释放资源 | 每次收集创建资源；disposer 同步，不可 suspend；创建资源本身失败则无资源可释放；源与释放都失败时组合异常 |
| `concat(vararg sources)`；`concat(sources: Iterable<Flow<T>>)` | 前一个完成才订阅下一个；全完成才完成 | source 出错直接结束，不自动继续后续 source |
| `merge(vararg sources)` | 并发接入、交错转发；全部完成才完成 | 任一个失败则终止并取消其他；不保证跨 source 排序，不存在此模块的 Iterable merge overload |

## 2. 转换、过滤、去重：值变成什么

| API | receiver / callback | 行为与选择 | 示例 |
|---|---|---|---|
| `map(transform)` | **仅显式 RxFlow overload**；`(T) -> R` | 一进一出，同步转换；返回 Flow 会得到嵌套流，不会执行 inner | `Flows.just(1).map { it * 2 }` |
| `filter(predicate)` | **仅显式 RxFlow overload**；`(T) -> Boolean` | true 保留，false 丢弃；不会停止 source | `.filter { it.isValid }` |
| `skip(count)` | Flow / RxFlow；count ≥ 0 | 丢弃前 N 项，以订阅为单位计数；0 不跳过 | `.skip(1)` 忽略初始状态 |
| `skipWhile(predicate)` | Flow / RxFlow；同步 | 首次 false 的项及后续所有项通过；不会反复开启跳过 | `1,2,3,1` 配 `<3` 得 `3,1` |
| `ofType<R : Any>()` | `Flow<*>`，reified | 按运行时类型筛选并返回非空 RxFlow；不是强制 cast | `events.ofType<Click>()` |
| `distinctUntilChanged()` | Flow / RxFlow | `==` 比较相邻已发出值；不是整个历史集合去重 | `A,A,B,A` 得 `A,B,A` |
| `distinctUntilChanged(keySelector)` | Flow / RxFlow；`(T) -> K` | 只比较连续 key；K 可以为空 | `.distinctUntilChanged(keySelector = { it.id })` |
| `distinctUntilChanged(areEqual)` | Flow / RxFlow；`(T,T) -> Boolean` | true 表示等价并抑制当前值 | `.distinctUntilChanged(areEqual = { a,b -> a.id == b.id })` |
| `distinctUntilChangedByHash()` | Flow 入口 | 比较 hashCode；碰撞会漏更新，通常优先 key/equals | 不把它当作“深比较优化” |

可变对象被原地修改时，旧引用也指向新内容，equals/key 比较可能看不出变化；优先发出不可变快照。两个 distinct lambda overload 用命名参数清楚表达意图。

## 3. 扁平化：如何处理由事件触发的异步任务

| API | 回调 | 并发、取消、完成 | 必须注意 |
|---|---|---|---|
| `Flow/RxFlow.switchMap(transform)` | `(T) -> Flow<R>`，**非 suspend** | 新 outer 取消旧 inner，旧 generation 不再交付值；outer 完成后等待当前 inner；任一当前链路错误终止 | 搜索、切换用户、刷新覆盖旧请求；取消不保证远端写操作撤销 |
| `Flow/RxFlow.concatMap(transform)` | `(T) -> Flow<R>`，**非 suspend** | inner 依次订阅，outer 完成后排空队列再完成；错误终止并清空 | 保序保存/上传；outer 快于处理会积压，无 maxConcurrency/队列上限参数 |

**本地实现细节**：`concatMap` 在 outer `onNext` 内立即执行 transform，把返回的 RxFlow 放入队列；延迟的是 inner 的订阅。因此 `concatMap { saveNow(it); Flows.just(Unit) }` 不能保证保存串行。写成 `concatMap { item -> Flows.fromCallable { save(item) } }`，让副作用在 inner 订阅时发生。`switchMap` 的 transform 也同步运行，应快速返回惰性 source。

```kotlin
// load 是 suspend 函数；在 fromCallable 中调用，不直接在 switchMap lambda 挂起。
queries.switchMap { query ->
    Flows.fromCallable { repository.load(query) }
        .subscribeOn(Schedulers.io())
}
```

outer 是 UI callback 时，外面一个 subscribeOn 不能改变未来 callback 的线程；每个阻塞 inner 自己调度。flatMap 的并行合并、concatMap 的保序执行、switchMap 的替换取消是不同业务规则，不因名字相近互换。

## 4. 空流回退与前缀

| API | 输入条件 / 参数 | 输出 / 失败语义 | 常见用途 |
|---|---|---|---|
| `defaultIfEmpty(defaultValue)` | Flow / RxFlow | source 零项正常完成才补一个值；错误不会触发 | 无记录显示空模型 |
| `switchIfEmpty(fallback: Flow<T>)` | Flow / RxFlow | 零项正常完成后订阅 fallback | 缓存 miss 查询网络 |
| `switchIfEmpty(fallback: () -> Flow<T>)` | Flow / RxFlow；同步 factory | 仅在空完成时创建 fallback；factory 错误成为 onError | 避免搭链时提前创建请求 |
| `startWithItem(item)` | Flow / RxFlow | 先发 item，再订阅原 source | 同一类型的初始状态 |
| `startWith(other: Flow<T>)` | Flow / RxFlow | other 正常完成才订阅原 source | 前缀阶段 / 缓存后网络 |
| `startWithArray(vararg items)` | Flow / RxFlow | 按序发完前缀再订阅 source | 多个初始值 |
| `startWithIterable(items)` | Flow / RxFlow | 同上，遍历给定集合 | 动态前缀 |

“没有数据”“null”“错误”“从未完成”是四种情况。`never()` 不会触发 empty fallback；`fromAction` 会触发，因为它正常完成且没有值。`startWith(never())` 永远不订阅原 source。前缀和原 source 元素必须是同一个 T 或预先映射到共同状态类型。

## 5. 错误恢复与重新订阅

本节各函数除 repeat 系列外均有 Flow/RxFlow overload；repeat 系列是 Flow 入口，RxFlow 通过继承 Flow 使用。

| API | callback / 参数 | 语义 | 适用 / 陷阱 |
|---|---|---|---|
| `onErrorReturnItem(item)` | 固定非空 T | 源失败后补一个值并完成 | 是替代结果，不会恢复源后续事件 |
| `onErrorReturn(valueSupplier)` | `(Throwable) -> T`，同步 | 按错误生成一个替代值后完成 | supplier 再失败会组合源错误与新错误 |
| `onErrorResumeNext(fallbackSupplier)` | `(Throwable) -> Flow<T>`，同步 | 切到备用流；备用流失败交给下游 | supplier 里返回惰性源，不能直接 suspend；fallback 不会被同一节点反复恢复 |
| `onErrorComplete(predicate = { true })` | `(Throwable) -> Boolean`，同步 | true 把错误变完成，false 传错 | 默认吞所有源错误；必须有业务理由；取消本身不是可恢复业务错误 |
| `retry()` | 无次数限制 | 失败立即重订阅上游 | 没有自动退避；同步永久失败会持续占用线程 |
| `retry(times: Long)` | ≥ 0；额外次数 | 最多 `times + 1` 次订阅 | 0 不重试；已发出的值不会回滚，可能重复 |
| `retry(times, predicate)` | `(Throwable) -> Boolean`，同步 | 有额度且 predicate=true 才重试 | predicate 不能 delay；耗尽额度不再调用 predicate；predicate 失败组合错误 |
| `retryUntil(stop)` | `() -> Boolean`，同步 | 每次失败后 stop=true 传原错，false 再订阅 | true 是停止；不在开始前调用 |
| `repeat()` | 无限 | 仅正常完成后重订阅，失败立即终止 | 对同步 empty/source 可造成忙循环 |
| `repeat(times: Long)` | ≥ 0；**总次数** | 0 不订阅，1 一次，N 总共 N 次 | 与 retry 的次数含义不同 |
| `repeatUntil(stop)` | `suspend () -> Boolean` | 每轮正常完成后检查；true 停止，false 继续 | 可挂起等待下一轮；不会重试错误 |

位置决定故障范围：

```text
outer.switchMap { request(it).onErrorReturn(...) }
    一次 inner 失败变成结果，outer 仍接收后续输入。
outer.switchMap { request(it) }.onErrorReturn(...)
    switchMap 整体先失败，恢复后整条流完成，不再响应后续输入。
source.retry(2).onErrorReturn(...)
    先重试，最终失败才降级。
source.onErrorReturn(...).retry(2)
    错误已变正常完成，retry 不会运行。
source.map(parse).retry(2)
    parse 失败会把 source 一起重做；写操作/扣款不能随意这样重试。
```

## 6. 多源组合：哪个事件驱动输出

以下是 Flow 入口，RxFlow 同样可作为 receiver；`combineLatest` / `withLatestFrom` / `zipWith` 的 transform 明确允许 suspend；other 的元素可 nullable，输出 R 仍非空。

| API | 谁触发 / 首值条件 | 完成 / 错误 | 业务选择 |
|---|---|---|---|
| `combineLatest(other, transform)` | 两边各有首值后，任一侧变化取各自最新值 | 原生 combine 适配；测试覆盖两侧完成后终止、empty 与有限 source 组合无输出；错误失败 | 表单校验、筛选条件；不保证快源每个中间值都一一组合 |
| `withLatestFrom(other, transform)` | **仅 receiver** 发值触发；other 未有首值时跳过 | other 完成后保留最后值；other 错误整链失败；receiver 完成取消 other | 点击提交 + 当前表单；`clicks.withLatestFrom(form)`，方向不能颠倒 |
| `zipWith(other, zipper)` | 第 n 项和第 n 项配对 | 某侧完成且无可配对值后结束，取消另一侧 | 两份有序序列逐项配对；不是最新状态同步 |
| `concatWith(other)` | receiver 完成后再订阅 other | 错误不进入 other；两边正常完成才完成 | 串行阶段；receiver 无限则 other 永不开始 |
| `mergeWith(other)` | 两边任意值直接交错转发 | 等全部完成；首错取消其他 | 同类型多事件源汇合；不是把两个值组合成一个对象 |

`withLatestFrom(empty())` 没有最新值，会持续跳过 receiver 值直至 receiver 结束；不要误解为立即提供默认值。需要初值时用 `startWithItem` 或合适的 StateFlow。`combineLatest` 对 empty+never 的挂起边界由当前原生 combine 实现决定，有限源测试不能证明所有空源组合立即完成。

## 7. 门控与截断：丢值、停源还是延后启动

| API | 开始收集主源的时间 | gate / 完成语义 | 使用场景 |
|---|---|---|---|
| `takeUntil(stopPredicate: suspend (T) -> Boolean)` | 立即 | **先发当前值，再判断**；true 结束 | 下载进度中保留最后一个 100% |
| `takeUntil(other)` | gate 与主源都接入 | other 首值或正常完成使主链完成并取消；other 错误失败 | 用户取消信号 / 外部停止条件；不同于 dispose 无完成信号 |
| `skipUntil(other)` | 主源立即运行 | gate 前丢值；other 首值或正常完成打开 gate；other 错误失败 | 授权信号后才转发；不能阻止 gate 前的请求副作用 |
| `delaySubscription(other)` | **触发前不订阅主源** | other 首值或正常完成才启动；错误则不启动并失败 | SDK ready 后启动；要明确 empty 是否应当算 ready |

本库 gate 会把 other 的正常完成当触发，不能照搬其他 Rx 实现关于“仅发值才触发”的记忆。同步 `takeUntil(empty())` 的测试还验证主源会经历订阅并立即释放，不保证完全没有订阅副作用；如需确保主源不启动，先在业务层决定是否订阅。

## 8. 时间：计时点、尾值与通知线程

全部为 Flow 入口，返回 RxFlow，默认 `Schedulers.computation()`；每个函数都有显式 Scheduler overload。时间 scheduler 参与计时/通知，不等于统一的 subscribeOn 或 Main 保证。

| API | 参数校验 | onNext / onComplete / onError | 场景 / 易错点 |
|---|---|---|---|
| `delay(duration[, scheduler])` | duration ≥ 0 | 值与完成延迟；错误立即调度，不等 duration，可能取消尚未交付的延迟值 | 只延后通知，source 的副作用已经执行 |
| `delaySubscription(duration[, scheduler])` | duration ≥ 0 | 到时才订阅主源 | 延后请求执行；取消计时可阻止订阅 |
| `throttleFirst(windowDuration[, scheduler])` | windowDuration ≥ 0 | 首值立即通过，然后关闭 gate 一段时间；terminal 立即转发 | 防连点；通过的值仍在上游通知线程，scheduler 负责重开 gate |
| `throttleLast(period[, scheduler])` | period > 0 | 周期发送期间最近值；无新值不重复；完成/错误丢弃未采样尾值 | 降频进度；**可能漏最终 100%**，不能当最终结果保证 |
| `throttleWithTimeout(timeout[, scheduler])` | timeout ≥ 0 | 新值重置等待；静默满 timeout 后发最新；**正常完成立即 flush 尾值**；错误不 flush | 搜索输入防抖；完成 flush 可能在上游线程，UI 后加 observeOnMain |

`throttleFirst` 的窗口跟随通过项开始；`throttleLast` 的采样从订阅开始按周期运行；`throttleWithTimeout` 跟随最后一项重新计时。它们不是同一个“节流”开关。

时间示意（窗口 100ms，避开边界竞争）：

```text
输入:                0:A   30:B   60:C                    170:D       结束:250
throttleFirst:       0:A                                  170:D
throttleLast:                       100:C                         200:D
throttleWithTimeout:                                  160:C           250:D(flush)
```

测试应避开同一时刻事件顺序不明的断言。虚拟时间测试用目标源码里的 `TestFlowScheduler`，它是 test source，不能作为生产依赖类导入。

## 9. 副作用与 finally：挂在哪个信号上

除 map/filter 外，下列副作用都有 Flow/RxFlow 入口，均为**同步 callback**，不消耗/恢复错误，不产生业务值。它们的执行线程取决于所处的信号路径。

| API | 何时执行 | 参数 / 次序 | 抛错与取消边界 |
|---|---|---|---|
| `doOnSubscribe(action)` | 上游 onSubscribe 到达时 | `(FlowDisposable) -> Unit`；在下游 onSubscribe 前 | action 抛错会释放上游并下发错误；不因后面的 observeOn 保证 Main |
| `doOnNext(action)` | 每个值交付下游前 | `(T) -> Unit` | action 错误导致流失败，该值不继续交付 |
| `doAfterNext(action)` | 值交付下游后 | `(T) -> Unit` | 值已经交付；action 错误导致后续失败 |
| `doOnError(action)` | 错误交付下游前 | `(Throwable) -> Unit` | action 错误与原错误组合；记录错误不等于处理错误 |
| `doOnComplete(action)` | 正常完成交付前 | `() -> Unit` | action 错误把完成变为失败；取消不执行 |
| `doOnTerminate(action)` | 正常完成或错误交付前 | `() -> Unit` | 不覆盖取消；错误路径二次错误组合，完成路径回调错变失败 |
| `doAfterTerminate(action)` | terminal 交付后 | `() -> Unit` | 不覆盖取消；失败已无下游可交付，进入插件 |
| `doOnDispose(action)` | dispose 经过该节点时 | `() -> Unit` | 正常完成不等于 dispose；action 错误交插件，仍释放上游 |
| `doFinally(action)` | 完成/错误交付后，或 dispose 清理时 | `() -> Unit`；每次订阅原子保证一次 | callback 错误交插件；取消时可能运行在 dispose 调用线程，**不是 Main 保证** |
| `doOnLifecycle(onSubscribe, onDispose)` | 上述两个节点的组合 | 两个同步 callback | 只是副作用组合，不是 Android Lifecycle 绑定 |
| `doOnEach(onNext = {}, onError = {}, onComplete = {})` | 上述三个节点组合 | 不是 RxJava Notification 参数 | 不含取消；仍需 terminal onError |
| `debug(identifier: String? = null, trimOutput = false)` | subscribed/next/error/completed/disposed 旁路 | `FlowDebugEvent` 发往 `FlowPlugins.onLog` | trimOutput 把日志 value 替换为最多 30 字符加省略号的字符串，数据链原值不变；不是脱敏 |

不要用 `doOnComplete` 隐藏所有退出路径的 loading。需要统一清理可用 doFinally，但 UI 清理要显式调度 Main；搜索 inner 切换的 finally 还可能把新请求 loading 关闭，应把 loading 设计成当前请求的状态。

## 10. 调度函数：任务与信号分别在哪执行

| API | 完整参数 / receiver | 语义 |
|---|---|---|
| `subscribeOn(scheduler)` | Flow / RxFlow | 调度上游订阅；同步 source 从该位置开始；不改变外部 SDK 未来 callback 的线程 |
| `observeOn(scheduler, delayError = false, bufferSize = 128)` | Flow / RxFlow；bufferSize > 0 | 序列化调度其后的 onNext/terminal；false 时错误可越过未消费队列；true 先排队列再报错；**不调度 onSubscribe** |
| `unsubscribeOn(scheduler)` | Flow / RxFlow | 调度往上游的 dispose；不是 suspend 清理等待，也不安排下游 UI |
| `subscribeOnComputation / IO / NewThread / Single / Trampoline()` | Flow / RxFlow | 等价对应 subscribeOn |
| `observeOnComputation / IO / NewThread / Single / Trampoline(delayError = false)` | Flow / RxFlow | 等价对应 observeOn；这些便捷入口未暴露 bufferSize |
| `subscribeOnMain()` / `unsubscribeOnMain()` | Android，Flow / RxFlow | 对应 Android Main scheduler |
| `observeOnMain(delayError = false, bufferSize = 128)` | Android，Flow / RxFlow | UI 通知边界；同样不保证 doFinally 的取消路径在 Main |

`Schedulers.computation()` 使用 Default dispatcher，`io()` 使用 IO dispatcher，`single()` 共享单线程 dispatcher，`newThread()` 每个 Worker 建专属线程，`trampoline()` 当前线程排队执行，`from(dispatcher)` 适配指定 dispatcher。不要在 trampoline 做阻塞等待其队列中另一个任务完成。

**bufferSize 不是容量上限**：此版本 observeOn 使用 `SpscLinkedArrayQueue`，参数决定分段队列大小，可继续扩展；RxFlow.collectSafely 的桥接还使用 `Channel.UNLIMITED`。原生 `.buffer(n)` 放在 RxFlow 之后不能倒推 Rx 源具备 request/backpressure 协议。若生产长期快于消费，须在源头限速、合并、采样或设计有界适配。

直接调度 API：`Scheduler.createWorker()`；`scheduleDirect(action)` / `scheduleDirect(action, delay)`；`Worker.schedule(action)` / `schedule(action, delay)` / `schedulePeriodically(action, initialDelay, period)`；任务返回 FlowDisposable，Worker.dispose 取消所属任务；受 `FlowPlugins.setScheduleHandler` 装饰。Android 另有 `scheduleDirectOnMain(Runnable)` / `(Runnable, delay: Long, unit: TimeUnit)`，负延迟按零处理，可取消未执行消息。精确签名见快照。

## 11. 订阅与阻塞终端

| 终端 | 返回 / callback | 约束 |
|---|---|---|
| `subscribe()` | FlowDisposable | 不消费值且无业务错误回调；仅了解其存在，不作为生产默认模板 |
| `subscribe(onNext)` | FlowDisposable | 默认错误包装为 FlowOnErrorNotImplementedException 交插件 |
| `subscribe(onNext, onError)` | FlowDisposable | 通常首选；两 callback 同步、不能 suspend |
| `subscribe(onNext, onError, onComplete)` | FlowDisposable | 只在正常完成调用 onComplete |
| `subscribe(observer: FlowObserver<T>)` | Unit | 通过 observer.onSubscribe 获得句柄 |
| `subscribeWith(observer: E)` | 原 observer E | 适合 DisposableFlowObserver 子类，自己持有取消权 |
| `blockingFirst()` / `blockingFirst(defaultValue)` | 首项 | 无默认且空流抛错；有默认仅空完成时使用；拿首项后取消剩余 |
| `blockingLast()` / `blockingLast(defaultValue)` | 最后项 | 等整个源完成；never/无限流一直阻塞；错误不被 default 吞掉 |
| `blockingForEach(onNext)` | Unit | 阻塞处理各值，回调错传播 |
| `blockingSubscribe()` / `(onNext)` / `(onNext,onError)` / `(onNext,onError,onComplete)` | Unit | 等 terminal；缺 onError 走插件；此版本无 timeout overload |

阻塞终端仅允许测试或明确可阻塞后台线程，不用于 Android Main。`subscribe` 可同步执行 callback，不要在 callback 引用尚未由返回值赋值的 lateinit disposable；需要订阅握手时用 observer.onSubscribe。

## 12. Android 生命周期过滤与取消

| API / 所在包 | 参数族与返回 | 语义 / 选择 |
|---|---|---|
| `autodispose.autoDisposable` | LifecycleOwner / Lifecycle + untilEvent=ON_DESTROY；View + checkAttached=true；ViewModel；返回 converter | onReady 握手完成后才启动上游；ON_ANY 非法 |
| 核心 `autoDisposable` | CoroutineScope / FlowScopeProvider | 只读 Job 结束信号，scope 无 Job 抛参数错误，不继承 dispatcher |
| `Flow/RxFlow.bindLifecycle` | owner / lifecycle / view / viewModel；返回 FlowSubscribeProxy | 与 `.to(autoDisposable(...))` 对应；**没有 Flow.bindLifecycle(CoroutineScope) overload**，scope 用核心 converter |
| `FlowLifecycle.bindLifecycle` | owner / lifecycle / view / viewModel / scope；返回 converter | 静态 facade，不是直接订阅 |
| `FlowDisposable.bindLifecycle` | owner / lifecycle / view；返回包装后的 FlowDisposable | 订阅后绑定，源可能已发值；没有 ViewModel 或 scope overload；优先订阅前 converter |
| `asFlowScopeProvider` | owner/lifecycle + untilEvent；view + checkAttached；核心 CoroutineScope | 自定义 converter 组合；不是数据 Flow |
| `Flow/RxFlow.filterWhen`，`com.xxf.coroutines.android.lifecycle` | owner / lifecycle + vararg atLeastState | 每个值读取 currentState，满足任一个 `isAtLeast` 就通过；零状态全丢；不缓存、不取消、不重放 |
| `FlowDisposable.collectTo(destination)` / `bindDisposableContainer(destination)` | FlowDisposableContainer；**返回 Boolean** | 结果是 add 是否接受，不能再 `.dispose()` 链式调用 |

`filterWhen(STARTED, RESUMED)` 是 OR 的至少状态判断，等效阈值 STARTED，不是仅 STARTED/RESUMED 精确枚举。后台丢掉的值回前台不会补发。需要可见期间停源并恢复时，设计 repeatOnLifecycle/重订阅机制；AutoDispose 单次结束不会恢复。

Fragment 更新 View 用 viewLifecycleOwner。View 默认要求订阅时已 attach，未 attach 走 outside-scope，`checkAttached=false` 只跳过初始检查，不等待 attach；之后 detach 结束。已销毁 Lifecycle 走 outside-scope；未设置 outside handler 时错误交订阅，handler 正常处理后仅取消。指定 untilEvent 是事件监听，不是“等待到某状态开始运行”。

## 13. 资源、Scope 与全局插件协议

| 类型 / API | 功能与关键差别 |
|---|---|
| `FlowDisposable` | `isDisposed`、幂等 dispose；工厂 `disposed()`、`empty()`、`fromAction(action)`（首次释放调用一次） |
| `FlowDisposableContainer` | add 接管；remove 删除并释放；delete 删除但不释放 |
| `CompositeFlowDisposable` | 构造支持 empty/vararg/Iterable；add/addAll/size；clear 释放现有但可复用；dispose 永久关闭，再 add 立即释放；释放错误可能同步抛出/组合 |
| `SerialFlowDisposable` | 构造可带初值；get；set 释放旧值；replace 不释放旧值；dispose 永久关闭，后续 set/replace 的新值会被释放 |
| `DisposableFlowObserver<T>` | onSubscribe 保存单个 upstream，dispose 取消；可覆写 protected onStart，子类实现三个数据/terminal 回调；不要手动调用 onSubscribe |
| `FlowConverter<T,R>` | apply(RxFlow<T>)；`Flow/RxFlow.to(converter)` 得 R；不是 Kotlin Pair 的 to |
| `FlowSubscribeProxy<T>` | 仅 subscribe/subscribeWith 终端，继承 observer subscribe 协议；不能再 map/observeOn |
| `FlowScopeProvider` | requestScope 每订阅独立解析；`UNBOUND` 只握手、不结束，不是自动安全取消 |
| `FlowScopeSource` / `FlowScopeObserver` | onSubscribe → onReady → onComplete/onError；自定义 scope 必须 ready 后才允许启动源 |
| `ManualFlowScopeProvider` | end/dispose/close 幂等结束作用域；结束后不可重开；供显式 owner / 测试 |
| `FlowPlugins` | set/getErrorHandler、set/getScheduleHandler、set/getLogHandler；公开 onError、onSchedule；internal onLog 供 debug 使用；reset；lockdown/isLockdown |
| `FlowAutoDisposePlugins` | set/getOutsideScopeHandler、reset；仅 outside-scope 策略，不是所有错误的吞错器 |
| `FlowDebugEvent` | kind/label/value/error；Kind = SUBSCRIBED/NEXT/ERROR/COMPLETED/DISPOSED；终态后 dispose 不再记录 DISPOSED |
| `CompositeFlowException` | errors: List<Throwable>；源与回调/资源释放等多错误组合 |
| `FlowUndeliverableException` | 已终止后迟到错误的包装 |
| `FlowOnErrorNotImplementedException` | 缺少订阅 onError 的错误包装 |
| `FlowProtocolViolationException` | Observer/Disposable 握手协议问题 |
| `OutsideFlowScopeException` | 无效生命周期/作用域的错误 |

全局插件由应用基础设施统一安装；局部示例/测试保存并恢复 handler。lockdown 后配置/reset 不能再随意变更。不要用全局错误 handler 取代每条业务链的 onError。

## 14. 同模块原生协程转换辅助函数

这四个函数不在 rxstyle.flow 包，不受 RxStyle `T : Any` 限制；不要混淆调度默认值。

| 包 / API | 参数与返回 | 使用边界 |
|---|---|---|
| `transform.suspend2flow.suspendAsFlow` | dispatcher=Dispatchers.IO、block: suspend () -> T；Flow<T> | 每次 collect 在 dispatcher 执行一次，发值并完成；与不自动 IO 的 Flows.fromCallable 不同 |
| 同包 `(suspend () -> T).asFlow` | dispatcher=Dispatchers.IO；Flow<T> | 点语法，同上；不是 Iterable.asFlow |
| `transform.flow2stateflow.Flow<T>.asStateFlow` | scope、initialValue、started=WhileSubscribed(5_000)；StateFlow<T> | 委托 stateIn；异常让共享协程失败，不自动变为状态值 |
| `transform.suspend2stateflow.suspendAsStateFlow` | scope、initialValue、dispatcher=IO、started=WhileSubscribed(5_000)、block；StateFlow<T> | 一次 suspend source 经 stateIn 共享；不是轮询，不保证进程存活或错误状态 |

将异常映射成业务状态应在 stateIn/asStateFlow 之前完成。state holder 不发 terminal 错误，不代表源不会失败。共享启动策略停止后再启动可能重新执行 cold 请求，缓存有效期必须由业务定义。

## 15. 验证清单

- 查快照中的 receiver、包、参数名、返回值、suspend，不根据 RxJava 经验补 overload。
- 明确空值/空流/失败/取消/永不完成；说明错误恢复后事件流是否继续。
- 每个 callback/inner 的调度与 owner 可解释；复杂链给出值、错误、取消的预期轨迹。
- 新业务测试覆盖真实边界：切换取消、串行副作用、inner 失败后的第二次输入、尾值、生命周期取消和资源释放；不要只断言调用了某个函数。
- 时间/gate/重试细节定位到 `FlowTimeExtensionsTest`、`FlowCombineGateTest`、`RxFlowRetryDistinctTest`、`RxFlowTransformTest` 与对应 internal 实现。
