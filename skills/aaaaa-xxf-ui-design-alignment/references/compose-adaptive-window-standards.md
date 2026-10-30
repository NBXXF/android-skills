# Compose 自适应窗口标准（官方口径）

## 读取时机

任务涉及以下任一情形时读取本文件：按窗口宽度做布局分支（断点）、平板/横屏/折叠屏/多窗口/分屏适配、导航容器选型（NavigationBar/Rail/Drawer）、canonical layouts（列表-详情、支撑面板、feed 网格）、edge-to-edge 与系统栏强制行为、大屏质量清单、manifest 适配属性（resizeableActivity/minAspectRatio/screenOrientation）、构造多窗口验证矩阵。组件内部动态内容（文字/图片压缩、叠层）仍按 `compose-adaptation-scenarios.md` 与 `compose-dynamic-layout-decisions.md` 执行。

## 核心原则

- 按"窗口"决策，不按"设备"决策：禁止用 `isTablet`、设备型号、物理宽高比、Build 配置做布局分支；窗口等级随旋转、分屏、折叠、自由窗口实时变化，布局必须响应等级切换而不是静态假定。
- 宽度优先：布局分支先看宽度等级；只有"宽 medium + 高 compact"（横屏手机、半开翻盖）等高度受限场景才参考高度等级，此时不适合双栏。
- 窗口等级只在 app/content 层单点获取，以参数/状态向下传递；可复用组件内部用自身收到的 constraints 决策，不反向读全局窗口等级。
- 数据加载与窗口尺寸解耦：数据按全窗口全量提供，禁止把"加载数据"当成窗口尺寸变化的副作用。
- 官方方向是彻底自适应：不依赖 manifest 限制属性保布局（见"manifest 与大屏质量"）。

## Window Size Classes 官方断点

| 维度 | Compact | Medium | Expanded | Large | Extra-large |
| --- | --- | --- | --- | --- | --- |
| 宽度 | < 600dp | 600–839dp | 840–1199dp | 1200–1599dp | ≥ 1600dp |
| 高度 | < 480dp | 480–899dp | ≥ 900dp | — | — |

- Large/XL 面向平板横屏、桌面与外接显示器；启用需 material3-adaptive 1.2+ 传 `supportLargeAndXLargeWidth = true`（V2 API 默认包含）。
- 断点数值是官方稳定口径，不要自造 500dp/700dp 之类私有断点；组件确需额外阈值（如内容列数）时写在组件内部并注明业务依据，不与 WSC 混用命名。

### 获取与判定（按项目依赖降级）

```kotlin
// 首选：material3-adaptive ≥ 1.3
val wsc = currentWindowAdaptiveInfoV2().windowSizeClass // 旧版本用 currentWindowAdaptiveInfo()

when {
    wsc.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND) -> { /* 双栏/网格 */ }
    wsc.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND) -> { /* rail + 单栏 */ }
    else -> { /* 底部导航 + 单栏 */ }
}
```

- 依赖分代：material3-adaptive ≥ 1.3 用 `currentWindowAdaptiveInfoV2()`（自 1.3.0-alpha10 起 `currentWindowAdaptiveInfo()` 已弃用，存量项目仍可用）；只引了旧 `material3-window-size-class` 时用 `calculateWindowSizeClass(activity)`；两者都没有时用 `BoxWithConstraints` + `androidx.window:window-core` 的 `WindowSizeClass.compute(widthDp, heightDp)`。
- 判定一律用 `isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_*_LOWER_BOUND)` 常量，不要手写 `600.dp` 数值比较。
- 禁止用 `Configuration.screenWidthDp/screenHeightDp` 做布局计算：targetSdk 35+ 它们不再排除系统栏，数值比窗口可用区偏大；`sw<N>dp` 资源限定符目录不受此影响。

## 断点布局决策树

### 导航容器

- 默认规则（`NavigationSuiteScaffold` 官方行为）：宽度或高度为 compact、或 tabletop 姿态 → NavigationBar；medium/expanded → NavigationRail；feed 类单栏应用在 expanded 可通过 `layoutType` 自定义为 NavigationDrawer。
- 手写降级（未引 adaptive-navigation-suite 时）：compact → `NavigationBar`，medium → `NavigationRail`，expanded → Rail 或 Drawer 按信息密度选。

### 内容布局（canonical layouts）

