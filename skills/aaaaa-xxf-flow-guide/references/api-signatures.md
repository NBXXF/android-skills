# 公开函数完整签名快照

由 `scripts/build-api-snapshot.py` 从本地源码提取；保留 Kotlin 显式重载、receiver、泛型、参数名、默认值与 suspend 标记。
不展开 `@JvmOverloads` 合成的 Java 重载；省略表达式函数的推断返回类型、实现体、构造器和属性。属性/类型协议见 [API 目录](api-catalog.md)。
这是检索索引，不是语义教程；按文件查精确签名后，回到 [操作符选型与语义](operator-reference.md) 和 [场景手册](scenario-playbook.md)。

范围：两个模块全部生产 `.kt` 文件中的公开顶层函数与公开类型成员函数；跳过 `internal/` 实现目录和不可见类型。
源码行号只用于定位此快照；源码变动后应重建。SHA-256 覆盖各模块全部生产 Kotlin 文件的相对路径与内容。

共提取 **294** 个公开函数声明（按源码中的显式重载计数）。

## KPower reactive-coroutines

生产 Kotlin 文件：60；源码摘要：`955ab170be476767f2b0180beab73061a753ad289227f08a3d3b250e4bed95f0`。

### FlowBlockingExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowBlockingExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L19

```kotlin
fun <T> Flow<T>.blockingFirst(): T
```

`top-level` · L28

```kotlin
fun <T : Any> Flow<T>.blockingFirst(
    defaultValue: T
): T
```

`top-level` · L35

```kotlin
fun <T> Flow<T>.blockingLast(): T
```

`top-level` · L44

```kotlin
fun <T : Any> Flow<T>.blockingLast(
    defaultValue: T
): T
```

`top-level` · L61

```kotlin
fun <T> Flow<T>.blockingForEach(
    onNext: (T) -> Unit
)
```

`top-level` · L72

```kotlin
fun <T : Any> Flow<T>.blockingSubscribe()
```

`top-level` · L81

```kotlin
fun <T : Any> Flow<T>.blockingSubscribe(
    onNext: (T) -> Unit
)
```

`top-level` · L92

```kotlin
fun <T : Any> Flow<T>.blockingSubscribe(
    onNext: (T) -> Unit,
    onError: (Throwable) -> Unit
)
```

`top-level` · L109

```kotlin
fun <T : Any> Flow<T>.blockingSubscribe(
    onNext: (T) -> Unit,
    onError: (Throwable) -> Unit,
    onComplete: () -> Unit
)
```

### FlowCallback.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowCallback.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`FlowCallback` · L7

```kotlin
fun onNext(value: T)
```

`FlowCallback` · L10

```kotlin
fun onError(throwable: Throwable)
```

`FlowCallback` · L13

```kotlin
fun onComplete()
```

### FlowCombineExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowCombineExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L21

```kotlin
fun <T1 : Any, T2, R : Any> Flow<T1>.combineLatest(
    other: Flow<T2>,
    transform: suspend (T1, T2) -> R
): RxFlow<R>
```

`top-level` · L38

```kotlin
fun <T : Any, U, R : Any> Flow<T>.withLatestFrom(
    other: Flow<U>,
    transform: suspend (T, U) -> R
): RxFlow<R>
```

`top-level` · L69

```kotlin
fun <T : Any, U, R : Any> Flow<T>.zipWith(
    other: Flow<U>,
    zipper: suspend (T, U) -> R
): RxFlow<R>
```

`top-level` · L77

```kotlin
fun <T : Any> Flow<T>.concatWith(
    other: Flow<T>
): RxFlow<T>
```

`top-level` · L84

```kotlin
fun <T : Any> Flow<T>.mergeWith(
    other: Flow<T>
): RxFlow<T>
```

### FlowDebug.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowDebug.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L34

```kotlin
fun <T : Any> Flow<T>.debug(
    identifier: String? = null,
    trimOutput: Boolean = false
): RxFlow<T>
```

`top-level` · L40

```kotlin
fun <T : Any> RxFlow<T>.debug(
    identifier: String? = null,
    trimOutput: Boolean = false
): RxFlow<T>
```

`FlowDebugEvent` · L69

```kotlin
override fun toString(): String
```

### FlowDistinctExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowDistinctExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L7

```kotlin
fun <T : Any> Flow<T>.distinctUntilChanged(): RxFlow<T>
```

`top-level` · L11

```kotlin
fun <T : Any> RxFlow<T>.distinctUntilChanged(): RxFlow<T>
```

`top-level` · L15

```kotlin
fun <T : Any, K> Flow<T>.distinctUntilChanged(
    keySelector: (T) -> K
): RxFlow<T>
```

`top-level` · L20

```kotlin
fun <T : Any, K> RxFlow<T>.distinctUntilChanged(
    keySelector: (T) -> K
): RxFlow<T>
```

`top-level` · L25

```kotlin
fun <T : Any> Flow<T>.distinctUntilChanged(
    areEqual: (T, T) -> Boolean
): RxFlow<T>
```

`top-level` · L30

```kotlin
fun <T : Any> RxFlow<T>.distinctUntilChanged(
    areEqual: (T, T) -> Boolean
): RxFlow<T>
```

`top-level` · L39

```kotlin
fun <T : Any> Flow<T>.distinctUntilChangedByHash(): RxFlow<T>
```

### FlowErrorExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowErrorExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L10

```kotlin
fun <T : Any> Flow<T>.onErrorReturnItem(item: T): RxFlow<T>
```

`top-level` · L14

```kotlin
fun <T : Any> RxFlow<T>.onErrorReturnItem(item: T): RxFlow<T>
```

`top-level` · L17

```kotlin
fun <T : Any> Flow<T>.onErrorReturn(valueSupplier: (Throwable) -> T): RxFlow<T>
```

`top-level` · L21

```kotlin
fun <T : Any> RxFlow<T>.onErrorReturn(valueSupplier: (Throwable) -> T): RxFlow<T>
```

