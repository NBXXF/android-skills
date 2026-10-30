# Compose UI 性能门禁

## 读取时机

改动或审查任何 Compose UI 时读取本文件：`@Composable` 页面/组件、Lazy 列表/网格/瀑布流、动画与手势、自定义 Layout/绘制、自定义 modifier、状态管理与 Flow 收集、以及"卡顿/掉帧/滚动不稳/启动慢/重组过多"类问题排查。目标不是消灭重组，而是让用户可感知指标（帧耗时、启动、TTFD）在真机 release 下可测量地改善。

## 度量纪律（Measure → Diagnose → Fix → Verify）

- 一切结论基于 release + R8 + 真机。debug 数字不可用，四个原因：Compose 运行时按解释执行 + JIT 预热；Live Literals 把常量变 getter（污染稳定性报告）；无 R8 full mode；Layout Inspector 重组计数是采样近似。官方口径：debug→release 约有 75% 启动与 60% 帧渲染差距。
- 先测基线再改代码；每次只改一个变量并重测（一项修复一个 PR）；报告必须带 variant/设备/R8 状态。
- 修复循环：Macrobenchmark（`StartupTimingMetric` 冷启动 ≥10 次、`FrameTimingMetric` 滚动 P50/P90/P99 ≥5 次，`CompilationMode.Partial(BaselineProfileMode.Require)`）→ 编译器报告/trace 定位 → 单点修复 → 同场景重测。报中位数不报均值（热节流敏感）。指标细节：`FrameTimingMetric` 区分 `frameDurationCpuNs`（CPU 侧帧耗时）与总帧时；`StartupTimingMetric` 拆 `timeToInitialDisplayMs`/`timeToFullDrawMs`；jank 判定 deadline 随设备刷新率自适应，禁止硬编码 16.6ms 口径。
- trace 工具：引入 `androidx.compose.runtime:runtime-tracing`（BOM 自带）后自动为每个 restartable composable 的重组在 Perfetto/System Trace 生成函数名 section（inline 与 non-restartable 函数不出现）；开销极低，release 可保留；自定义段落用 `androidx.tracing.trace() {}`。生产监控用 JankStats 按生命周期聚合 FrameTiming 上报 P50/P90/P99（实战经验：卡顿常集中在导航图中单个低效 composable，修复后 P90 帧时可降 ~18%）。
- 编译器报告缓存坑：报告必须 release 产物，增量构建可能不重跑，必要时 `--rerun-tasks`。
- 量化论据（说服用）：Strong Skipping 使 Now in Android 首屏重组时间 -20%、Jetsnack time-to-first-pixel -17%；Baseline Profile 实战 Duolingo 启动 -30%、Meta included paths 执行 +40%。对 View 的对比口径（官方 Hero benchmark）：**滚动 jank 率 Compose 1.9+ 已与 Views 持平**；启动侧 1.11 实测 TTID 慢约 2.5%、TTFD 慢约 13%——"Compose 天然比 View 慢"的旧说法仅剩启动 TTFD 一角，别把它当宽恕滚动卡顿的理由。
- TTFD 用 `ReportDrawn`/`ReportDrawnWhen`/`ReportDrawnAfter`（androidx.activity.compose）标记，否则 `timeToFullDisplay` 少算。
- Baseline Profile：AGP 8.2+ Baseline Profile Generator 模块；`BaselineProfileRule` 必须覆盖启动 + 至少一条滚动路径；产物 `app/src/<variant>/generated/baselineProfiles/baseline-prof.txt` 入库；验证 APK 内存在 `assets/dexopt/baseline.prof`（缺失 = 接线错误 = 零收益）。
- **禁止把 skippable 比例当 KPI**：跳过本身不免费（每个参数都进 slot 表并在重组时比较）；重组调度启动才是大头。目标是让 composable 更便宜，而不是强行让一切可跳过。

## 三轴诊断框架

1. **参数稳定性/跳过**：参数是否稳定可比较，决定 restartable composable 能否跳过。
2. **State 读取阶段**：帧率级 State（滚动/动画/手势）是在 Composition 还是 Layout/Draw 读取。
3. **跨阶段回写**：更晚的阶段写快照状态，使更早阶段失效（如 `onSizeChanged` 写 Composition 读的状态）。