- 列表-详情（list-detail）：expanded 双栏并排；medium/compact 单栏互切。单栏切双栏时保留当前详情内容；列表态展开时详情栏先显示占位。
- 支撑面板（supporting pane）：expanded 主栏约 70% + 支撑栏 30%；medium 各 50%；compact 把支撑内容移到主内容下方或 BottomSheet，不并排。
- feed：网格用 `GridCells.Adaptive(minSize = 180.dp)`（官方示例值，可按最小卡片宽调整），compact 自动退化为单列；瀑布流用 `StaggeredGridCells.Adaptive`。
- expanded 下主内容区不无限拉伸：用 `widthIn(max = ...)` + 居中承接；全宽列表/网格/feed 不受限。

### 次级元素最大宽度

- BottomSheet、Dialog、按钮、输入框、小型编辑菜单不得在宽屏全宽拉伸（大屏质量 LS-U2）；用最大宽度 + 居中。

## material3-adaptive 落地

- 坐标：`androidx.compose.material3.adaptive:adaptive-layout` / `adaptive-navigation` / `adaptive-navigation3`；旧坐标 `androidx.compose.material3:material3-adaptive` 停更于 1.0.0-alpha06，禁止新引用。`NavigationSuiteScaffold` 在另一条版本线：`androidx.compose.material3:material3-adaptive-navigation-suite`。版本与引入按 `aaaaa-xxf-gradle-dependencies` 治理。
- 多栏实现首选分代：项目用 Navigation 3 时**必须**用 `SceneStrategy` 方案，官方明确不要再用 `ListDetailPaneScaffold`/`SupportingPaneScaffold`；项目未用 Nav3 时才用后者。

### 首选：Navigation 3 SceneStrategy

```kotlin
val strategy = rememberListDetailSceneStrategy<NavKey>() // 依赖 adaptive-navigation3
NavDisplay(backStack = backStack, sceneStrategies = listOf(strategy)) { /* entries */ }
// entry metadata 标角色：
// entry(metadata = ListDetailSceneStrategy.listPane(detailPlaceholder = { Placeholder() }))
// entry(metadata = ListDetailSceneStrategy.detailPane()) / .extraPane()（超宽第三栏）
```

- 角色用 `entry(metadata = ...)` 标注：`listPane(detailPlaceholder = {...})` 永远可见，宽屏未选中时显示占位；`detailPane()` 次栏；`extraPane()` 超宽第三栏。pane 间导航就是 backStack 增删，策略观察 back stack 自动切布局。
- 配套状态保存：`rememberNavBackStack(...)`（key 必须 `@Serializable` 且实现 `NavKey`）；`NavDisplay` 必须装配 `rememberSaveableStateHolderNavEntryDecorator()`（+ 按需 `rememberViewModelStoreNavEntryDecorator()`），漏配是自适应切换丢 pane 状态的典型根因。
- 需 `@OptIn(ExperimentalMaterial3AdaptiveApi::class)`；去掉 pane 间默认分隔条：`calculatePaneScaffoldDirective(currentWindowAdaptiveInfoV2()).copy(horizontalPartitionSpacerSize = 0.dp)` 传给 strategy。
- 细节规则：detail 在手机上的全屏模式进入双栏后必须解除；双栏布局下 detail 不显示返回箭头。

### 降级：ListDetailPaneScaffold / SupportingPaneScaffold（非 Nav3 项目）

```kotlin
val navigator = rememberListDetailPaneScaffoldNavigator<ItemId>()
ListDetailPaneScaffold(
    directive = navigator.scaffoldDirective,
    value = navigator.scaffoldValue,
    listPane = { AnimatedPane { ListContent(onItemClick = { id -> navigator.navigateToDetail(id) }) } },
    detailPane = { AnimatedPane { DetailContent() } },
)
```

- 项目未引 adaptive 库且不便新增时再手写单双栏互切：同一份数据 + 选中状态驱动两套布局（compact 单栏导航跳转、expanded 双栏选中），不要复制成两个独立页面导致状态双份。

### NavigationSuiteScaffold 细则

- 导航区显隐：`rememberNavigationSuiteScaffoldState()` 传入 `state` 参数，`LaunchedEffect(isVisible)` 里调 `state.show()/hide()`；不要用外层 `AnimatedVisibility` 包裹。
- insets 陷阱：`NavigationSuiteScaffold` / `ListDetailPaneScaffold` 自管 safe area 但**不**向内容传播 `PaddingValues`，内部每个 screen 要单独处理 insets；禁止对其父级加 `safeDrawingPadding`（会裁剪、破坏 edge-to-edge）。