`top-level` · L25

```kotlin
fun <T : Any> Flow<T>.onErrorResumeNext(
    fallbackSupplier: (Throwable) -> Flow<T>
): RxFlow<T>
```

`top-level` · L30

```kotlin
fun <T : Any> RxFlow<T>.onErrorResumeNext(
    fallbackSupplier: (Throwable) -> Flow<T>
): RxFlow<T>
```

`top-level` · L36

```kotlin
fun <T : Any> Flow<T>.onErrorComplete(
    predicate: (Throwable) -> Boolean = { true }
): RxFlow<T>
```

`top-level` · L42

```kotlin
fun <T : Any> RxFlow<T>.onErrorComplete(
    predicate: (Throwable) -> Boolean = { true }
): RxFlow<T>
```

### FlowGateExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowGateExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L12

```kotlin
fun <T : Any> Flow<T>.takeUntil(stopPredicate: suspend (T) -> Boolean): RxFlow<T>
```

`top-level` · L20

```kotlin
fun <T : Any, U> Flow<T>.skipUntil(other: Flow<U>): RxFlow<T>
```

`top-level` · L24

```kotlin
fun <T : Any, U> Flow<T>.takeUntil(other: Flow<U>): RxFlow<T>
```

### FlowLifecycleExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowLifecycleExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L6

```kotlin
fun <T : Any> Flow<T>.doOnNext(action: (T) -> Unit): RxFlow<T>
```

`top-level` · L9

```kotlin
fun <T : Any> Flow<T>.doAfterNext(action: (T) -> Unit): RxFlow<T>
```

`top-level` · L12

```kotlin
fun <T : Any> Flow<T>.doOnError(action: (Throwable) -> Unit): RxFlow<T>
```

`top-level` · L15

```kotlin
fun <T : Any> Flow<T>.doOnComplete(action: () -> Unit): RxFlow<T>
```

`top-level` · L18

```kotlin
fun <T : Any> Flow<T>.doOnTerminate(action: () -> Unit): RxFlow<T>
```

`top-level` · L21

```kotlin
fun <T : Any> Flow<T>.doAfterTerminate(action: () -> Unit): RxFlow<T>
```

`top-level` · L24

```kotlin
fun <T : Any> Flow<T>.doOnDispose(action: () -> Unit): RxFlow<T>
```

`top-level` · L27

```kotlin
fun <T : Any> Flow<T>.doFinally(action: () -> Unit): RxFlow<T>
```

`top-level` · L30

```kotlin
fun <T : Any> Flow<T>.doOnLifecycle(
    onSubscribe: (FlowDisposable) -> Unit,
    onDispose: () -> Unit
): RxFlow<T>
```

`top-level` · L35

```kotlin
fun <T : Any> RxFlow<T>.doOnLifecycle(
    onSubscribe: (FlowDisposable) -> Unit,
    onDispose: () -> Unit
): RxFlow<T>
```

`top-level` · L40

```kotlin
fun <T : Any> Flow<T>.doOnEach(
    onNext: (T) -> Unit = {},
    onError: (Throwable) -> Unit = {},
    onComplete: () -> Unit = {}
): RxFlow<T>
```

`top-level` · L46

```kotlin
fun <T : Any> RxFlow<T>.doOnEach(
    onNext: (T) -> Unit = {},
    onError: (Throwable) -> Unit = {},
    onComplete: () -> Unit = {}
): RxFlow<T>
```

### FlowObserver.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowObserver.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`FlowObserver` · L9

```kotlin
fun onSubscribe(disposable: FlowDisposable)
```

`FlowObserver` · L12

```kotlin
fun onNext(value: T)
```

`FlowObserver` · L15

```kotlin
fun onError(throwable: Throwable)
```

`FlowObserver` · L18

```kotlin
fun onComplete()
```

### FlowPlugins.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowPlugins.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`FlowPlugins` · L22

```kotlin
fun setErrorHandler(
        handler: ((Throwable) -> Unit)?
    )
```

`FlowPlugins` · L32

```kotlin
fun getErrorHandler(): ((Throwable) -> Unit)?
```

`FlowPlugins` · L36

```kotlin
fun setScheduleHandler(handler: (((() -> Unit)) -> (() -> Unit))?)
```

`FlowPlugins` · L44

```kotlin
fun getScheduleHandler(): (((() -> Unit)) -> (() -> Unit))?
```

`FlowPlugins` · L52

```kotlin
fun setLogHandler(handler: ((Any) -> Unit)?)
```

`FlowPlugins` · L60

```kotlin
fun getLogHandler(): (Any) -> Unit
```

`FlowPlugins` · L80

```kotlin
fun reset()
```

`FlowPlugins` · L90

```kotlin
fun lockdown()
```

`FlowPlugins` · L95

```kotlin
fun isLockdown(): Boolean
```

`FlowPlugins` · L98

```kotlin
fun onError(throwable: Throwable)
```

`FlowPlugins` · L117

```kotlin
fun onSchedule(action: () -> Unit): () -> Unit
```

### FlowRepeatExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowRepeatExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L16

```kotlin
fun <T : Any> Flow<T>.repeat(): RxFlow<T>
```

`top-level` · L24

```kotlin
fun <T : Any> Flow<T>.repeat(
    times: Long
): RxFlow<T>
```

`top-level` · L41

```kotlin
fun <T : Any> Flow<T>.repeatUntil(
    stop: suspend () -> Boolean
): RxFlow<T>
```

### FlowRetryExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowRetryExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L9

```kotlin
fun <T : Any> Flow<T>.retry(): RxFlow<T>
```

`top-level` · L12

```kotlin
fun <T : Any> RxFlow<T>.retry(): RxFlow<T>
```

`top-level` · L15

```kotlin
fun <T : Any> Flow<T>.retry(times: Long): RxFlow<T>
```

`top-level` · L18

```kotlin
fun <T : Any> RxFlow<T>.retry(times: Long): RxFlow<T>
```