| 症状 | 首查病因 |
| --- | --- |
| Lazy 滚动掉帧 | 缺 `key`/`contentType`、item 参数不稳定、prefetch 不足 |
| 滚动/动画时整屏重组 | 状态在 Composition 读取（轴2）或回写（轴3） |
| 参数看似相等仍重组 | 不稳定参数 + 实例不等（`===` 失败）；或每次重组新分配 lambda/集合字面量 |
| `derivedStateOf` 不触发/每 tick 都触发 | 缺 `remember` 包裹、捕获非 state 值未做 key、或输入输出频率相同（不该用） |
| 自定义 modifier 每次父失效都重组 | `Modifier.composed {}` 每次新作用域 → 迁 Modifier.Node |
| 首帧弹跳/布局闪烁 | 回写（尺寸在 Layout 写、Composition 读） |
| 首滑内层 pager 卡顿 | 外层 Lazy 未做嵌套 prefetch（`NestedPrefetchScope`） |

假线索（不要白做）：对真实数据变化的重组是正常工作，不是性能问题；`remember(index) { isFirstRow(index) }` 替代内联 `when` 无收益；无证据时不做回调替换/相等性守卫/"缓存 Modifier 链"。

## 状态读取阶段（延迟读取）

- 三阶段 Composition → Layout → Draw，**N 阶段读取使 N 及以下全部失效**。把热状态读取压到最低阶段。
- 值形式 → lambda 形式对照：

| 值形式（Composition 读，热状态禁止） | lambda 形式（Layout/Draw 读） |
| --- | --- |
| `offset(x.dp, y.dp)` | `offset { IntOffset(x, y) }`（注意是**像素**） |
| `alpha(f)` / `rotate(f)` / `scale(f)` | `graphicsLayer { alpha/rotationZ/scaleX }` |
| `background(color)`（动画色） | `drawBehind { drawRect(color) }` |
| `padding(state.dp)`（动画内边距） | `layout { measurable, constraints -> ... }`（padding 无 lambda 版） |

- 多个逐帧变换合并进同一个 `graphicsLayer { }`（translation/scale/rotation/alpha/cameraDistance 一个 Draw 节点）；可重建资源（Path/Brush/渐变）用 `drawWithCache { ... onDrawBehind { } }`。
- 跨 composable 传递热值用 lambda provider `() -> T`（命名可加 `Provider` 后缀）；仅当消费端在 Layout/Draw 读取才有意义，Composition 读取就直接传值。细分口径：只读高频组件直传 `State<T>` 常优于 lambda（lambda 若在错误的 composition scope 内读取会把失效放大到父 scope）；一般场景正确 remember 的 lambda 惯用写法可接受。
- 例外：读取需要决定"发射哪棵组合树/哪个分支"时必须留在 Composition。

## 回写（backwards write）

- 严格定义：**先读后写**（同 pass `Read -> Write`，或 Composition 读 → Layout/Draw 写）。开头先写后读（`Write -> Read`）不是回写，但属"冗余状态包装"——同步值别包 `remember { mutableStateOf() }` 再立即覆盖，用局部 `val` 或在目标阶段直接读。
- 前向合法：Composition 写 → Layout/Draw 读；Layout 写 → Draw 读；事件回调（onClick 等用户事件）写；`LaunchedEffect` 协程写（谨慎，常暗示分层不当）。
- 禁止：`onSizeChanged`/`onPlaced`/`onGloballyPositioned`/自定义 LayoutModifier 写"Composition 已读"的状态——首帧尺寸错 + 二帧重排 + 可能死循环。
- 尺寸驱动的解法优先级：`aspectRatio`/custom `Layout`（测量阶段内完成）→ `FlowRow`/`LazyVerticalGrid`（测量期自适应）→ 窗口级判断提升到 WSC → 确需子组合分支才 `BoxWithConstraints`（有子组合成本）→ 最后手段才接受首帧错误。
- 同 pass 内写"已读状态"立即失效当前作用域；需要"组合内捕获会变的值"用 `rememberUpdatedState`（唯一合法例外）。