## 折叠屏与铰链

- 基础库 `androidx.window`（stable 1.5+）：`WindowInfoTracker.getOrCreate(context).windowLayoutInfo(activity)` Flow → `displayFeatures` 中的 `FoldingFeature`。
- 姿态判定首选 `mediaQuery { windowPosture == UiMediaScope.Posture.Tabletop }`（Compose ≥ 1.11，见"布局原语选型"节；官方不推荐直接读 `windowPosture.isTabletop`）；旧版本可用 material3-adaptive `collectFoldingFeaturesAsState()` 或 `currentWindowAdaptiveInfoV2().windowPosture`。
- `FoldingFeature` 关键属性：`state`（FLAT / HALF_OPENED）、`orientation`（HORIZONTAL / VERTICAL）、`occlusionType`（NONE / FULL）、`isSeparating`、`bounds`。HALF_OPENED 恒有 `isSeparating = true`。
- 姿态定义：tabletop = HALF_OPENED + HORIZONTAL（上半屏内容、下半屏控制区）；book = HALF_OPENED + VERTICAL（左右双页）。
- 典型 tabletop 场景（出现即考虑分栏）：媒体/音频播放与直播、视频通话、相机拍摄、图片编辑、音频混音、菜谱、演示文稿。
- tabletop 布局规则：铰链 `bounds` 必须从 window 坐标换算到本地坐标（`onGloballyPositioned` + `coordinates.windowToLocal`），**禁止假设 50/50 对半分屏**；内容区约束在铰链上方（`maxHeight ≤ hingeTop`），控制区约束在铰链下方（起点 `y = hingeBottom`）。
- 实现二选一：内容/控件两姿态不同（需要不同组件）→ `mediaQuery` 条件分支两套布局；内容/控件相同仅位置变 → `Grid` 双配置（defaultConfig 全部 `row = 1, column = 1` 叠放、tabletopConfig 上下分栏，声明顺序即 z 序，控制区后声明渲染在上）。
- 关键交互控件、输入框、弹窗、底部栏不得跨 `isSeparating` 区域或铰链 `bounds`；折痕遮挡只允许影响纯装饰内容。
- 降级：未接入 window/adaptive 库时不做折叠特化，但布局必须"不因折痕崩坏"——内容可滚动、无依赖屏幕中线的绝对定位装饰、双栏布局在任意折叠态可用。
- 测试模拟：`androidx.window:window-testing` 的 `WindowLayoutInfoPublisherRule` + `createFoldingFeature(state = HALF_OPENED, orientation = ...)` 注入铰链。

## Edge-to-edge 与系统栏（target 35+ 强制）

- targetSdk 35 起 edge-to-edge 强制执行：手势导航条透明、内容绘制到系统栏之后；`setStatusBarColor`、`setNavigationBarColor`（手势导航）、`setDecorFitsSystemWindows`、`statusBarContrastEnforced` 等已弃用失效。
- `windowOptOutEdgeToEdgeEnforcement` 在 targetSdk 36 + Android 16 设备上已被禁用；禁止依赖 opt-out 过渡。
- 标准做法三件套：targetSdk ≥ 35；`ComponentActivity.onCreate()` 中 `setContent` 前调用 `enableEdgeToEdge()`（androidx.activity）；使用软键盘的 Activity 在 Manifest 声明 `android:windowSoftInputMode="adjustResize"`（禁止用已废弃的 `SOFT_INPUT_ADJUST_RESIZE` flag）。
- insets 处理只选一种方案，避免双重 padding：
    1. `Scaffold` + 把 `innerPadding` 传给内容（列表用 `contentPadding = innerPadding` + `Modifier.consumeWindowInsets(innerPadding)` 承接）。
    2. 依赖 M3 组件自带 safe area（TopAppBar 全家族、BottomAppBar、NavigationBar/NavigationRail、ModalDrawerSheet、ModalBottomSheet 自动处理）。
    3. Scaffold 之外的容器用 `Modifier.safeDrawingPadding()` / `windowInsetsPadding(WindowInsets.safeDrawing)`。
    4. 深层嵌套或 IME 场景用 `Modifier.fitInside(WindowInsetsRulers.Ime.current)` / `fitInside(WindowInsetsRulers.SafeDrawing.current)`（较新 API；不可用时 `imePadding()` 降级，且必须放在 `verticalScroll()` 之前）。