`top-level` · L21

```kotlin
fun <T : Any> Flow<T>.retry(
    times: Long,
    predicate: (Throwable) -> Boolean
): RxFlow<T>
```

`top-level` · L27

```kotlin
fun <T : Any> RxFlow<T>.retry(
    times: Long,
    predicate: (Throwable) -> Boolean
): RxFlow<T>
```

`top-level` · L36

```kotlin
fun <T : Any> Flow<T>.retryUntil(stop: () -> Boolean): RxFlow<T>
```

`top-level` · L40

```kotlin
fun <T : Any> RxFlow<T>.retryUntil(stop: () -> Boolean): RxFlow<T>
```

### FlowRxInterop.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowRxInterop.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L13

```kotlin
fun <T : Any> Flow<T>.subscribe(): FlowDisposable
```

`top-level` · L15

```kotlin
fun <T : Any> Flow<T>.subscribe(
    onNext: (T) -> Unit
): FlowDisposable
```

`top-level` · L19

```kotlin
fun <T : Any> Flow<T>.subscribe(
    onNext: (T) -> Unit,
    onError: (Throwable) -> Unit
): FlowDisposable
```

`top-level` · L24

```kotlin
fun <T : Any> Flow<T>.subscribe(
    onNext: (T) -> Unit,
    onError: (Throwable) -> Unit,
    onComplete: () -> Unit
): FlowDisposable
```

`top-level` · L30

```kotlin
fun <T : Any> Flow<T>.subscribe(observer: FlowObserver<T>)
```

`top-level` · L34

```kotlin
fun <T : Any, E : FlowObserver<T>> Flow<T>.subscribeWith(observer: E): E
```

### FlowStartEmptyExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowStartEmptyExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L11

```kotlin
fun <T : Any> Flow<T>.defaultIfEmpty(defaultValue: T): RxFlow<T>
```

`top-level` · L15

```kotlin
fun <T : Any> RxFlow<T>.defaultIfEmpty(defaultValue: T): RxFlow<T>
```

`top-level` · L19

```kotlin
fun <T : Any> Flow<T>.switchIfEmpty(fallback: Flow<T>): RxFlow<T>
```

`top-level` · L23

```kotlin
fun <T : Any> RxFlow<T>.switchIfEmpty(fallback: Flow<T>): RxFlow<T>
```

`top-level` · L27

```kotlin
fun <T : Any> Flow<T>.switchIfEmpty(fallback: () -> Flow<T>): RxFlow<T>
```

`top-level` · L31

```kotlin
fun <T : Any> RxFlow<T>.switchIfEmpty(fallback: () -> Flow<T>): RxFlow<T>
```

`top-level` · L35

```kotlin
fun <T : Any> Flow<T>.startWithItem(item: T): RxFlow<T>
```

`top-level` · L39

```kotlin
fun <T : Any> RxFlow<T>.startWithItem(item: T): RxFlow<T>
```

`top-level` · L43

```kotlin
fun <T : Any> Flow<T>.startWith(other: Flow<T>): RxFlow<T>
```

`top-level` · L47

```kotlin
fun <T : Any> RxFlow<T>.startWith(other: Flow<T>): RxFlow<T>
```

`top-level` · L51

```kotlin
fun <T : Any> Flow<T>.startWithArray(vararg items: T): RxFlow<T>
```

`top-level` · L55

```kotlin
fun <T : Any> RxFlow<T>.startWithArray(vararg items: T): RxFlow<T>
```

`top-level` · L59

```kotlin
fun <T : Any> Flow<T>.startWithIterable(items: Iterable<T>): RxFlow<T>
```

`top-level` · L63

```kotlin
fun <T : Any> RxFlow<T>.startWithIterable(items: Iterable<T>): RxFlow<T>
```

### FlowSubscribeSource.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowSubscribeSource.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`FlowSubscribeSource` · L7

```kotlin
fun subscribe(observer: FlowObserver<T>)
```

### FlowTimeExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowTimeExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L18

```kotlin
fun <T : Any> Flow<T>.delay(duration: Duration): RxFlow<T>
```

`top-level` · L22

```kotlin
fun <T : Any> Flow<T>.delay(duration: Duration, scheduler: Scheduler): RxFlow<T>
```

`top-level` · L28

```kotlin
fun <T : Any> Flow<T>.delaySubscription(duration: Duration): RxFlow<T>
```

`top-level` · L32

```kotlin
fun <T : Any> Flow<T>.delaySubscription(duration: Duration, scheduler: Scheduler): RxFlow<T>
```

`top-level` · L41

```kotlin
fun <T : Any, U> Flow<T>.delaySubscription(other: Flow<U>): RxFlow<T>
```

`top-level` · L47

```kotlin
fun <T : Any> Flow<T>.throttleFirst(windowDuration: Duration): RxFlow<T>
```

`top-level` · L51

```kotlin
fun <T : Any> Flow<T>.throttleFirst(windowDuration: Duration, scheduler: Scheduler): RxFlow<T>
```

`top-level` · L59

```kotlin
fun <T : Any> Flow<T>.throttleLast(period: Duration): RxFlow<T>
```

`top-level` · L63

```kotlin
fun <T : Any> Flow<T>.throttleLast(period: Duration, scheduler: Scheduler): RxFlow<T>
```

`top-level` · L69

```kotlin
fun <T : Any> Flow<T>.throttleWithTimeout(timeout: Duration): RxFlow<T>
```

`top-level` · L73

```kotlin
fun <T : Any> Flow<T>.throttleWithTimeout(timeout: Duration, scheduler: Scheduler): RxFlow<T>
```

### FlowTransformExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/FlowTransformExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L15

```kotlin
fun <T : Any> Flow<T>.skip(count: Int): RxFlow<T>
```

`top-level` · L18

```kotlin
fun <T : Any> RxFlow<T>.skip(count: Int): RxFlow<T>
```

`top-level` · L24

```kotlin
fun <T : Any> Flow<T>.skipWhile(predicate: (T) -> Boolean): RxFlow<T>
```

