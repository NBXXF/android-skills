---
name: aaaaa-xxf-flow-guide
description: 深度指导 KPower reactive-coroutines 与 reactive-coroutines-android：完整操作符/重载查询、响应式链路选型、搜索切换、串行任务、组合门控、时间、错误隔离、线程及生命周期；用于 Flow 实战、Vibe Coding 与 RxJava Observable 迁移。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# RxStyle Flow 使用指南

## 目标

帮助 AI 和 Vibe Coding 正确使用 KPower `reactive-coroutines` 的 RxJava Observable 风格 API。该库以 Kotlin `Flow` 为基础，并提供独立的 Observer/Disposable 订阅链；相似的 API 名称不代表它与 RxJava 或 kotlinx Flow 的所有语义完全相同。

## 触发场景 / 适用范围

- 业务代码使用 `Flows`、`RxFlow`、`subscribe`、`FlowDisposable`、`Schedulers` 或本库的 Rx 命名操作符。
- 用户要求把 RxJava/Observable 迁移到 Flow，或询问非 suspend 订阅、线程切换、取消、回调适配、错误恢复。
- Android 工程使用 Lifecycle、View detach、`autoDisposable`、`bindLifecycle`、`AndroidSchedulers` 或 `filterWhen`。

## 使用顺序

1. 先确认目标仓库的依赖模块、版本、Gradle 声明、静态类型与 import；不能从本 skill 推测坐标或版本。
2. 先写业务契约：输入是事件还是状态、输出类型、是否保序/取消旧任务/允许并发、单次失败是否允许继续、线程与取消 owner。再按下表读取相关 reference。
3. 以目标仓库当前源码、README 和测试为准复核签名和行为。本 skill 的 API 事实来自所引用的 `KPower/core/reactive-coroutines` 与 `xxf_android/core/reactive-coroutines-android` 检出版本。
4. 先选 source 和错误路径，再定调度和取消所有者；给出完整可理解的链路和适用边界。
5. 检查静态类型、扩展函数 import、RxFlow / 原生 Flow 语义边界、nullable 和 Android/JVM 模块边界。

| 需要处理 | 阅读资料 |
|---|---|
| 订阅、source、operator、线程、错误、类型与 RxJava 对照 | [核心概念与 API](references/rxstyle-flow-guide.md) |
| 业务意图如何变成正确链路、搜索/串行写入/缓存/轮询、错误范围与反例 | [响应式设计与组合](references/reactive-design.md) |
| 每个操作符的参数族、suspend、完成/错误/取消、线程、位置与边界 | [操作符完整语义](references/operator-reference.md) |
| 生命周期、回调、资源归属与原有快速场景 | [场景手册](references/scenario-playbook.md) |
| 按包/文件查全部 API、维护索引 | [API 导航](references/api-catalog.md) |
| 精确查询 receiver、泛型、所有显式重载、默认参数与 suspend | [公开函数签名快照](references/api-signatures.md)，按文件局部读取，再回当前源码确认 |

## 必须遵守的语义