- 双重 padding 高频反例：`Scaffold(contentWindowInsets = WindowInsets.safeDrawing)` 已处理 IME 时再加 `imePadding()`；外层 `padding(WindowInsets.safeDrawing.asPaddingValues())`（不 consume）+ 内层 `imePadding()`。
- insets 只能进 `LazyColumn/LazyRow` 的 `contentPadding`，禁止作为 `Modifier.padding()` 加在列表父容器（裁内容、无法滚进系统栏后面）。
- Material 2 组件手动传 `windowInsets` 参数（如 `TopAppBar(windowInsets = AppBarDefaults.topAppBarWindowInsets)`），禁止对父容器加 padding 代替。
- 底部栏（`BottomAppBar`/`NavigationBar`）在 SDK 29+ 设 `window.isNavigationBarContrastEnforced = false`，防系统加半透明底色；全屏 Dialog（`usePlatformDefaultWidth = false` + `fillMaxSize`）需 `decorFitsSystemWindows = false` 才能 edge-to-edge。
- 可点击元素必须避开手势热区与系统栏。
- splash 崩溃坑：target35 + 旧 splashscreen 主题会因 cutoutMode 处理崩溃；升 `androidx.core:core-splashscreen` ≥ 1.2.0 或显式 `layoutInDisplayCutoutMode = ALWAYS`。

## manifest 与大屏质量

- 官方方向是彻底自适应：targetSdk 36 起，sw ≥ 600dp 屏幕会忽略 `screenOrientation`、`resizeableActivity`、`minAspectRatio`、`maxAspectRatio`、`setRequestedOrientation()`。禁止把"竖屏锁定/宽高比限制"当适配方案；项目已有这些配置时保留不删，但必须注明其在新型号上失效，布局本身要自适应。
- `resizeableActivity="false"` 自 Android 12 起就无法在 sw≥600dp 屏阻止多窗口，不要指望它。
- 大屏质量底线（Tier 3）：内容填充全部可用窗口（无 letterbox/兼容模式）；旋转、折叠开合、窗口 resize 后保持状态——滚动位置、输入内容、选中态、播放进度；多窗口与分屏全功能。
- Tier 2 要点：按 WSC 自适应布局（导航 rail、网格伸缩、双栏/canonical layouts）；次级元素最大宽度（LS-U2）；触控目标 ≥ 48dp。

## 状态保持（配置变更与自适应切换）

- **禁止**通过 Manifest 加 `android:configChanges` 或 `android:screenOrientation` 抑制 Activity 重建来"修"状态丢失——这会掩盖状态丢失 bug、破坏自适应资源重载；正确做法是把状态补成可保存。
- 系统排查所有 `remember` 用法：用户输入与交互态（草稿、搜索词、开关）用 `rememberSaveable { mutableStateOf(...) }`，必要时按 id 加 key（`rememberSaveable(conversationId)`）。
- 委托 `MutableState<T>` 保存自定义类型时传 `stateSaver = ...`（不是 `saver =`）；或类标 `@Serializable` 用 `rememberSerializable`。
- 滚动状态经典陷阱：`remember { LazyListState() }` 绕过 Saver，配置变更后丢滚动位置；必须换工厂函数 `rememberLazyListState()` / `rememberLazyGridState()` / `rememberLazyStaggeredGridState()` / `rememberScrollState()`。
- 媒体播放（ExoPlayer/Media3）：位置与 playWhenReady 存 `rememberSaveable`，在 `Player.Listener` 回调 + `LaunchedEffect` 轮询中持续更新（不能只在 onDispose 存）；恢复时 `seekTo` 后再 `prepare()`；`LifecycleStartEffect` 只在原状态为播放时才 `play()`。
- 验证口径：旋转、折叠开合、窗口 resize 后检查滚动位置、输入、选中态、播放进度（LS-C1/C2），不能只截默认态。

## 布局原语选型（含 Compose 1.11 新原语）

- 选型表：