## 稳定性与 Strong Skipping（Kotlin 2.0.20+ 默认开启）

### 语义

- Strong Skipping 下所有 restartable composable 均可跳过：**稳定参数用 `equals` 比较，不稳定参数用 `===` 实例比较**。同一实例重复传入即可快速跳过（O(1)）。
- Compose 编译器 feature flag 四件套及默认态：`StrongSkipping`（Kotlin 2.0.20+ 默认开）、`IntrinsicRemember`（默认开，编译期折叠输入静态不变的 remember）、`OptimizeNonSkippingGroups`（默认关 opt-in，开启后去掉非 restartable composable 的 group 记账）、`PausableComposition`（默认关，预取可暂停的编译器前提）。改动编译器 flag 必须说明动机并测量。
- `@Composable` 函数内的**捕获型 lambda 自动 `remember(captures)`**；无捕获 lambda 是编译器单例。
- 自动 memoize **不覆盖**非 @Composable 作用域：`LazyListScope.items {}`、`Modifier.pointerInput/drawBehind/drawWithCache {}`、对象表达式。这些内部的热 lambda 手动提升：`remember(id) { { vm.select(id) } }` 或直接传方法引用 `vm::select`。
- composable 参数里的集合/对象字面量（`listOf(...)`、`map { }` 产物）每次重组都是新实例，`===` 必失败 → 提升为 `remember` 或顶层 `persistentListOf`。
- lambda 捕获不稳定对象（如 ViewModel）会把不稳定性传染给整个调用点；四档修法按优先级：**方法引用 `vm::fn` > `remember(捕获变量) { lambda }` > 只调顶层函数的 lambda > 仅捕获稳定类型**。该规则在 Strong Skipping 时代依然必要（`===` 不豁免新实例）。
- `@NonRestartableComposable` 只用于"不直接读状态的小函数"——读状态的函数禁用（移除重启作用域后，状态变化会被迫上溯失效更大的 scope）；默认参数表达式被标 `@dynamic`（如不稳定 lambda 默认值）会破坏跳过，改显式传参。
- 外部库/非 Compose 模块类型可临时用 `@Stable class StableHolder<T>(val item: T)`（equals 委托 item）包装救急，正解是屏幕级 UI model 由 ViewModel 映射。

### 官方口径与纠偏

官方有两套口径：**人类指南页**（stability/fix、strongskipping）仍把 `ImmutableList`/`@Stable` 列为常规手段，只提醒"贵 `equals` 的比较成本可能超过一次廉价重组"；**官方 agents/skills 参考**（2026 收紧口径）对集合模型明显更保守。按场景裁决，不要一刀切：

- **喂给 Lazy 布局的大数据集/深嵌套模型**（feed 流、`Post{List<Paragraph>, List<Markup>}` 级嵌套）：不要加 `@Stable`/`@Immutable`、不要换 `ImmutableList`——O(N) 结构性 `equals` 每次重组都跑，比 O(1) `===` 更贵，trace 里常见 `Model.equals` 吃掉大头帧时间；存量此类注解建议移除（仅限本场景）。
- **非 Lazy 或小而有界集合的模型**（卡片带 2-5 个徽标/缩略图）：`ImmutableList` + `@Immutable` 仍是合理手段；**存量注解一律不动**、禁止批量 grep 标记。
- 新增注解仅当三条件同时满足：编译器无法推断（跨模块/接口）+ 上游（Room/MVI reducer 等）对未变数据每次发新实例 + 类小而平、`equals` O(1)。
- `ImmutableList` 解包双重 O(N) 陷阱：父比较 data class equals 遍历列表一次，子再收 `ImmutableList` 参数又比一次。标准 `List` 解包传参反而是 O(1)。
- 逃生舱须一行注释说明理由：`@DontMemoize`（只标 lambda 表达式处，故意每次新捕获）、`@NonSkippableComposable`（纯副作用 composable，如调试 overlay）、`@NonRestartableComposable`（几乎不用）。
- 辅助注解（`runtime-annotation` 1.9+，配 lint）：`@FrequentlyChangingValue`（标记高频变化值，勿依赖其相等性做跳过）、`@RememberInComposition`（提示需要 remember）；`@Stable`/`@Immutable`/`@StableMarker` 同样来自该工件，纯 Kotlin 数据模块 compileOnly 引入即可。
- `@ReadOnlyComposable` 仅当函数体只读组合值（token 访问器）；调用布局/效果/`remember` 的函数禁止标注。