- 本库的 `subscribe` 是非 suspend API，不要求调用方传 `CoroutineScope`。裸订阅默认从调用线程开始；阻塞 source 需显式调度。
- `subscribeOn` 管上游订阅，`observeOn` 管其后 onNext/terminal 通知（不调度 onSubscribe），`unsubscribeOn` 管上游释放。Android UI 更新必须显式切 Main；Lifecycle 绑定不会替代 `observeOn`。
- 有限任务可自然终止；需要提前停止的订阅必须保存 `FlowDisposable` 或用适当的容器管理。`dispose()` 只取消，不发送 `onComplete`。
- `to(autoDisposable(...))` 放在 operator 链末端；它按每次订阅绑定 scope，正常 scope 结束只取消该订阅。返回 proxy 只能调用 terminal API。
- Android ViewModel 可用 `Flow<T>.bindLifecycle(viewModel)` / `RxFlow<T>.bindLifecycle(viewModel)`，也可用 `FlowLifecycle.bindLifecycle(viewModel.viewModelScope)` 创建 converter；ViewModel 清除时取消订阅。`CoroutineScope` 只提供取消边界，不负责切换数据链 dispatcher。
- 显式提供 `onError`。省略错误回调的订阅会交给 `FlowPlugins`；不能静默吞错。
- RxStyle `T` 要求非空。nullable 数据先在原生 Flow 阶段处理。操作符回调是否支持 suspend 必须看签名。
- `RxFlow` 同时实现 `Flow`。静态类型被收窄成 `Flow<T>` 后，同名扩展可能解析到 kotlinx Flow operator；检查 receiver、import 和推断类型。
- 该链路不提供 Flowable 背压协议。`observeOn(bufferSize)` 使用可增长分段队列，bufferSize 不是积压上限；RxFlow → collect 桥接使用无界 channel。不能把时间/缓冲/桥接操作符当作自动限流；`fromCallback` 参考实现的 `onNext` 使用 `trySend` 且不返回发送结果，高频源需评估缓冲满时的事件丢失。
- `map/filter` 的本库专用声明仅在 RxFlow；普通 Flow 的同名 kotlinx operator、组合函数的 suspend transform 与本库同步 transform 不得混淆。`fromCallable/fromSuspend/create/defer` 支持 suspend，但不自动切 IO；同模块 `suspendAsFlow` 默认 IO。
- `concatMap/switchMap` transform 是同步 factory；返回惰性 inner，在 `fromCallable/defer` 内做请求。concatMap 串行订阅 inner，但 transform 在 outer 到达时已执行；不能在 factory 中提前做副作用。
- 长期事件源的单次任务错误在 inner 内恢复；在 switchMap/concatMap 外恢复会让整条事件流先终止。retry 是额外次数，repeat 是总次数；重试写操作必须确认幂等性。
- empty fallback 只响应零项正常完成；门控 other 的正常完成也会触发。takeUntil(predicate) 包含触发项。throttleLast 丢完成前未采样尾值，throttleWithTimeout 正常完成 flush 尾值。
- `filterWhen` 是每值按至少状态 OR 判断，不停上游、不重放；AutoDispose 只取消一次订阅，不自动重启。没有直接 `Flow.bindLifecycle(CoroutineScope)`，scope 用 `to(autoDisposable(scope))`。
- `doFinally` 覆盖完成/失败/取消，但取消清理可能在 dispose 线程；不能因为前面有 observeOnMain 就直接断言 finally 可操作 UI。
- 阻塞 API 仅供测试或允许阻塞的后台线程使用；Android 主线程禁止调用。

## 禁止事项

- 禁止虚构当前模块不存在的 RxStyle flatMap、exhaustMap、timeout、retryWhen 或未确认的重载；需要时显式进入原生 Flow 并给出 import/类型边界。
- 禁止嵌套 subscribe 或在 callback 里随意 launch，让子任务脱离主链取消与错误归属。
- 禁止把只读任务的 switchMap 随意用于必须完成的写操作，或把多处订阅当共享/缓存。
- 禁止只给函数名而不交代业务效果；复杂链必须说明值、错误和取消轨迹。

## 验证 / 审查清单

- 按签名快照核对 receiver、参数名、返回类型与 suspend；泛型能容纳 Loading/Data/Failure，不让子类推断锁死 fallback。
- 覆盖关键业务边界：第二次输入、inner 错误后继续、旧请求取消、实际副作用保序、时间尾值、生命周期结束、资源解绑。
- 线程检查同时覆盖 onSubscribe、正常通知和 dispose/finally；确认缓冲与队列增长策略。
- 维护本 skill 时运行 `scripts/build-api-snapshot.py --core <模块根目录> --android <模块根目录> --check` 检查源码漂移，并按 skill-manage 同步三处实体目录；更新操作见 [API 导航](references/api-catalog.md)。

## 交付要求

实现建议须清楚交代输入/输出、source/operator 选择理由、inner 并发策略、订阅与通知线程、取消归属、错误范围和生命周期边界；给出有类型的代码与必要 import，说明实际执行的验证。版本差异或源码未确认的行为要明确标为待核实，不得宣称未经测试的 RxJava 1:1 兼容。