| 原语 | 用途 |
| --- | --- |
| `Row` / `Column` / `FlexBox` | 一维排列 |
| `Grid` | 二维结构布局（屏幕骨架、复杂组件），按容器尺寸换行列数 |
| `LazyVerticalGrid` / `LazyStaggeredGrid` / `LazyHorizontalGrid` | 大量同构数据集可视化（需懒加载） |
| `FlowRow` / `FlowColumn` | 换行排列的旧方案；Compose ≥ 1.11 用 `FlexBox` 替代 |

- 改"显示什么"（换布局结构、换内容形态）才用 WSC（app 层）或 `BoxWithConstraints`（组件层）；改"在哪/怎么显示"（尺寸、padding、列数、对齐）用 modifier 与自适应容器表达，不引入 `BoxWithConstraints`。它会把 composition 推迟到 layout 阶段（官方明示成本）；组件内部小阈值分支参考官方口径 `maxWidth < 400.dp` 量级。

### Grid（1.11 引入实验，1.13 起 stable）

- 版本分代：Compose 1.11–1.12 为实验性（需 `@OptIn(ExperimentalGridApi::class)` 且征得用户同意）；**1.13 起转 stable**，按项目实际依赖版本选择口径。
- 非懒加载；用于屏内区域/卡片矩阵等**结构性**二维布局，不要拿来展示大数据集，也不要嵌在原 `Column` 里，直接整体替换。
- 轨道在 `config` lambda 里定义（可读 `constraints`）：`column(160.dp)` 固定、`column(0.5f)` 百分比、`row(1.fr)` 份额、`GridTrackSize.Auto` / `MinMax(100.dp, 1.fr)` / `MinContent` / `MaxContent`；`repeat(n) { ... }`、`gap(8.dp)`。
- item 用 `Modifier.gridItem(row = , column = , rowSpan = , columnSpan = , alignment = )`；支持负数从末尾计数；声明顺序即 z 序（后声明渲染在上）。

```kotlin
Grid(config = {
    val w = constraints.maxWidth.toDp()
    val (cols, rows) = if (w < 800.dp) 2 to 4 else 4 to 2
    repeat(cols) { column(((w - 8.dp * (cols - 1)) / cols).coerceAtLeast(0.dp)) }
    repeat(rows) { row(GridTrackSize.Auto) }
    gap(8.dp)
}) { /* items */ }
```

- 1.11–1.12 需 `@OptIn(ExperimentalGridApi::class)` 且征得用户同意；降级路径：非懒二维布局用 `Row`/`Column` 组合 + WSC 分支。

### FlexBox（1.11 引入实验，1.13 起 stable）

- CSS flexbox 语义，一维排列中需要换行、伸缩、按比例分配空间时使用；官方口径：需要 wrap 的场景用 `FlexBox` 替代 `FlowRow`/`FlowColumn`；不支持懒加载；整体屏幕骨架优先 `Grid`。
- 容器：`FlexBox(config = { direction(FlexDirection.Row); wrap(FlexWrap.Wrap); justifyContent(FlexJustifyContent.Center); alignItems(FlexAlignItems.Center); gap(16.dp) })`。
- item：`Modifier.flex { basis(FlexBasis.Auto /* 或 dp / 0.7f */); grow(1f); shrink(0.5f); alignSelf(...); order(...) }`——`grow`/`shrink` 是 weight 的声明式替代，压缩顺序在此显式表达。
- 1.11–1.12 为实验性需征得用户同意，1.13 起 stable；降级路径：`FlowRow`/`FlowColumn` + `weight`。

### mediaQuery 设备能力查询（Compose ≥ 1.11，实验性）

- 需在 `Application.onCreate()` 设 `ComposeUiFlags.isMediaQueryIntegrationEnabled = true`；`mediaQuery { ... }` 返回 Boolean，`windowWidth`/`windowHeight` 等高频变化参数用 `derivedMediaQuery { ... }`（内部 derivedStateOf，避免多余重组）。
- 可查询维度：`windowWidth/windowHeight`（断点比较用 `windowWidth < WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND.dp`）、`windowPosture`（Tabletop/Book/Flat）、`pointerPrecision`（Fine/Coarse/Blunt/None）、`keyboardKind`（Physical/Virtual/None）、`hasCamera`/`hasMicrophone`、`viewingDistance`（Near/Medium/Far）。
- 适配语义：指针精度低（Coarse/Blunt）→ 用更大触控目标按钮；`viewingDistance` 远 → 增大字号；无物理键盘 → 提示连接或适配软键盘流。
- 预览：`CompositionLocalProvider(LocalUiMediaScope provides 自定义 UiMediaScope)` 覆盖后预览特定姿态；降级路径：窗口尺寸用 WSC，姿态用 `collectFoldingFeaturesAsState()`。

