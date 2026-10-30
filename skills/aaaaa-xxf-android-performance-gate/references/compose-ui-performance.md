# Compose UI 性能门禁

## 读取时机

改动或审查任何 Compose UI 时读取本文件：`@Composable` 页面/组件、Lazy 列表/网格/瀑布流、动画与手势、自定义 Layout/绘制、自定义 modifier、状态管理与 Flow 收集、以及"卡顿/掉帧/滚动不稳/启动慢/重组过多"类问题排查。目标不是消灭重组，而是让用户可感知指标（帧耗时、启动、TTFD）在真机 release 下可测量地改善。

## 度量纪律（Measure → Diagnose → Fix → Verify）

- 一切结论基于 release + R8 + 真机。debug 数字不可用，四个原因：Compose 运行时按解释执行 + JIT 预热；Live Literals 把常量变 getter（污染稳定性报告）；无 R8 full mode；Layout Inspector 重组计数是采样近似。官方口径：debug→release 约有 75% 启动与 60% 帧渲染差距。
- 先测基线再改代码；每次只改一个变量并重测（一项修复一个 PR）；报告必须带 variant/设备/R8 状态。
- 修复循环：Macrobenchmark（`StartupTimingMetric` 冷启动 ≥10 次、`FrameTimingMetric` 滚动 P50/P90/P99 ≥5 次，`CompilationMode.Partial(BaselineProfileMode.Require)`）→ 编译器报告/trace 定位 → 单点修复 → 同场景重测。报中位数不报均值（热节流敏感）。
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
- 跨 composable 传递热值用 lambda provider `() -> T`（命名可加 `Provider` 后缀）；仅当消费端在 Layout/Draw 读取才有意义，Composition 读取就直接传值。
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
- `@Composable` 函数内的**捕获型 lambda 自动 `remember(captures)`**；无捕获 lambda 是编译器单例。
- 自动 memoize **不覆盖**非 @Composable 作用域：`LazyListScope.items {}`、`Modifier.pointerInput/drawBehind/drawWithCache {}`、对象表达式。这些内部的热 lambda 手动提升：`remember(id) { { vm.select(id) } }` 或直接传方法引用 `vm::select`。
- composable 参数里的集合/对象字面量（`listOf(...)`、`map { }` 产物）每次重组都是新实例，`===` 必失败 → 提升为 `remember` 或顶层 `persistentListOf`。

### 官方纠偏（勿沿用旧"全家桶稳定化"口径）

- **禁止**给含大集合/深嵌套的模型加 `@Stable`/`@Immutable`，**禁止**把 `kotlin.collections.List` 换成 `ImmutableList`：O(N) 结构性 `equals` 每次重组都跑，比 O(1) `===` 更贵；trace 里常见 `Model.equals` 吃掉大头帧时间。
- 只在三个条件同时满足才加注解：编译器无法推断（跨模块/接口）+ 上游（Room/MVI reducer 等）对未变数据每次发新实例 + 类小而平、无集合、`equals` O(1)。
- 移除既有注解的 scope guard：仅当模型喂给 Lazy 布局（LazyColumn/Grid/Pager 等）**且**数据量大/嵌套深时建议移除；其余既有注解一律不动、不批量 grep 标记。
- `ImmutableList` 解包双重 O(N) 陷阱：父比较 data class equals 遍历列表一次，子再收 `ImmutableList` 参数又比一次。标准 `List` 解包传参反而是 O(1)。
- 逃生舱须一行注释说明理由：`@DontMemoize`（只标 lambda 表达式处，故意每次新捕获）、`@NonSkippableComposable`（纯副作用 composable，如调试 overlay）、`@NonRestartableComposable`（几乎不用）。
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
- item 内禁止：`list.indexOf(item)`（用 `itemsIndexed`）；逐项查 `CompositionLocal`（父级解析后下传）；`LaunchedEffect(Unit)` 曝光埋点（预组合导致提前/虚假曝光，用 `Modifier.onVisibilityChanged` + 停留阈值）；逐项 `collectAsStateWithLifecycle()`（共享流父级收集一次传值）。
- 选中态跟踪用 `mutableStateOf(set)`/`mutableStateSetOf`（O(1) 查询），叶子传 `isSelected: () -> Boolean` lambda provider 隔离重组；`SnapshotStateList` 反复查询先 `.toList()`/`.toSet()`。
- painter/`BorderStroke`/shape 等重建项提出 items lambda；**Modifier 链已被结构化驻留**，`remember { Modifier... }` 是微优化，无 FrameTimingMetric 证据禁止加。
- 小而有界集合（约 ≤10 项）用 `Row/Column` + `forEach`，免掉懒加载虚拟化开销；scope guard：key/contentType 规则只适用于 Lazy 容器，别标记普通 Column 遍历。
- prefetch：默认优先；Foundation 1.10+ 预取组合默认可暂停（重 item 不再爆帧预算）。仅测量证明仍掉帧才配 `LazyLayoutCacheWindow(ahead, behind)`（1.9+ 实验性；走 `rememberLazyListState(cacheWindow = ...)`，不是 LazyColumn 参数；Dp 单位；宽窗口=内存+反向浪费）。内嵌 lazy（LazyColumn 行内 HorizontalPager）实现 `NestedPrefetchScope` 链式预热。

