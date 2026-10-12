# RxStyle Flow API 目录

这是按参考源码整理的导航，不替代当前依赖版本的 API Reference。扩展函数尤其要检查 import 和静态 receiver；函数没有出现在本目录不代表目标版本没有它，函数出现也不保证目标版本签名相同。

## 目录

- [Source factories](#source-factories)
- [订阅与 Observer](#订阅与-observer)
- [操作符类别](#操作符类别)
- [调度器](#调度器)
- [Disposable 家族](#disposable-家族)
- [AutoDispose 与 Android 扩展](#autodispose-与-android-扩展)
- [阻塞终端 API](#阻塞终端-api)
- [快速定位源码](#快速定位源码)

## Source factories

核心包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。参考 `Flows.kt`；下表只列方法名和实用语义，不展开所有 overload。

| 分类 | API | 语义/提醒 |
|---|---|---|
| 固定 source | `just`、`empty`、`error`、`never` | `never` 仅在取消时结束；`error` 在订阅收集时失败。 |
| 延迟/计算 | `defer`、`fromCallable`、`fromSupplier`、`fromSuspend` | 每次订阅重新调用 factory；不会因为 callable 而自动切 IO。 |
| Kotlin 集合 | `fromArray`、`fromIterable`、`fromSequence`、`range`、`rangeLong` | `range(start, count)` 的第二个参数是数量。 |
| callback/action | `fromCallback`、`create`、`fromAction`、`fromRunnable`、`fromResult` | `create` 是顺序 FlowCollector block；callback 应用 `fromCallback`；action/runnable 不发值。 |
| 时间 | `timer`、`interval`、`intervalRange` | timer 单次发 `0L` 后结束；interval 无限；intervalRange 有限。 |
| resource | `using` | 每次收集创建资源，结束/失败/取消后同步 disposer。 |
| 多 source | `concat`、`merge` | concat 顺序订阅；merge 合流，不能假设固定交错顺序。 |
| 包装 | `wrap` | 普通 Flow 惰性进入 RxFlow；已有 RxFlow 保持原实例。 |

RxStyle 工厂值类型为 `T : Any`。目标使用 nullable 元素时，先保留 native Flow 或在进入 RxStyle 前转换。

## 订阅与 Observer

`FlowRxInterop.kt` 为普通 `Flow<T>` 提供以下扩展，`RxFlow` 自身也实现 `Flow` 订阅源：

```kotlin
fun Flow<T>.subscribe(): FlowDisposable
fun Flow<T>.subscribe(onNext: (T) -> Unit): FlowDisposable
fun Flow<T>.subscribe(onNext: (T) -> Unit, onError: (Throwable) -> Unit): FlowDisposable
fun Flow<T>.subscribe(
    onNext: (T) -> Unit,
    onError: (Throwable) -> Unit,
    onComplete: () -> Unit
): FlowDisposable
fun Flow<T>.subscribe(observer: FlowObserver<T>)
fun <E : FlowObserver<T>> Flow<T>.subscribeWith(observer: E): E
```

KDoc/源码通常把 RxStyle 类型约束写为 `T : Any`。观察者接口的协议是：

```kotlin
interface FlowObserver<in T : Any> {
    fun onSubscribe(disposable: FlowDisposable)
    fun onNext(value: T)
    fun onError(throwable: Throwable)
    fun onComplete()
}
```

Observer 形式会通过 `onSubscribe` 交付句柄；lambda 重载直接返回句柄。subscribe 本身不是 suspend；异步完成并不意味着订阅函数必须挂起。

## 操作符类别

### 转换、过滤、生命周期回调

核心 RxFlow operator（`RxFlowOperators.kt`）包括：

- `map((T) -> R)`、`filter((T) -> Boolean)`。
- `doOnNext`、`doAfterNext`、`doOnError`、`doOnComplete`。
- `doOnTerminate`、`doAfterTerminate`、`doOnDispose`、`doOnSubscribe`、`doFinally`。

这些是同步 callback 签名；异常通常会成为订阅错误或不可交付错误，具体 callback 二次异常需查实现和测试。另有 `FlowLifecycleExtensions.kt` 的普通 Flow 入口及 `doOnLifecycle`、`doOnEach`，按具体 overload 核实。

### 变换与 fallback

- `skip(count)`、`skipWhile(predicate)`、`ofType<R>()`。
- `switchMap(transform)`：最新 inner 胜出，新 outer 值会取消旧 inner。
- `concatMap(transform)`：inner 按 outer 到达顺序串行执行。
- `defaultIfEmpty(value)`、`switchIfEmpty(fallback)`、`startWithItem`、`startWith`、`startWithArray`、`startWithIterable`。
- `onErrorReturnItem(value)`、`onErrorReturn(supplier)`、`onErrorResumeNext(fallback)`、`onErrorComplete(predicate)`。
- `retry()`、`retry(times)`、`retry(times, predicate)`、`retryUntil(stop)`；retry 的 `times` 表示额外重试次数。
- `repeat()`、`repeat(times)`、`repeatUntil(stop)`；repeat 的 `times` 表示 source 总订阅次数，`repeatUntil` 的 stop callback 在每次正常完成后调用且支持 suspend。

大部分严格 RxFlow transform/predicate 是普通 lambda。`onErrorComplete()` 的默认 predicate 会接受所有异常，因此可能把错误转成正常完成；只在明确业务允许时使用。

### 多 source 与门控

- `combineLatest(other, transform)`：在双方各有首值后，任一侧更新会用最新值计算。
- `withLatestFrom(other, transform)`：仅当前 source 发值时计算，other 无值时当前值被跳过。
- `zipWith(other, zipper)`：按位置配对。
- `concatWith(other)`、`mergeWith(other)`。
- `takeUntil(predicate)`：参考版本是 native `Flow` 入口，predicate 为 suspend，当前元素先 emit 再判断停止。
- `takeUntil(other)`、`skipUntil(other)`：other 首次发值或正常完成会触发 gate；other 错误会失败。
- `delaySubscription(other)`：other 首次发值或正常完成后订阅主 source。

多 source 的完成、空值和错误语义不要从名字猜测；在当前源码及 `FlowCombineGateTest` 里核实。

### 时间操作符

参考 `FlowTimeExtensions.kt`，使用 `kotlin.time.Duration`：

| API | 行为 |
|---|---|
| `delay(duration[, scheduler])` | 延迟数据通知；源码注释说明错误默认不延迟。 |
| `delaySubscription(duration[, scheduler])` | 延迟订阅 source。 |
| `delaySubscription(other)` | other 触发后才订阅 source。 |
| `throttleFirst(duration[, scheduler])` | 时间窗口保留第一个值。 |
| `throttleLast(period[, scheduler])` | 周期 sample；参考实现默认不发送窗口末尾残留值。 |
| `throttleWithTimeout(timeout[, scheduler])` | timeout/debounce 风格。 |

不要把不同时间 API 的 scheduler 作用点、最后一个窗口值或错误时点假定为相同。时间行为测试见 `FlowTimeExtensionsTest` 和 `RxFlowTimeSourceTest`。

### 生命周期与诊断

其他 operator/file 包括 `distinctUntilChanged`（含 key selector/equality overload）、`distinctUntilChangedByHash`、`debug`、`start/empty` 系列及阻塞 API。使用前 `rg` 目标版本源码查精确名称与 overload，避免把 Kotlin 标准库或 kotlinx Flow operator 当成本库 operator。

## 调度器

核心包下子包 `com.nbxxf.kpower.coroutines.rxstyle.flow.schedulers`：

- `Schedulers.computation()`、`io()`、`single()`、`newThread()`、`trampoline()`、`from(CoroutineDispatcher)`。
- `subscribeOn(Scheduler)`、`observeOn(Scheduler, delayError = false, bufferSize = 128)`、`unsubscribeOn(Scheduler)`。
- 便捷 operator `subscribeOnComputation()`、`subscribeOnIO()`、`subscribeOnNewThread()`、`subscribeOnSingle()`、`subscribeOnTrampoline()`。

Android 包 `com.xxf.coroutines.android.schedulers`：

- `AndroidSchedulers.mainThread()`。
- `subscribeOnMain()`、`observeOnMain(delayError, bufferSize)`、`unsubscribeOnMain()`。

线程职责在 [核心概念与使用指南](rxstyle-flow-guide.md#线程与调度) 中有解释。

## Disposable 家族

子包 `com.nbxxf.kpower.coroutines.rxstyle.flow.disposables`：

| API | 用途 | 重点语义 |
|---|---|---|
| `FlowDisposable` | 单订阅取消协议 | `isDisposed` + 幂等 `dispose()`。 |
| `FlowDisposableContainer` | 管理协议 | `add/remove/delete`。 |
| `CompositeFlowDisposable` | 多个独立订阅 | 支持 `add/addAll/size/clear/dispose`；`clear` 可复用，`dispose` 永久关闭。 |
| `SerialFlowDisposable` | 只持有一个当前订阅 | `set` 释放旧值；`replace` 不释放旧值。 |
| `DisposableFlowObserver` | observer 同时持有 disposable | 适合封装自管理订阅的 observer。 |

Android 子包 `com.xxf.coroutines.android.disposables` 增加 `FlowDisposable.collectTo(container)` 和 `bindDisposableContainer(container)` 便捷扩展。

## AutoDispose 与 Android 扩展

核心子包 `com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`：

- `autoDisposable(scope: CoroutineScope)` 或 `autoDisposable(scopeProvider)` 创建 converter。
- `Flow<T>.to(converter)` / `RxFlow<T>.to(converter)` 转换为 terminal-only `FlowSubscribeProxy<T>`。
- Scope 只贡献 Job 生命周期结束信号，不贡献 RxStyle 数据调度 dispatcher。
- converter 每次订阅独立创建 scope subscription；调用 `to` 不启动 source。

Android 包 `com.xxf.coroutines.android.autodispose`：

- `autoDisposable(LifecycleOwner[, untilEvent])`、`autoDisposable(Lifecycle[, untilEvent])`，默认 `ON_DESTROY`，`ON_ANY` 不合法。
- `autoDisposable(View[, checkAttached = true])`，在 View detach 结束；`checkAttached` 控制订阅时未 attach 的 outside-scope 策略。
- `Flow<T>.bindLifecycle(owner/lifecycle/view)` 与 `RxFlow<T>.bindLifecycle(...)` 返回 proxy；生命周期结束仅取消本次订阅。
- `FlowDisposable.bindLifecycle(...)` 是订阅后包装方式；新链路优先在 subscribe 前用 converter，以得到 listener-ready 握手。
- `LifecycleOwner.asFlowScopeProvider(...)`、`Lifecycle.asFlowScopeProvider(...)` 可把 Android 生命周期接入核心转换器。

Android `com.xxf.coroutines.android.lifecycle` 的 `filterWhen(owner/lifecycle, vararg states)` 仅按当前 lifecycle state 过滤 onNext，不取消 upstream。

## 阻塞终端 API

参考 `FlowBlockingExtensions.kt`：`blockingFirst`、`blockingLast`、`blockingForEach`、`blockingSubscribe`。它们会阻塞当前调用线程，Android 主线程禁止调用。签名、timeout/default 值 overload 必须查当前文件；它们不能替代后台异步订阅的调度设计。

## 快速定位源码

核心工程 `src/jvmMain/kotlin/com/nbxxf/kpower/coroutines/rxstyle/flow/`：

| 文件/目录 | 内容 |
|---|---|
| `Flows.kt` | source factory |
| `RxFlow.kt`、`FlowRxInterop.kt` | 核心类型、普通 Flow 订阅 adapter |
| `RxFlowOperators.kt`、`FlowTransformExtensions.kt` | 映射、过滤、变换 |
| `FlowErrorExtensions.kt`、`FlowRetryExtensions.kt`、`FlowRepeatExtensions.kt` | 恢复与重试/重复 |
| `FlowCombineExtensions.kt`、`FlowGateExtensions.kt` | 组合与 gate |
| `FlowTimeExtensions.kt` | 时间操作符 |
| `RxFlowScheduling.kt`、`schedulers/` | 调度与 worker |
| `FlowPlugins.kt`、`disposables/`、`observers/` | 错误插件、资源管理、Observer |
| `autodispose/` | Scope provider/converter/proxy |

Android 工程 `src/main/java/com/xxf/coroutines/android/`：`autodispose/`、`disposables/`、`lifecycle/`、`schedulers/`。

核心行为测试 `src/jvmTest/kotlin/com/nbxxf/kpower/coroutines/rxstyle/flow/`，按主题查 `FlowAutoDisposeTest`、`FlowDisposableTest`、`FlowBlockingTest`、`FlowCombineGateTest`、`FlowTimeExtensionsTest`、`RxFlowCoreTest`、`RxFlowRetryDistinctTest`、`RxFlowSemanticsTest`、`RxFlowTransformTest`、`RxFlowTimeSourceTest` 和 `TestFlowSchedulerTest`。