### 诊断与门禁工具链

- Compose Compiler 报告（**只能读 release 产物**，debug 被 Live Literals 污染）：`composeCompiler { reportsDestination/metricsDestination }`，产物四文件 `<module>_release-{classes,composables}.txt`、`-composables.csv`、`-module.json`。先读 `composables.txt` 找 `restartable` 非 `skippable` 与 `unstable` 参数，再回 `classes.txt` 找根因（var/泛型/不稳定嵌套）；`runtime stable class` 是正常惰性判定不是问题；`module.json` 计数只做回归哨兵。
- 热点分级按**频率 × 成本**：Lazy item 内的 composable 优先，一次性启动屏幕不追。
- 运行时确认：Layout Inspector（debug 快速分诊）→ `@TraceRecomposition(traceStates = true)`（skydoves compose-stability-analyzer 插件，可用于 release-with-symbols；`ComposeStabilityAnalyzer.setEnabled(BuildConfig.DEBUG)` 必须门禁化，禁止生产硬编码开）。logcat `-s Recomposition:D` 读 `[Recomposition #N]` 累计计数与参数 diff。
- CI 回归门禁：`composeStabilityAnalyzer { stabilityValidation { failOnStabilityChange.set(true) } }`；`:stabilityDump` 生成 `.stability` 基线入库（放模块内目录，不放 `build/`），CI 跑 `:stabilityCheck`，skippable 变差即红。
- `Flow<T>` 禁止作为 composable 参数（无稳定身份、阻断跳过、生命周期不清）：上游收集成值再传。纯 Kotlin 数据模块用 `androidx.compose.runtime:runtime-annotation`（compileOnly）提供注解，不拖全量 runtime。

## Lazy 布局

- `key` 与 `contentType` 双强制：key 用服务端稳定 ID 且为**原始类型**（Int/Long/String）；禁止 index、每次求值的 `UUID.randomUUID()`、可变对象的 `hashCode()`。异构 feed（卡片+头+广告）必须 `contentType = { it::class }`，否则跨类型复用槽位即全量重建。
- `Modifier.animateItem()`（1.7+ GA）依赖稳定 key，无 key 静默失效。
- item 内禁止：`list.indexOf(item)`（用 `itemsIndexed`）；逐项查 `CompositionLocal`（父级解析后下传）；`LaunchedEffect(Unit)` 曝光埋点（预组合导致提前/虚假曝光，用 `Modifier.onVisibilityChanged` + 停留阈值；`onFirstVisible` 已于 1.11 弃用）；逐项 `collectAsStateWithLifecycle()`（共享流父级收集一次传值）。
- 选中态跟踪用 `mutableStateOf(set)`/`mutableStateSetOf`（O(1) 查询），叶子传 `isSelected: () -> Boolean` lambda provider 隔离重组；`SnapshotStateList` 反复查询先 `.toList()`/`.toSet()`。
- painter/`BorderStroke`/shape 等重建项提出 items lambda；**Modifier 链已被结构化驻留**，`remember { Modifier... }` 是微优化，无 FrameTimingMetric 证据禁止加。
- 小而有界集合（约 ≤10 项）用 `Row/Column` + `forEach`，免掉懒加载虚拟化开销；scope guard：key/contentType 规则只适用于 Lazy 容器，别标记普通 Column 遍历。
- prefetch：默认优先。版本口径分清：预取"可暂停组合"1.10.0 曾默认开、**1.10.6 因稳定性回退默认关**、1.13 起移除 flag 转常开；`LazyLayoutCacheWindow` 在 1.9–1.12 为实验性且只能经 `rememberLazyListState(cacheWindow = ...)` 传入，**1.13 起 stable 且可直接给 LazyColumn/LazyRow 传参**（旧方式与 `LazyListPrefetchStrategy` 废弃），并提供按平均 item 尺寸自适应的动态默认窗口——手动调窗需求进一步降低。确要手配时仅凭 FrameTimingMetric 证据，Dp 单位，宽窗口=内存+反向浪费。内嵌 lazy（LazyColumn 行内 HorizontalPager）实现 `NestedPrefetchScope` 链式预热。