`top-level` · L28

```kotlin
fun <T : Any> RxFlow<T>.skipWhile(predicate: (T) -> Boolean): RxFlow<T>
```

`top-level` · L32

```kotlin
inline fun <reified R : Any> Flow<*>.ofType(): RxFlow<R>
```

`top-level` · L37

```kotlin
fun <T : Any, R : Any> Flow<T>.switchMap(transform: (T) -> Flow<R>): RxFlow<R>
```

`top-level` · L41

```kotlin
fun <T : Any, R : Any> RxFlow<T>.switchMap(transform: (T) -> Flow<R>): RxFlow<R>
```

`top-level` · L45

```kotlin
fun <T : Any, R : Any> Flow<T>.concatMap(transform: (T) -> Flow<R>): RxFlow<R>
```

`top-level` · L49

```kotlin
fun <T : Any, R : Any> RxFlow<T>.concatMap(transform: (T) -> Flow<R>): RxFlow<R>
```

### Flows.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/Flows.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`Flows` · L47

```kotlin
fun <T : Any> fromCallback(
        register: suspend (FlowCallback<T>) -> Unit,
        unregister: (FlowCallback<T>) -> Unit = {}
    ): RxFlow<T>
```

`Flows` · L98

```kotlin
fun <T : Any> just(value: T): RxFlow<T>
```

`Flows` · L105

```kotlin
fun <T : Any> just(
        first: T,
        second: T,
        vararg others: T
    ): RxFlow<T>
```

`Flows` · L120

```kotlin
fun <T : Any> empty(): RxFlow<T>
```

`Flows` · L128

```kotlin
fun <T : Any> error(throwable: Throwable): RxFlow<T>
```

`Flows` · L138

```kotlin
fun <T : Any> error(
        supplier: suspend () -> Throwable
    ): RxFlow<T>
```

`Flows` · L150

```kotlin
fun <T : Any> never(): RxFlow<T>
```

`Flows` · L163

```kotlin
fun <T : Any> create(
        block: suspend FlowCollector<T>.() -> Unit
    ): RxFlow<T>
```

`Flows` · L171

```kotlin
fun <T : Any> defer(
        factory: suspend () -> Flow<T>
    ): RxFlow<T>
```

`Flows` · L180

```kotlin
fun <T : Any> fromArray(
        vararg values: T
    ): RxFlow<T>
```

`Flows` · L185

```kotlin
fun <T : Any> fromIterable(
        source: Iterable<T>
    ): RxFlow<T>
```

`Flows` · L190

```kotlin
fun <T : Any> fromSequence(
        source: Sequence<T>
    ): RxFlow<T>
```

`Flows` · L200

```kotlin
fun <T : Any> fromCallable(
        callable: suspend () -> T
    ): RxFlow<T>
```

`Flows` · L212

```kotlin
fun <T : Any> fromSupplier(
        supplier: suspend () -> T
    ): RxFlow<T>
```

`Flows` · L221

```kotlin
fun <T : Any> fromSuspend(
        block: suspend () -> T
    ): RxFlow<T>
```

`Flows` · L233

```kotlin
fun fromAction(
        action: suspend () -> Unit
    ): RxFlow<Nothing>
```

`Flows` · L242

```kotlin
fun fromRunnable(
        runnable: suspend () -> Unit
    ): RxFlow<Nothing>
```

`Flows` · L251

```kotlin
fun <T : Any> fromResult(
        result: Result<T>
    ): RxFlow<T>
```

`Flows` · L263

```kotlin
fun <T : Any> wrap(source: Flow<T>): RxFlow<T>
```

`Flows` · L269

```kotlin
fun range(
        start: Int,
        count: Int
    ): RxFlow<Int>
```

`Flows` · L297

```kotlin
fun rangeLong(
        start: Long,
        count: Long
    ): RxFlow<Long>
```

`Flows` · L328

```kotlin
fun timer(
        delayDuration: Duration
    ): RxFlow<Long>
```

`Flows` · L333

```kotlin
fun timer(
        delayDuration: Duration,
        scheduler: Scheduler
    ): RxFlow<Long>
```

`Flows` · L347

```kotlin
fun interval(
        period: Duration
    ): RxFlow<Long>
```

`Flows` · L352

```kotlin
fun interval(
        period: Duration,
        scheduler: Scheduler
    ): RxFlow<Long>
```

`Flows` · L369

```kotlin
fun interval(
        initialDelay: Duration,
        period: Duration
    ): RxFlow<Long>
```

`Flows` · L375

```kotlin
fun interval(
        initialDelay: Duration,
        period: Duration,
        scheduler: Scheduler
    ): RxFlow<Long>
```

`Flows` · L391

```kotlin
fun intervalRange(
        start: Long,
        count: Long,
        initialDelay: Duration,
        period: Duration
    ): RxFlow<Long>
```

`Flows` · L399

```kotlin
fun intervalRange(
        start: Long,
        count: Long,
        initialDelay: Duration,
        period: Duration,
        scheduler: Scheduler
    ): RxFlow<Long>
```

`Flows` · L431

```kotlin
fun <R, T : Any> using(
        resourceFactory: suspend () -> R,
        flowFactory: suspend (R) -> Flow<T>,
        disposer: (R) -> Unit
    ): RxFlow<T>
```

`Flows` · L460

```kotlin
fun <T : Any> concat(
        vararg sources: Flow<T>
    ): RxFlow<T>
```

`Flows` · L465

```kotlin
fun <T : Any> concat(
        sources: Iterable<Flow<T>>
    ): RxFlow<T>
```

`Flows` · L470

```kotlin
fun <T : Any> merge(
        vararg sources: Flow<T>
    ): RxFlow<T>
```

### RxFlow.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/RxFlow.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`RxFlow` · L29

```kotlin
final override fun subscribe(observer: FlowObserver<T>)
```

`RxFlow` · L50

```kotlin
final override suspend fun collectSafely(collector: FlowCollector<T>)
```

