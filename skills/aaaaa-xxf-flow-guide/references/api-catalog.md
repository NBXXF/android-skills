# RxStyle Flow API 导航与源码覆盖

## 如何查询

- 不知道业务该选哪个操作符：读 [响应式设计与组合](reactive-design.md)。
- 知道函数名，想看作用、错误/完成/取消、线程与例子：读 [操作符参考](operator-reference.md)。
- 需要**每个显式 overload 的完整签名**：按本页文件名查 [公开函数签名快照](api-signatures.md)，保留 receiver、泛型、参数名、默认值与 suspend。
- 当前依赖有差异：以当前版本源码/测试为准。快照不是在线最新版，也不是所有 kotlinx Flow / RxJava 操作符目录。

## 包与类型边界

| 导入包 | 能力 | 返回与约束 |
|---|---|---|
| `com.nbxxf.kpower.coroutines.rxstyle.flow` | Flows、RxFlow、Observer、subscribe、核心 operators、FlowPlugins/debug | RxStyle T : Any；map/filter 仅显式 RxFlow 扩展 |
| 上述包的 `.schedulers` | Scheduler、Schedulers、线程便捷扩展 | 不把 CoroutineDispatcher 直接传给需要 Scheduler 的函数 |
| `.disposables` | FlowDisposable、CompositeFlowDisposable、SerialFlowDisposable、FlowDisposableContainer | dispose 不发 onComplete |
| `.observers` | DisposableFlowObserver | 自管理订阅，支持 onStart |
| `.autodispose` | converter、proxy、scope 协议、核心 autoDisposable/to、ManualFlowScopeProvider、插件 | proxy 仅终端 API |
| `com.nbxxf.kpower.coroutines.transform.suspend2flow` | suspendAsFlow、suspend 函数引用 asFlow | **原生 Flow**，默认 IO |
| `com.nbxxf.kpower.coroutines.transform.flow2stateflow` | Flow.asStateFlow | stateIn 包装 |
| `com.nbxxf.kpower.coroutines.transform.suspend2stateflow` | suspendAsStateFlow | 原生共享状态 |
| `com.xxf.coroutines.android.autodispose` | Android autoDisposable、bindLifecycle、FlowLifecycle、asFlowScopeProvider | AndroidX / View 生命周期 |
| `com.xxf.coroutines.android.schedulers` | AndroidSchedulers、Main 便捷扩展、scheduleDirectOnMain | 数据 UI 通知显式切 Main |
| `com.xxf.coroutines.android.lifecycle` | filterWhen | 每值至少状态 OR 判断；不取消、不重启 |
| `com.xxf.coroutines.android.disposables` | collectTo、bindDisposableContainer | 返回 Boolean，不是 FlowDisposable |

## 创建源完整名称索引

均在 `Flows.kt`；所有显式重载见签名快照 `Flows.kt` 小节。

| 类别 | 函数（重载区别） |
|---|---|
| 固定/终态 | just(value / first,second,vararg)、empty、error(Throwable / suspend supplier)、never |
| 延迟/执行 | create、defer、fromCallable、fromSupplier、fromSuspend、fromAction、fromRunnable、fromResult |
| 集合/范围 | fromArray、fromIterable、fromSequence、range、rangeLong |
| callback/资源/包装 | fromCallback(register,unregister)、using(resourceFactory,flowFactory,disposer)、wrap |
| 时间 | timer(delay[,scheduler])；interval(period[,scheduler] / initialDelay,period[,scheduler])；intervalRange(start,count,initialDelay,period[,scheduler]) |
| 多源 | concat(vararg / Iterable)、merge(vararg) |

## 操作符完整名称索引

receiver 记法：**双** = Flow/RxFlow 各有显式 overload；**Flow** = Flow 入口，可接收 RxFlow，但内部可能走原生 collect 桥接；**RxFlow** = 只为 RxFlow 声明，普通 Flow 同名函数需看 kotlinx import。

