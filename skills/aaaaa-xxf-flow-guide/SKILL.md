---
name: aaaaa-xxf-flow-guide
description: 面向 KPower RxStyle Flow 与 reactive-coroutines-android 的订阅、Scheduler、Disposable、错误处理和生命周期使用指南；用于 RxJava Observable 迁移及 Flow 业务链路设计。
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
2. 识别当前使用场景，按下表只读相关 reference；混合场景再读共同语义章节。
3. 以目标仓库当前源码、README 和测试为准复核签名和行为。本 skill 的 API 事实来自所引用的 `KPower/core/reactive-coroutines` 与 `xxf_android/core/reactive-coroutines-android` 检出版本。
4. 先选 source 和错误路径，再定调度和取消所有者；给出完整可理解的链路和适用边界。
5. 检查静态类型、扩展函数 import、RxFlow / 原生 Flow 语义边界、nullable 和 Android/JVM 模块边界。

| 需要处理 | 阅读资料 |
|---|---|
| 订阅、source、operator、线程、错误、类型与 RxJava 对照 | [核心概念与 API](references/rxstyle-flow-guide.md) |
| 按业务选用法、端到端代码、生命周期、回调和资源归属 | [场景手册](references/scenario-playbook.md) |
| 不知道操作符是否存在、签名/参数语义是什么 | [API 目录](references/api-catalog.md)，再回源码确认 |

## 必须遵守的语义

- 本库的 `subscribe` 是非 suspend API，不要求调用方传 `CoroutineScope`。裸订阅默认从调用线程开始；阻塞 source 需显式调度。
- `subscribeOn` 管上游订阅，`observeOn` 管其后 Observer 信号，`unsubscribeOn` 管上游释放。Android UI 更新必须显式切 Main；Lifecycle 绑定不会替代 `observeOn`。
- 有限任务可自然终止；需要提前停止的订阅必须保存 `FlowDisposable` 或用适当的容器管理。`dispose()` 只取消，不发送 `onComplete`。
- `to(autoDisposable(...))` 放在 operator 链末端；它按每次订阅绑定 scope，正常 scope 结束只取消该订阅。返回 proxy 只能调用 terminal API。
- 显式提供 `onError`。省略错误回调的订阅会交给 `FlowPlugins`；不能静默吞错。
- RxStyle `T` 要求非空。nullable 数据先在原生 Flow 阶段处理。操作符回调是否支持 suspend 必须看签名。
- `RxFlow` 同时实现 `Flow`。静态类型被收窄成 `Flow<T>` 后，同名扩展可能解析到 kotlinx Flow operator；检查 receiver、import 和推断类型。
- 该链路不提供 Flowable 背压协议。不能把 `observeOn(bufferSize)`、`interval` 或 callback 适配描述成自动具备无界/无损背压能力；`fromCallback` 参考实现的 `onNext` 使用 `trySend` 且不返回发送结果，高频源需评估缓冲满时的事件丢失。
- 阻塞 API 仅供测试或允许阻塞的后台线程使用；Android 主线程禁止调用。

## 交付要求

实现建议须清楚交代 source/operator、订阅与通知线程、取消归属、错误路径和生命周期边界。版本差异或源码未确认的行为要明确标为待核实，不得宣称未经测试的 RxJava 1:1 兼容。