`RxFlow` · L84

```kotlin
fun subscribe(): FlowDisposable
```

`RxFlow` · L86

```kotlin
fun subscribe(onNext: (T) -> Unit): FlowDisposable
```

`RxFlow` · L95

```kotlin
fun subscribe(
        onNext: (T) -> Unit,
        onError: (Throwable) -> Unit
    ): FlowDisposable
```

`RxFlow` · L100

```kotlin
fun subscribe(
        onNext: (T) -> Unit,
        onError: (Throwable) -> Unit,
        onComplete: () -> Unit
    ): FlowDisposable
```

`RxFlow` · L110

```kotlin
fun <E : FlowObserver<T>> subscribeWith(observer: E): E
```

### RxFlowOperators.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/RxFlowOperators.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L10

```kotlin
fun <T : Any, R : Any> RxFlow<T>.map(transform: (T) -> R): RxFlow<R>
```

`top-level` · L14

```kotlin
fun <T : Any> RxFlow<T>.filter(predicate: (T) -> Boolean): RxFlow<T>
```

`top-level` · L18

```kotlin
fun <T : Any> RxFlow<T>.doOnNext(action: (T) -> Unit): RxFlow<T>
```

`top-level` · L22

```kotlin
fun <T : Any> RxFlow<T>.doAfterNext(action: (T) -> Unit): RxFlow<T>
```

`top-level` · L24

```kotlin
fun <T : Any> RxFlow<T>.doOnError(action: (Throwable) -> Unit): RxFlow<T>
```

`top-level` · L26

```kotlin
fun <T : Any> RxFlow<T>.doOnComplete(action: () -> Unit): RxFlow<T>
```

`top-level` · L28

```kotlin
fun <T : Any> RxFlow<T>.doOnTerminate(action: () -> Unit): RxFlow<T>
```

`top-level` · L30

```kotlin
fun <T : Any> RxFlow<T>.doAfterTerminate(action: () -> Unit): RxFlow<T>
```

`top-level` · L32

```kotlin
fun <T : Any> RxFlow<T>.doOnDispose(action: () -> Unit): RxFlow<T>
```

`top-level` · L34

```kotlin
fun <T : Any> RxFlow<T>.doOnSubscribe(
    action: (FlowDisposable) -> Unit
): RxFlow<T>
```

`top-level` · L40

```kotlin
fun <T : Any> RxFlow<T>.doFinally(action: () -> Unit): RxFlow<T>
```

`top-level` · L45

```kotlin
fun <T : Any> Flow<T>.doOnSubscribe(
    action: (FlowDisposable) -> Unit
): RxFlow<T>
```

### RxFlowScheduling.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/RxFlowScheduling.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow`。

`top-level` · L13

```kotlin
fun <T : Any> Flow<T>.subscribeOn(scheduler: Scheduler): RxFlow<T>
```

`top-level` · L17

```kotlin
fun <T : Any> RxFlow<T>.subscribeOn(scheduler: Scheduler): RxFlow<T>
```

`top-level` · L22

```kotlin
fun <T : Any> Flow<T>.observeOn(
    scheduler: Scheduler,
    delayError: Boolean = false,
    bufferSize: Int = 128
): RxFlow<T>
```

`top-level` · L31

```kotlin
fun <T : Any> RxFlow<T>.observeOn(
    scheduler: Scheduler,
    delayError: Boolean = false,
    bufferSize: Int = 128
): RxFlow<T>
```

`top-level` · L42

```kotlin
fun <T : Any> Flow<T>.unsubscribeOn(scheduler: Scheduler): RxFlow<T>
```

`top-level` · L46

```kotlin
fun <T : Any> RxFlow<T>.unsubscribeOn(scheduler: Scheduler): RxFlow<T>
```

### FlowAutoDispose.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowAutoDispose.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`top-level` · L23

```kotlin
fun <T : Any, R> Flow<T>.to(converter: FlowConverter<T, R>): R
```

`top-level` · L28

```kotlin
fun <T : Any, R> RxFlow<T>.to(converter: FlowConverter<T, R>): R
```

`top-level` · L33

```kotlin
fun <T : Any> autoDisposable(
    scopeProvider: FlowScopeProvider
): FlowConverter<T, FlowSubscribeProxy<T>>
```

`top-level` · L40

```kotlin
fun <T : Any> autoDisposable(
    scope: CoroutineScope
): FlowConverter<T, FlowSubscribeProxy<T>>
```

`top-level` · L47

```kotlin
fun CoroutineScope.asFlowScopeProvider(): FlowScopeProvider
```

### FlowAutoDisposePlugins.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowAutoDisposePlugins.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`FlowAutoDisposePlugins` · L12

```kotlin
fun setOutsideScopeHandler(handler: ((OutsideFlowScopeException) -> Unit)?)
```

`FlowAutoDisposePlugins` · L17

```kotlin
fun getOutsideScopeHandler(): ((OutsideFlowScopeException) -> Unit)?
```

`FlowAutoDisposePlugins` · L20

```kotlin
fun reset()
```

### FlowConverter.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowConverter.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`FlowConverter` · L8

```kotlin
fun apply(upstream: RxFlow<T>): R
```

### FlowScopeObserver.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowScopeObserver.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`FlowScopeObserver` · L8

```kotlin
fun onSubscribe(disposable: FlowDisposable)
```

`FlowScopeObserver` · L10

```kotlin
fun onReady()
```

`FlowScopeObserver` · L12

```kotlin
fun onComplete()
```

`FlowScopeObserver` · L14

```kotlin
fun onError(throwable: Throwable)
```

### FlowScopeProvider.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowScopeProvider.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`FlowScopeProvider` · L10

```kotlin
fun requestScope(): FlowScopeSource
```

### FlowScopeSource.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowScopeSource.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`FlowScopeSource` · L7

```kotlin
fun subscribe(observer: FlowScopeObserver)
```

### FlowSubscribeProxy.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/FlowSubscribeProxy.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`FlowSubscribeProxy` · L10