## 适配验证矩阵（AI 执行口径）

验证至少覆盖：compact 手机（320/360/411dp 宽 + 旋转）、medium（600dp 级）、expanded（841dp 级折叠展开/平板）、超大（1280×800、1600×900 平板/桌面）、折叠姿态（tabletop/book）、字号放大（触及通用组件时含 200% 最大字号，Android 14+ 官方测试口径）。

- 官方测试窗口基准：折叠 841×701dp、8″ 平板 1024×640dp、10.5″ 平板 1280×800dp、13″ Chromebook 1600×900dp。
- adb 模拟与截图：

```bash
adb shell wm size 841x701        # 恢复: adb shell wm size reset
adb shell wm density 420         # 恢复: adb shell wm density reset
adb shell settings put system font_scale 2.0  # 无 reset 子命令，测完必须设回 1.0
adb exec-out screencap -p > shot.png          # 用 exec-out，避免 shell 管道破坏 PNG
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml
```

- 模拟器：优先用 Device Manager 的 Resizable (Experimental) 镜像拖拽模拟折叠/展开/旋转，不必逐个建折叠屏 AVD。
- 仪器测试模拟：铰链用 `WindowLayoutInfoPublisherRule`；字号用 `DeviceConfigurationOverride(FontScale(2f))`；屏幕规格用 Robolectric `@Config(qualifiers = "w841dp-h701dp")`。
- 形态档预览：自定义 multi-preview 注解批量覆盖 `@Preview(device = Devices.PHONE/FOLDABLE/TABLET/DESKTOP)`，配合 `@PreviewTest` 即一条形态档截图用例。
- 截图测试纪律：跑验证任务对比基准图，**禁止未经用户查看 diff 就自动更新/重录基准图**；确定性前提是固定 state、冻结时钟与动画、网络图用 fake 加载器、动态文本受控。AGP 9.5+ testsuites 新模型任务名 `update{Suite}{Target}{Variant}TestSuite` / `test{Suite}{Target}{Variant}TestSuite`（旧插件模型 `updateDebugScreenshotTest` / `validateDebugScreenshotTest` 仍常见，按项目 AGP 选）。
- 验证必须包含状态保持：旋转/折叠/resize 后检查滚动位置、输入、选中态、播放进度是否保留，不能只截默认态。
- 截图核对按"部位级"检查（关键交界逐项确认），口径见 `compose-adaptation-scenarios.md` 防坑节。

## 澄清触发

- 设计稿只给了 compact 构图、实现需要 medium/expanded 布局时：列出延伸策略（内容拉伸 + max width、双栏 canonical、网格加密、rail + 内容区）及各自代价，让开发者选择并按 `aaaaa-xxf-clarify-question` 记录；不要替业务发明大屏构图。
- 折叠屏特化（tabletop 上下分区、book 双页）属于超出设计稿的新增交互，须先澄清是否在需求内。
- 项目既有 manifest 限制属性与新系统行为冲突时，报告冲突并让开发者决策，不要静默删除或静默保留。

## 禁止事项

- 禁止用设备型号、`isTablet`、物理宽高比做布局分支。
- 禁止自造断点数值或手写 dp 与官方断点比较。
- 禁止把 `Configuration.screenWidthDp` 用于布局计算（target35+ 含系统栏）。
- 禁止新引用旧坐标 `androidx.compose.material3:material3-adaptive`；用 Nav3 的项目禁止新写 `ListDetailPaneScaffold`/`SupportingPaneScaffold`。
- 禁止依赖 `windowOptOutEdgeToEdgeEnforcement` 或 manifest 限制属性保布局。
- 禁止用 `android:configChanges`/`android:screenOrientation` 抑制重建来掩盖状态丢失。
- 禁止把 insets 以 `Modifier.padding()` 加在 Lazy 列表父容器，或对 `NavigationSuiteScaffold` 父级加 `safeDrawingPadding`。
- 禁止把关键交互元素跨铰链/`isSeparating` 区域摆放，或假设折叠屏 50/50 对半分屏。
- 禁止在用户查看 diff 前自动更新截图基准图；实验性 API（Grid/FlexBox/mediaQuery）未经用户同意不得引入。