## 副作用与 Flow

- 决策树：要协程 → `LaunchedEffect(keys)`；非协程订阅要拆装 → `DisposableEffect(key) { onDispose {} }`；同步跟 key 反应 → 别起协程作用域（同步轻量场景 `SideEffect`，1.12+ 支持 `SideEffect(keys)`）；一次性初始化 → `remember {}` 而非 `LaunchedEffect(Unit)`。
- 长寿命 `LaunchedEffect` 消费外部回调必须 `rememberUpdatedState` 包装，否则协程持有旧引用。
- 禁止：非挂起操作写进 `LaunchedEffect`（日志/同步赋值）；空 `onDispose {}` 的 `DisposableEffect` 当占位；动画/滚动中高频换 key 重启 effect（协程取消有成本）。
- 多个 `LaunchedEffect(Unit)` 合并为一个 + 嵌套 `launch`，减少 effect 节点与协程启动；可选回调先 `if (callback != null)` 守卫再启动。
- Flow 收集：外部流（VM/仓库/传感器）一律 `collectAsStateWithLifecycle()`（默认 STARTED；焦点专属控件 RESUMED；禁 CREATED）；内存内轻量 StateFlow 可 `collectAsState`（lifecycle 版订阅/分发开销约为其 3-4 倍，纯内存流不值得）。高频流（>~10ms/次）加 `.conflate().distinctUntilChanged()` 且操作链包 `remember(key)`。
- 派生状态决策（1.13+）：简单条件/过滤（`scrollState.value > 0`）用 `computedStateOf`（失效路径显著更快；注意该取舍口径出自官方 agents/skills 参考，人类 best-practices 页暂只讲 `derivedStateOf`）；重计算多次读取用 `derivedStateOf`；平凡取反/属性查值用普通 `get()`。`derivedStateOf` 必须 `remember {}` 包裹，捕获的非 state 值全部做 key，**禁止**把 `state.value` 传成 key（等于每次变更重建、彻底废掉过滤）；输入频率 ≈ 输出频率时两者都不用。同步派生禁 `produceState + snapshotFlow`（白付协程与 flow 派发）；fire-and-forget 副作用（埋点/日志）用 `LaunchedEffect { snapshotFlow {}.distinctUntilChanged().collect {} }`。
- 整表替换场景用 `mutableStateOf(mutableListOf(), neverEqualPolicy())` + 载荷赋值（`state.value = list`），比 `mutableStateListOf` 逐元素跟踪便宜。
- 一次手势/事件内的多次状态写包进 `Snapshot.withMutableSnapshot { }`：合并为一次失效、一次重组，并防 torn reads；后台线程裸写 `MutableState` 由快照隔离保证安全。

## 布局与子组合

- `BoxWithConstraints`/`SubcomposeLayout` 禁止：只为读 `maxWidth`（改 `Modifier.onSizeChanged`/`layout {}`）；放进 Lazy item（每 item 一次测量期子组合，提升到列表父级判断后传 Boolean 下传）；`Scaffold` 嵌 `Scaffold`（用现成槽位）。
- 合法保留（子内容组合真依赖测量值）时：`SubcomposeLayoutState(SubcomposeSlotReusePolicy(n))` 复用槽位；可预测槽位提前 `state.precompose(slotId, content)`；measurePolicy 内不要每次测量新建组合 lambda（AndroidX 内部 lint 同款反模式）。
- 坐标类：避免 `onGloballyPositioned`（用 `onPlaced`/`onLayoutRectChanged`（性能优于 onGloballyPositioned）/`Modifier.Node` 内按需 `requireLayoutCoordinates()`）；可见性跟踪用 `Modifier.onVisibilityChanged`（Compose 1.9+，配 `minDurationMs` 停留时长与 `minFractionVisible` 可见比例阈值）；浮层锚定（tooltip/角标）用 custom `Layout` 同时测量放置双方，禁止坐标存 `MutableState` 再 `offset`（一帧滞后 + 二次组合）。
- 减树深：去掉装饰性 `Box`/`Canvas` wrapper，修饰直接挂 modifier 或 `drawBehind`；intrinsic 测量链别深嵌。