```kotlin
fun subscribe(): FlowDisposable
```

`FlowSubscribeProxy` · L12

```kotlin
fun subscribe(onNext: (T) -> Unit): FlowDisposable
```

`FlowSubscribeProxy` · L14

```kotlin
fun subscribe(onNext: (T) -> Unit, onError: (Throwable) -> Unit): FlowDisposable
```

`FlowSubscribeProxy` · L16

```kotlin
fun subscribe(
        onNext: (T) -> Unit,
        onError: (Throwable) -> Unit,
        onComplete: () -> Unit
    ): FlowDisposable
```

`FlowSubscribeProxy` · L22

```kotlin
fun <E : FlowObserver<T>> subscribeWith(observer: E): E
```

### ManualFlowScopeProvider.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/autodispose/ManualFlowScopeProvider.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.autodispose`。

`ManualFlowScopeProvider` · L16

```kotlin
override fun requestScope(): FlowScopeSource
```

`ManualFlowScopeProvider` · L40

```kotlin
fun end()
```

`ManualFlowScopeProvider` · L50

```kotlin
override fun dispose()
```

`ManualFlowScopeProvider` · L52

```kotlin
override fun close()
```

### CompositeFlowDisposable.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/disposables/CompositeFlowDisposable.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.disposables`。

`CompositeFlowDisposable` · L24

```kotlin
override fun add(disposable: FlowDisposable): Boolean
```

`CompositeFlowDisposable` · L37

```kotlin
fun addAll(vararg disposables: FlowDisposable): Boolean
```

`CompositeFlowDisposable` · L49

```kotlin
override fun remove(disposable: FlowDisposable): Boolean
```

`CompositeFlowDisposable` · L57

```kotlin
override fun delete(disposable: FlowDisposable): Boolean
```

`CompositeFlowDisposable` · L64

```kotlin
fun size(): Int
```

`CompositeFlowDisposable` · L69

```kotlin
fun clear()
```

`CompositeFlowDisposable` · L79

```kotlin
override fun dispose()
```

### FlowDisposable.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/disposables/FlowDisposable.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.disposables`。

`FlowDisposable` · L10

```kotlin
fun dispose()
```

`FlowDisposable.Companion` · L16

```kotlin
fun disposed(): FlowDisposable
```

`FlowDisposable.Companion` · L20

```kotlin
fun empty(): FlowDisposable
```

`FlowDisposable.Companion` · L24

```kotlin
fun fromAction(action: () -> Unit): FlowDisposable
```

### FlowDisposableContainer.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/disposables/FlowDisposableContainer.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.disposables`。

`FlowDisposableContainer` · L7

```kotlin
fun add(disposable: FlowDisposable): Boolean
```

`FlowDisposableContainer` · L10

```kotlin
fun remove(disposable: FlowDisposable): Boolean
```

`FlowDisposableContainer` · L13

```kotlin
fun delete(disposable: FlowDisposable): Boolean
```

### SerialFlowDisposable.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/disposables/SerialFlowDisposable.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.disposables`。

`SerialFlowDisposable` · L17

```kotlin
fun get(): FlowDisposable?
```

`SerialFlowDisposable` · L23

```kotlin
fun set(disposable: FlowDisposable?): Boolean
```

`SerialFlowDisposable` · L28

```kotlin
fun replace(disposable: FlowDisposable?): Boolean
```

`SerialFlowDisposable` · L32

```kotlin
override fun dispose()
```

### DisposableFlowObserver.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/observers/DisposableFlowObserver.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.observers`。

`DisposableFlowObserver` · L26

```kotlin
final override fun onSubscribe(disposable: FlowDisposable)
```

`DisposableFlowObserver` · L41

```kotlin
final override fun dispose()
```

### FlowSchedulerExtensions.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/schedulers/FlowSchedulerExtensions.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.schedulers`。

`top-level` · L8

```kotlin
fun <T : Any> Flow<T>.subscribeOnComputation(): RxFlow<T>
```

`top-level` · L11