## 副作用与 Flow

- 决策树：要协程 → `LaunchedEffect(keys)`；非协程订阅要拆装 → `DisposableEffect(key) { onDispose {} }`；同步跟 key 反应 → 别起协程作用域（同步轻量场景 `SideEffect`，1.12+ 支持 `SideEffect(keys)`）；一次性初始化 → `remember {}` 而非 `LaunchedEffect(Unit)`。
- 长寿命 `LaunchedEffect` 消费外部回调必须 `rememberUpdatedState` 包装，否则协程持有旧引用。
- 禁止：非挂起操作写进 `LaunchedEffect`（日志/同步赋值）；空 `onDispose {}` 的 `DisposableEffect` 当占位；动画/滚动中高频换 key 重启 effect（协程取消有成本）。
- 多个 `LaunchedEffect(Unit)` 合并为一个 + 嵌套 `launch`，减少 effect 节点与协程启动；可选回调先 `if (callback != null)` 守卫再启动。
- Flow 收集：外部流（VM/仓库/传感器）一律 `collectAsStateWithLifecycle()`（默认 STARTED；焦点专属控件 RESUMED；禁 CREATED）；内存内轻量 StateFlow 可 `collectAsState`。高频流（>~10ms/次）加 `.conflate().distinctUntilChanged()` 且操作链包 `remember(key)`。
- 派生状态决策（1.13+）：简单条件/过滤（`scrollState.value > 0`）用 `computedStateOf`（失效路径显著更快）；重计算多次读取用 `derivedStateOf`；平凡取反/属性查值用普通 `get()`。`derivedStateOf` 必须 `remember {}` 包裹，捕获的非 state 值全部做 key，**禁止**把 `state.value` 传成 key（等于每次变更重建、彻底废掉过滤）；输入频率 ≈ 输出频率时两者都不用。同步派生禁 `produceState + snapshotFlow`（白付协程与 flow 派发）；fire-and-forget 副作用（埋点/日志）用 `LaunchedEffect { snapshotFlow {}.distinctUntilChanged().collect {} }`。
- 整表替换场景用 `mutableStateOf(mutableListOf(), neverEqualPolicy())` + 载荷赋值（`state.value = list`），比 `mutableStateListOf` 逐元素跟踪便宜。

## 布局与子组合

- `BoxWithConstraints`/`SubcomposeLayout` 禁止：只为读 `maxWidth`（改 `Modifier.onSizeChanged`/`layout {}`）；放进 Lazy item（每 item 一次测量期子组合，提升到列表父级判断后传 Boolean 下传）；`Scaffold` 嵌 `Scaffold`（用现成槽位）。
- 合法保留（子内容组合真依赖测量值）时：`SubcomposeLayoutState(SubcomposeSlotReusePolicy(n))` 复用槽位；可预测槽位提前 `state.precompose(slotId, content)`；measurePolicy 内不要每次测量新建组合 lambda（AndroidX 内部 lint 同款反模式）。
- 坐标类：避免 `onGloballyPositioned`（用 `onPlaced`/`onLayoutRectChanged`/`Modifier.Node` 内按需 `requireLayoutCoordinates()`）；浮层锚定（tooltip/角标）用 custom `Layout` 同时测量放置双方，禁止坐标存 `MutableState` 再 `offset`（一帧滞后 + 二次组合）。
- 减树深：去掉装饰性 `Box`/`Canvas` wrapper，修饰直接挂 modifier 或 `drawBehind`；intrinsic 测量链别深嵌。

## 动画与图形

- 动画属性（alpha/scale/rotation/translation/color）一律 `graphicsLayer {}`；尺寸过渡用 `Modifier.animateContentSize` / `animateBounds`；`Lazy` item 的 `sharedElement`/`sharedBounds` 挂在可见性指示（`onVisibilityChanged`）之后，避免预取项实例化过渡作用域。
- `Animatable` 作为 `Modifier.Node` 的持久成员，`onAttach()` 里 `coroutineScope.launch` 启动。
- 绘制：装饰性 `Canvas` 换 `Modifier.drawWithCache`（缓存 Path/Paint/Brush）；热绘制循环 `Path.rewind()` 优于 `reset()`；网络图用 Coil `AsyncImage`（`Image`+bitmap 不缓存）；泛型元组/集合用 `androidx.collection`（`MutableLongSet`）与 `packInts`；`RuntimeShader`/`ShaderBrush` 在 composition `remember`，尺寸 uniform 进 `drawWithCache`，逐帧 uniform 进 `onDrawBehind`。

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

| 能力 | 最低版本 |
| --- | --- |
| Strong Skipping 默认开 | Kotlin 2.0.20+ |
| `stabilityConfigurationFiles` DSL | Compose Compiler 1.5.5+ |
| `Modifier.animateItem()` GA | Compose UI 1.7+ |
| `LazyLayoutCacheWindow` | Foundation 1.9+ |
| 预取组合可暂停（默认） | Foundation 1.10+ |
| `SideEffect(keys)` | Compose 1.12+ |
| `computedStateOf` | Compose 1.13+ |
| Baseline Profile Generator 模板 | AGP 8.2+ |