## 动画与图形

- 动画属性（alpha/scale/rotation/translation/color）一律 `graphicsLayer {}`；尺寸过渡用 `Modifier.animateContentSize` / `animateBounds`；`Lazy` item 的 `sharedElement`/`sharedBounds` 挂在可见性指示（`onVisibilityChanged`）之后，避免预取项实例化过渡作用域。
- `Animatable` 作为 `Modifier.Node` 的持久成员，`onAttach()` 里 `coroutineScope.launch` 启动。
- 绘制：装饰性 `Canvas` 换 `Modifier.drawWithCache`（缓存 Path/Paint/Brush）；热绘制循环 `Path.rewind()` 优于 `reset()`；网络图用 Coil `AsyncImage`（`Image`+bitmap 不缓存）；泛型元组/集合用 `androidx.collection`（`MutableLongSet`）与 `packInts`；`RuntimeShader`/`ShaderBrush` 在 composition `remember`，尺寸 uniform 进 `drawWithCache`，逐帧 uniform 进 `onDrawBehind`。

## 数据、文本与图像

- 数据→UI 转换链（VM/Repository 的 `filter/map` 链）**禁止习惯性 `asSequence`**：kotlinx-benchmark 实测比普通 List 慢 9%（简单链）~45%（复杂链）；大数据集选普通 List 或 `ImmutableArray`。IntelliJ 的"转 Sequence"建议不要采纳。
- 富文本：`buildAnnotatedString` 结果包 `remember(text) { ... }`，静态富文本提升为顶层 `val`；**`ParagraphStyle` 变更（行高/对齐/maxLines）触发整段 re-layout，`SpanStyle`-only 变更显著更便宜**——频繁变化的样式用 SpanStyle，段落级样式保持稳定；列表热路径禁止每次重组新建 `AnnotatedString` 实例（迫使 paragraph 重新校验布局）。
- Coil 3 图片：`placeholderMemoryCacheKey`（传入前图缓存 key）实现转场即时占位命中；`precision` 默认按组件尺寸解码，勿盲目 EXACT；`allowHardware` 默认 true，仅 Palette/模糊/取像素时关闭；用 `SingletonImageLoader` 共享单例防缓存碎片；网格/列表场景保证 `memoryCacheKey` 跨重组稳定。

## RecyclerView 互操作（ComposeView 嵌 RV）

- RecyclerView ≥1.3 + Compose ≥1.2 起 pooling container 默认策略 `DisposeOnDetachedFromWindowOrReleasedFromPool` 自动复用 composition；**删除旧教程的 `onViewRecycled` 手动 `disposeComposition()` 与 `DisposeOnViewTreeLifecycleDestroyed`**（会覆盖更优默认）。
- 状态串位陷阱：item 的 `remember` 状态跨 recycle 保留，会串到同类型其他行——状态提升到 adapter，或 `key(唯一id) { }` 强制重建（有重建代价）。
- 离屏未销毁 item 的动画/重组仍运行并拖累滚动：`onViewDetachedFromWindow` 中对提升的 `Animatable.stop()`。

## 自定义 Modifier

- 新写自定义 modifier 一律 `ModifierNodeElement` + `Modifier.Node`（能力接口 `DrawModifierNode`/`LayoutModifierNode`/`SemanticsModifierNode`/`CompositionLocalConsumerModifierNode`+`currentValueOf`，委托子节点用 `DelegatingNode`）；存量 `Modifier.composed {}` 有重组/分配成本，触及即评估迁移：

```kotlin
fun Modifier.circle(color: Color) = this then CircleElement(color)
private data class CircleElement(val color: Color) : ModifierNodeElement<CircleNode>() {
    override fun create() = CircleNode(color)
    override fun update(node: CircleNode) { node.color = color }
}
private class CircleNode(var color: Color) : DrawModifierNode, Modifier.Node() {
    override fun ContentDrawScope.draw() = drawCircle(color)
}
```