```kotlin
fun <T : Any> Flow<T>.observeOnComputation(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L14

```kotlin
fun <T : Any> Flow<T>.subscribeOnIO(): RxFlow<T>
```

`top-level` · L17

```kotlin
fun <T : Any> Flow<T>.observeOnIO(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L20

```kotlin
fun <T : Any> Flow<T>.subscribeOnNewThread(): RxFlow<T>
```

`top-level` · L23

```kotlin
fun <T : Any> Flow<T>.observeOnNewThread(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L26

```kotlin
fun <T : Any> Flow<T>.subscribeOnSingle(): RxFlow<T>
```

`top-level` · L29

```kotlin
fun <T : Any> Flow<T>.observeOnSingle(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L32

```kotlin
fun <T : Any> Flow<T>.subscribeOnTrampoline(): RxFlow<T>
```

`top-level` · L35

```kotlin
fun <T : Any> Flow<T>.observeOnTrampoline(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L38

```kotlin
fun <T : Any> RxFlow<T>.subscribeOnComputation(): RxFlow<T>
```

`top-level` · L41

```kotlin
fun <T : Any> RxFlow<T>.observeOnComputation(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L44

```kotlin
fun <T : Any> RxFlow<T>.subscribeOnIO(): RxFlow<T>
```

`top-level` · L47

```kotlin
fun <T : Any> RxFlow<T>.observeOnIO(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L50

```kotlin
fun <T : Any> RxFlow<T>.subscribeOnNewThread(): RxFlow<T>
```

`top-level` · L53

```kotlin
fun <T : Any> RxFlow<T>.observeOnNewThread(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L56

```kotlin
fun <T : Any> RxFlow<T>.subscribeOnSingle(): RxFlow<T>
```

`top-level` · L59

```kotlin
fun <T : Any> RxFlow<T>.observeOnSingle(delayError: Boolean = false): RxFlow<T>
```

`top-level` · L62

```kotlin
fun <T : Any> RxFlow<T>.subscribeOnTrampoline(): RxFlow<T>
```

`top-level` · L65

```kotlin
fun <T : Any> RxFlow<T>.observeOnTrampoline(delayError: Boolean = false): RxFlow<T>
```

### Scheduler.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/schedulers/Scheduler.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.schedulers`。

`Scheduler` · L19

```kotlin
abstract fun createWorker(): Worker
```

`Scheduler` · L22

```kotlin
open fun scheduleDirect(action: () -> Unit): FlowDisposable
```

`Scheduler` · L27

```kotlin
open fun scheduleDirect(action: () -> Unit, delay: Duration): FlowDisposable
```

`Scheduler.Worker` · L59

```kotlin
fun schedule(action: () -> Unit): FlowDisposable
```

`Scheduler.Worker` · L72

```kotlin
fun schedule(action: () -> Unit, delay: Duration): FlowDisposable
```

`Scheduler.Worker` · L89

```kotlin
fun schedulePeriodically(
            action: () -> Unit,
            initialDelay: Duration,
            period: Duration
        ): FlowDisposable
```

`Scheduler.Worker` · L152

```kotlin
final override fun dispose()
```

### Schedulers.kt

路径：`com/nbxxf/kpower/coroutines/rxstyle/flow/schedulers/Schedulers.kt`；包：`com.nbxxf.kpower.coroutines.rxstyle.flow.schedulers`。

`Schedulers` · L32

```kotlin
fun computation(): Scheduler
```

`Schedulers` · L35

```kotlin
fun io(): Scheduler
```

`Schedulers` · L38

```kotlin
fun single(): Scheduler
```

`Schedulers` · L41

```kotlin
fun newThread(): Scheduler
```

`Schedulers` · L44

```kotlin
fun trampoline(): Scheduler
```

`Schedulers` · L47

```kotlin
fun from(dispatcher: CoroutineDispatcher): Scheduler
```

### FlowAsStateFlow.kt

路径：`com/nbxxf/kpower/coroutines/transform/flow2stateflow/FlowAsStateFlow.kt`；包：`com.nbxxf.kpower.coroutines.transform.flow2stateflow`。

`top-level` · L22

```kotlin
fun <T> Flow<T>.asStateFlow(
    scope: CoroutineScope,
    initialValue: T,
    started: SharingStarted = SharingStarted.WhileSubscribed(5_000)
): StateFlow<T>
```

### SuspendAsFlow.kt

路径：`com/nbxxf/kpower/coroutines/transform/suspend2flow/SuspendAsFlow.kt`；包：`com.nbxxf.kpower.coroutines.transform.suspend2flow`。

`top-level` · L51

```kotlin
fun <T> suspendAsFlow(
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
    block: suspend () -> T,
): Flow<T>
```

`top-level` · L111

```kotlin
fun <T> (suspend () -> T).asFlow(
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
): Flow<T>
```

### SuspendAsStateFlow.kt

路径：`com/nbxxf/kpower/coroutines/transform/suspend2stateflow/SuspendAsStateFlow.kt`；包：`com.nbxxf.kpower.coroutines.transform.suspend2stateflow`。

`top-level` · L24

```kotlin
fun <T> suspendAsStateFlow(
    scope: CoroutineScope,
    initialValue: T,
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
    started: SharingStarted = SharingStarted.WhileSubscribed(5_000),
    block: suspend () -> T
): StateFlow<T>
```

## xxf_android reactive-coroutines-android

生产 Kotlin 文件：10；源码摘要：`fe52880fe76a3c1b72324fd089981d74d58ed464f344cd6a64f9a85aa72a8b22`。

### FlowDisposableLifecycleExtensions.kt

路径：`com/xxf/coroutines/android/autodispose/FlowDisposableLifecycleExtensions.kt`；包：`com.xxf.coroutines.android.autodispose`。

`top-level` · L22

```kotlin
fun FlowDisposable.bindLifecycle(
    lifecycleOwner: LifecycleOwner,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowDisposable
```

`top-level` · L32

```kotlin
fun FlowDisposable.bindLifecycle(
    lifecycle: Lifecycle,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowDisposable
```

### FlowLifecycle.kt

路径：`com/xxf/coroutines/android/autodispose/FlowLifecycle.kt`；包：`com.xxf.coroutines.android.autodispose`。

`FlowLifecycle` · L18

```kotlin
fun <T : Any> bindLifecycle(
        lifecycleOwner: LifecycleOwner,
        untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
    ): FlowConverter<T, FlowSubscribeProxy<T>>
```

`FlowLifecycle` · L26

```kotlin
fun <T : Any> bindLifecycle(
        lifecycle: Lifecycle,
        untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
    ): FlowConverter<T, FlowSubscribeProxy<T>>
```

`FlowLifecycle` · L33

```kotlin
fun <T : Any> bindLifecycle(
        viewModel: ViewModel
    ): FlowConverter<T, FlowSubscribeProxy<T>>
```

`FlowLifecycle` · L39

```kotlin
fun <T : Any> bindLifecycle(
        scope: CoroutineScope
    ): FlowConverter<T, FlowSubscribeProxy<T>>
```

`FlowLifecycle` · L46

```kotlin
fun <T : Any> bindLifecycle(
        view: View,
        checkAttached: Boolean = true
    ): FlowConverter<T, FlowSubscribeProxy<T>>
```

### LifecycleAutoDispose.kt

路径：`com/xxf/coroutines/android/autodispose/LifecycleAutoDispose.kt`；包：`com.xxf.coroutines.android.autodispose`。

`top-level` · L24

```kotlin
fun <T : Any> autoDisposable(
    lifecycleOwner: LifecycleOwner,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowConverter<T, FlowSubscribeProxy<T>>
```

`top-level` · L33

```kotlin
fun <T : Any> autoDisposable(
    lifecycle: Lifecycle,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowConverter<T, FlowSubscribeProxy<T>>
```

`top-level` · L41

```kotlin
fun <T : Any> autoDisposable(
    viewModel: ViewModel
): FlowConverter<T, FlowSubscribeProxy<T>>
```

`top-level` · L49

```kotlin
fun <T : Any> Flow<T>.bindLifecycle(
    lifecycleOwner: LifecycleOwner,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowSubscribeProxy<T>
```

`top-level` · L56

```kotlin
fun <T : Any> Flow<T>.bindLifecycle(
    lifecycle: Lifecycle,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowSubscribeProxy<T>
```

`top-level` · L62

```kotlin
fun <T : Any> Flow<T>.bindLifecycle(viewModel: ViewModel): FlowSubscribeProxy<T>
```

`top-level` · L69

```kotlin
fun <T : Any> RxFlow<T>.bindLifecycle(
    lifecycleOwner: LifecycleOwner,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowSubscribeProxy<T>
```

`top-level` · L76

```kotlin
fun <T : Any> RxFlow<T>.bindLifecycle(
    lifecycle: Lifecycle,
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowSubscribeProxy<T>
```

`top-level` · L82

```kotlin
fun <T : Any> RxFlow<T>.bindLifecycle(viewModel: ViewModel): FlowSubscribeProxy<T>
```

`top-level` · L92

```kotlin
fun LifecycleOwner.asFlowScopeProvider(
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowScopeProvider
```

`top-level` · L98

```kotlin
fun Lifecycle.asFlowScopeProvider(
    untilEvent: Lifecycle.Event = Lifecycle.Event.ON_DESTROY
): FlowScopeProvider
```

### ViewAutoDispose.kt

路径：`com/xxf/coroutines/android/autodispose/ViewAutoDispose.kt`；包：`com.xxf.coroutines.android.autodispose`。

`top-level` · L28

```kotlin
fun <T : Any> autoDisposable(
    view: View,
    checkAttached: Boolean = true
): FlowConverter<T, FlowSubscribeProxy<T>>
```

`top-level` · L40

```kotlin
fun <T : Any> Flow<T>.bindLifecycle(
    view: View,
    checkAttached: Boolean = true
): FlowSubscribeProxy<T>
```

`top-level` · L49

```kotlin
fun <T : Any> RxFlow<T>.bindLifecycle(
    view: View,
    checkAttached: Boolean = true
): FlowSubscribeProxy<T>
```

`top-level` · L61

```kotlin
fun View.asFlowScopeProvider(checkAttached: Boolean = true): FlowScopeProvider
```

`top-level` · L76

```kotlin
fun FlowDisposable.bindLifecycle(
    view: View,
    checkAttached: Boolean = true
): FlowDisposable
```

### FlowDisposableContainerExtensions.kt

路径：`com/xxf/coroutines/android/disposables/FlowDisposableContainerExtensions.kt`；包：`com.xxf.coroutines.android.disposables`。

`top-level` · L10

```kotlin
fun FlowDisposable.collectTo(destination: FlowDisposableContainer): Boolean
```

`top-level` · L13

```kotlin
fun FlowDisposable.bindDisposableContainer(destination: FlowDisposableContainer): Boolean
```

### FlowLifecycleFilterExtensions.kt

路径：`com/xxf/coroutines/android/lifecycle/FlowLifecycleFilterExtensions.kt`；包：`com.xxf.coroutines.android.lifecycle`。

`top-level` · L15

```kotlin
fun <T : Any> Flow<T>.filterWhen(
    owner: LifecycleOwner,
    vararg atLeastState: Lifecycle.State
): RxFlow<T>
```

`top-level` · L21

```kotlin
fun <T : Any> Flow<T>.filterWhen(
    lifecycle: Lifecycle,
    vararg atLeastState: Lifecycle.State
): RxFlow<T>
```

`top-level` · L30

```kotlin
fun <T : Any> RxFlow<T>.filterWhen(
    owner: LifecycleOwner,
    vararg atLeastState: Lifecycle.State
): RxFlow<T>
```

`top-level` · L36

```kotlin
fun <T : Any> RxFlow<T>.filterWhen(
    lifecycle: Lifecycle,
    vararg atLeastState: Lifecycle.State
): RxFlow<T>
```

### AndroidSchedulers.kt

路径：`com/xxf/coroutines/android/schedulers/AndroidSchedulers.kt`；包：`com.xxf.coroutines.android.schedulers`。

`AndroidSchedulers` · L21

```kotlin
fun mainThread(): Scheduler
```

### MainThreadDirectScheduler.kt

路径：`com/xxf/coroutines/android/schedulers/MainThreadDirectScheduler.kt`；包：`com.xxf.coroutines.android.schedulers`。

`top-level` · L14

```kotlin
fun scheduleDirectOnMain(action: Runnable): FlowDisposable
```

`top-level` · L22

```kotlin
fun scheduleDirectOnMain(
    action: Runnable,
    delay: Long,
    unit: TimeUnit
): FlowDisposable
```

### MainThreadSchedulerExtensions.kt

路径：`com/xxf/coroutines/android/schedulers/MainThreadSchedulerExtensions.kt`；包：`com.xxf.coroutines.android.schedulers`。

`top-level` · L10

```kotlin
fun <T : Any> Flow<T>.subscribeOnMain(): RxFlow<T>
```

`top-level` · L13

```kotlin
fun <T : Any> RxFlow<T>.subscribeOnMain(): RxFlow<T>
```

`top-level` · L17

```kotlin
fun <T : Any> Flow<T>.observeOnMain(
    delayError: Boolean = false,
    bufferSize: Int = 128
): RxFlow<T>
```

`top-level` · L24

```kotlin
fun <T : Any> RxFlow<T>.observeOnMain(
    delayError: Boolean = false,
    bufferSize: Int = 128
): RxFlow<T>
```

`top-level` · L32

```kotlin
fun <T : Any> Flow<T>.unsubscribeOnMain(): RxFlow<T>
```

`top-level` · L37

```kotlin
fun <T : Any> RxFlow<T>.unsubscribeOnMain(): RxFlow<T>
```