| 源文件 | 函数 / 重载族 | receiver / 详细语义 |
|---|---|---|
| `RxFlowOperators.kt` | map、filter | RxFlow；[转换过滤](operator-reference.md#2-转换过滤去重值变成什么) |
| 同上及 `FlowLifecycleExtensions.kt` | doOnNext、doAfterNext、doOnError、doOnComplete、doOnTerminate、doAfterTerminate、doOnDispose、doOnSubscribe、doFinally、doOnLifecycle、doOnEach | 双；[副作用](operator-reference.md#9-副作用与-finally挂在哪个信号上) |
| `FlowTransformExtensions.kt` | skip(count)、skipWhile、switchMap、concatMap | 双；[扁平化](operator-reference.md#3-扁平化如何处理由事件触发的异步任务) |
| 同上 | ofType<R>() | Flow<*> / reified；[过滤](operator-reference.md#2-转换过滤去重值变成什么) |
| `FlowDistinctExtensions.kt` | distinctUntilChanged() / (keySelector) / (areEqual)；distinctUntilChangedByHash() | distinct 双；ByHash 仅 Flow；[去重](operator-reference.md#2-转换过滤去重值变成什么) |
| `FlowStartEmptyExtensions.kt` | defaultIfEmpty、switchIfEmpty(Flow / supplier)、startWithItem、startWith、startWithArray、startWithIterable | 双；[空流和前缀](operator-reference.md#4-空流回退与前缀) |
| `FlowErrorExtensions.kt` | onErrorReturnItem、onErrorReturn、onErrorResumeNext、onErrorComplete(predicate={true}) | 双；[恢复](operator-reference.md#5-错误恢复与重新订阅) |
| `FlowRetryExtensions.kt` | retry() / (times) / (times,predicate)；retryUntil | 双；同上，predicate 同步 |
| `FlowRepeatExtensions.kt` | repeat() / (times)；repeatUntil | Flow；同上，repeatUntil 支持 suspend |
| `FlowCombineExtensions.kt` | combineLatest、withLatestFrom、zipWith、concatWith、mergeWith | Flow；[多源](operator-reference.md#6-多源组合哪个事件驱动输出)；前三个 transform suspend |
| `FlowGateExtensions.kt` | takeUntil(predicate / other)、skipUntil(other) | Flow；[门控](operator-reference.md#7-门控与截断丢值停源还是延后启动) |
| `FlowTimeExtensions.kt` | delay(duration[,scheduler])、delaySubscription(duration[,scheduler] / other)、throttleFirst、throttleLast、throttleWithTimeout（各有 scheduler 重载） | Flow；[时间](operator-reference.md#8-时间计时点尾值与通知线程) |
| `RxFlowScheduling.kt` | subscribeOn、observeOn(scheduler,delayError=false,bufferSize=128)、unsubscribeOn | 双；[调度](operator-reference.md#10-调度函数任务与信号分别在哪执行) |
| `schedulers/FlowSchedulerExtensions.kt` | subscribeOnComputation/IO/NewThread/Single/Trampoline；observeOnComputation/IO/NewThread/Single/Trampoline(delayError=false) | 双；便捷 observeOn 不暴露 bufferSize |
| `FlowDebug.kt` | debug(identifier=null,trimOutput=false) | 双；[副作用与诊断](operator-reference.md#9-副作用与-finally挂在哪个信号上) |
| `autodispose/FlowAutoDispose.kt` | to(converter)、autoDisposable(scopeProvider / CoroutineScope)、CoroutineScope.asFlowScopeProvider | to 双；[生命周期](operator-reference.md#12-android-生命周期过滤与取消) |

## 终端与辅助协议完整索引

| 文件 / 类型 | API | 细节 |
|---|---|---|
| `RxFlow.kt` / `FlowRxInterop.kt` | subscribe() / (onNext) / (onNext,onError) / (onNext,onError,onComplete) / (observer)；subscribeWith(observer) | RxFlow 成员 + Flow 扩展；observer overload 为 Unit，其余 lambda 返回 FlowDisposable |
| `FlowBlockingExtensions.kt` | blockingFirst() / (defaultValue)、blockingLast() / (defaultValue)、blockingForEach(onNext)、blockingSubscribe 0/1/2/3 callback | 无 timeout overload；主线程禁止 |
| `FlowObserver` / `FlowSubscribeSource` / `FlowCallback` | onSubscribe/onNext/onError/onComplete；subscribe(observer)；callback 三信号 | FlowCallback 没有 onSubscribe |
| `FlowDisposable` | isDisposed、dispose；companion.disposed/empty/fromAction | 属性未收入函数快照 |
| `FlowDisposableContainer` / `CompositeFlowDisposable` | add/remove/delete；addAll/size/clear/dispose；Composite 构造器 empty/vararg/Iterable | clear 复用，dispose 关闭 |
| `SerialFlowDisposable` | get/set/replace/dispose；构造可带 initialDisposable | set 释放旧句柄，replace 不释放 |
| `DisposableFlowObserver` | onSubscribe/dispose/isDisposed；protected onStart 扩展点 | protected 方法不在公开函数快照 |
| `Scheduler` / `Worker` | createWorker；scheduleDirect(action[,delay])；schedule(action[,delay])；schedulePeriodically(action,initialDelay,period)；dispose/isDisposed | 延迟 Duration；Worker 串行 |
| `Schedulers` | computation/io/single/newThread/trampoline/from(CoroutineDispatcher) | [调度语义](operator-reference.md#10-调度函数任务与信号分别在哪执行) |
| `FlowConverter` / `FlowSubscribeProxy` | apply；subscribe/subscribeWith 终端族 | proxy 继承 subscribe(observer) 协议 |
| `FlowScopeProvider` / `FlowScopeSource` / `FlowScopeObserver` | requestScope；UNBOUND；subscribe；onSubscribe/onReady/onComplete/onError | ready 握手 |
| `ManualFlowScopeProvider` | requestScope/end/dispose/close/isDisposed | 显式结束，不重开 |
| `FlowPlugins` | set/getErrorHandler、set/getScheduleHandler、set/getLogHandler、reset/lockdown/isLockdown、onError/onSchedule | onLog 是 **internal**，供 debug 实现使用，不是公开调用 API |
| `FlowAutoDisposePlugins` | set/getOutsideScopeHandler、reset | 只处理 outside-scope |
| 错误与日志模型 | CompositeFlowException.errors；FlowUndeliverableException；FlowOnErrorNotImplementedException；FlowProtocolViolationException；OutsideFlowScopeException；FlowDebugEvent(kind,label,value,error)/Kind | [协议](operator-reference.md#13-资源scope-与全局插件协议) |

## Android 完整索引

| 文件 | API / 全部参数族 |
|---|---|
| `LifecycleAutoDispose.kt` | autoDisposable(owner / lifecycle[,untilEvent] / viewModel)；Flow/RxFlow.bindLifecycle(owner / lifecycle[,untilEvent] / viewModel)；owner/lifecycle.asFlowScopeProvider(untilEvent=ON_DESTROY) |
| `ViewAutoDispose.kt` | autoDisposable(view,checkAttached=true)；Flow/RxFlow.bindLifecycle(view,checkAttached=true)；View.asFlowScopeProvider(checkAttached=true)；FlowDisposable.bindLifecycle(view,checkAttached=true) |
| `FlowDisposableLifecycleExtensions.kt` | FlowDisposable.bindLifecycle(owner / lifecycle,untilEvent=ON_DESTROY) |
| `FlowLifecycle.kt` | facade.bindLifecycle(owner / lifecycle[,untilEvent] / viewModel / scope / view[,checkAttached])，均返回 converter |
| `FlowLifecycleFilterExtensions.kt` | Flow/RxFlow.filterWhen(owner / lifecycle,vararg atLeastState) |
| `FlowDisposableContainerExtensions.kt` | FlowDisposable.collectTo / bindDisposableContainer(destination)，返回 Boolean |
| `AndroidSchedulers.kt` | AndroidSchedulers.mainThread() |
| `MainThreadSchedulerExtensions.kt` | Flow/RxFlow.subscribeOnMain / observeOnMain(delayError=false,bufferSize=128) / unsubscribeOnMain |
| `MainThreadDirectScheduler.kt` | scheduleDirectOnMain(action: Runnable) / (action,delay: Long,unit: TimeUnit) |

`LifecycleScopeSubscription.kt` 是 internal 实现，不作为业务 API。Android 模块通过 api 暴露核心库与 Lifecycle 类型，不要向 JVM 模块导入 Android 包。接入坐标/版本读取目标工程 version catalog；当前模块 Manifest 没有专门的权限/组件接入步骤，不为普通 Flow 使用虚构初始化、权限或 keep 规则。

## 快照来源、更新与漂移检查

本次源码范围：

- `/Users/xxf/Documents/developer/java/work_space/KPower/core/reactive-coroutines/src/jvmMain/kotlin`
- `/Users/xxf/Documents/developer/android/work_space/xxf_android/core/reactive-coroutines-android/src/main/java`

路径用于本机维护证据，业务使用 skill 不要求存在这些绝对路径；可传其他 checkout 的模块根目录。生产 Kotlin 文件集合与内容摘要写在签名快照中，可区分本地未提交改动，优于仅记录 Git HEAD。

```bash
python3 scripts/build-api-snapshot.py \
  --core /path/to/KPower/core/reactive-coroutines \
  --android /path/to/xxf_android/core/reactive-coroutines-android

# 校验同一源码是否已经漂移，不修改文件
python3 scripts/build-api-snapshot.py \
  --core /path/to/KPower/core/reactive-coroutines \
  --android /path/to/xxf_android/core/reactive-coroutines-android \
  --check
```

在 skill 根目录执行。脚本是针对当前 Kotlin 源码风格的静态抽取器，不是 Kotlin parser/编译器，不展开继承成员、编译器生成 API 或 Java synthetic overload。刷新后人工核对新增语法与函数覆盖，更新本目录、语义参考和示例，再同步 skills/.agents/.claude 三处。

验证行为时看 `src/jvmTest/.../rxstyle/flow`：RxFlowCoreTest、RxFlowSemanticsTest、RxFlowTransformTest、RxFlowRetryDistinctTest、RxFlowTimeSourceTest、FlowCombineGateTest、FlowTimeExtensionsTest、FlowAutoDisposeTest、FlowDisposableTest、FlowBlockingTest、FlowDebugTest、TestFlowSchedulerTest。这些是源码证据入口，不代表当前任务已运行全部测试。