- modifier 顺序是可观测语义不是风格：链自上而下=层层包裹下方一切。`clickable` 命中区=其所在位置边界（要 48dp 触控目标就放在视觉 padding 之外；只点可见区就放 padding 之后）；`clip` 裁剪其下方一切（圆角底色用 `background(color, shape)` 一步到位）；`graphicsLayer` 只包裹其下方内容（整体淡出放链首）。禁止用 `composed {}` 修顺序问题。

## 门禁执行口径（AI 审计）

1. 按上述十类**逐类过完**再下结论，不要首个命中即停；每条发现必须落到"症状 → 证据（编译器报告行/trace/计数）→ 最小修复 → 验证方式"，报告要能点名 composable 与变化参数（"它重组很多"不是发现）。
2. 修复建议一次一个轴、可 bisect；无法测量时区分"已证实路径"与"未测量成本"，给条件性建议，不凭感觉开方。
3. Pass/Warn/Block 建议：触及 Lazy item 不稳定参数、回写死循环风险、Lazy item 内子组合/埋点 effect → Block 候选；非热点一次性屏幕的小问题 → Warn；纯重构无运行时差异 → Pass 并注明未测量项。
4. 修复后闭环：同场景重测（重组计数趋平、帧指标改善）+ `:stabilityCheck` 不红 + 基线 profile 再生成入库；无法闭环时在结论中列为残余风险。
5. 混淆/R8 相关按 `aaaaa-xxf-code-shrinking-guard`；UI 视觉对齐按 `aaaaa-xxf-ui-design-alignment`；变更验证范围按 `aaaaa-xxf-test-strategy`。

## 版本速查

当前稳定基线（2026-10）：BOM **2026.09.00** → foundation/runtime/ui **1.12.1**；beta 通道 1.13.0-beta02。核验方法：release notes + Google Maven 字节码比对。

| 能力 | 最低版本 |
| --- | --- |
| Strong Skipping 默认开 | Kotlin 2.0.20+ |
| `stabilityConfigurationFiles` DSL | Compose Compiler 1.5.5+ |
| `@Stable`/`@Immutable` 移入 runtime-annotation（+`@FrequentlyChangingValue`/`@RememberInComposition`） | runtime-annotation 1.9+ |
| `Modifier.onVisibilityChanged`/`onLayoutRectChanged` | Foundation 1.9+ |
| `Modifier.animateItem()` GA（废 `animateItemPlacement`）/ `rememberGraphicsLayer` | 1.7+ |
| `LazyLayoutCacheWindow` | Foundation 1.9.0-alpha01（实验）；**1.13 stable + LazyColumn 直参 + 动态默认窗口** |
| 预取组合可暂停 | 1.10.0 默认开 → **1.10.6 回退默认关** → 1.13 起常开 |
| `SideEffect(keys)` | Runtime 1.12+（1.12.0-alpha02） |
| `computedStateOf`（块强制只读） | Runtime 1.13+（1.13.0-alpha03） |
| Baseline Profile Generator 模板 | AGP 8.2+ |

### 1.11–1.13 性能演进速览（触及相关场景时知道版本自带收益/修复）

- **1.11**：`LinkTable` 实验 flag（`isLinkBufferComposerEnabled`，默认关；列表重排类重组提速 2x+、其余约 10%）；`Modifier.visible()` 条件跳过绘制；`MeasuredSizeAwareModifierNode`；LazyStaggeredGrid×LookaheadScope 内存泄漏修复；`onFirstVisible` 弃用→`onVisibilityChanged`。
- **1.12**：BasicTextField min/maxLines 高度计算优化（默认开）；`softWrap=false` 行高计算优化；scroll capture 跨子组合传播优化；`derivedStateOf` 内存泄漏修复；测试协程默认 StandardTestDispatcher（`createComposeRule` 注意共享 dispatcher）。
- **1.13**：`LazyLayoutCacheWindow` stable + staggered grid/多 lane 支持 + 动态默认窗口；预取可暂停常开（`LazyListPrefetchStrategy` 废弃）；`VectorPainter` 跨组件共享 ImageBitmap（重复图标省纹理上传与内存）；单行文本行高测量优化默认开；CompositionLocal 动态解析优化；SaveableStateRegistry 改 ScatterMap 消 HashMap 分配。
