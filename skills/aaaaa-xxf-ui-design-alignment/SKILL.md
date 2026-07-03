---
name: aaaaa-xxf-ui-design-alignment
description: xxf_android 的 Android UI 设计稿对齐规范，侧重 Jetpack Compose 布局。用于根据 Figma、Figama、MasterGo、蓝湖、摹客或截图实现/修复 Compose 页面 UI 时，要求像素级视觉对齐、不同窗口尺寸适配、动态内容适配、Lazy 列表/瀑布流/网格适配、字体缩放、WindowInsets 安全区、图片比例、空/错/加载态和截图复核。
---

# UI 设计稿对齐

## 核心目标

实现 Compose UI 时同时满足两件事：默认机型上尽量贴近设计稿像素效果，多窗口尺寸和动态内容下不崩、不挤、不遮挡、不写死。不要为了单张截图对齐而牺牲真实设备适配。

## 先取设计真值

1. 明确设计来源：Figma/Figama、MasterGo、蓝湖、摹客、截图或产品口述。
2. 记录设计稿基准画板宽高、关键节点尺寸、间距、字号、颜色、圆角、阴影、图片比例、状态栏/导航栏处理。
3. 有设计工具数据时，以节点坐标、尺寸、文本、颜色、资源为准；不要凭视觉大概估。
4. 只有截图或口述时，先声明哪些值是推断值，并优先使用现有项目样式、dimens、主题 token 和邻近页面规范。
5. 存在 Figma/MasterGo 工具能力时，优先获取节点截图或 DSL/metadata，并在实现后用运行截图对照。

## 像素对齐规则

- 以设计稿基准宽度换算 Android `dp`，不要直接把设计稿 px 当成代码常量；确认设计稿是否是 1x、2x、3x 或 Android dp 画板。
- 关键视觉锚点必须对齐：页面左右边距、顶部起点、卡片宽高、头像/封面比例、按钮高度、分割线、图标尺寸、文本 baseline、列表 item 间距。
- 颜色、字号、圆角、间距优先复用资源：Compose theme、typography、spacing token、`colors.xml`、`dimens.xml` 或项目既有 modifier/组件参数；不要在多个 composable 中散落魔法数字。
- 图标和矢量资源用设计稿导出的真实资源；不要手画近似路径。位图资源按密度放置，避免运行时拉伸发糊。
- 允许 1dp 级别的 Android 渲染差异；超过这个范围要么修正，要么在最终说明里解释原因。

## 不要写死

- 不要写死屏幕宽高、状态栏高度、导航栏高度、刘海高度、列表数量、文案长度、图片真实尺寸或接口返回顺序。
- 不要用 `screenWidth - 37`、固定 `offset` 堆坐标、固定 item 总数来模拟设计稿。
- 不要让列表 item 依赖父页面某个固定高度；列表应能处理 0/1/少量/大量数据。
- 不要把服务端文案、用户名、价格、标签、按钮文案当成固定长度；长文本必须有换行、截断或自适应策略。
- 不要为了某个机型截图好看而破坏小屏、横屏、折叠屏、平板或字体放大后的布局。

## 多机型适配

- 优先使用 `Modifier.fillMaxWidth`、`weight`、`widthIn/heightIn`、`requiredSize`、`aspectRatio`、`BoxWithConstraints`、adaptive grid、window size class 和 `WindowInsets` 表达布局关系。
- 小屏至少检查 320dp/360dp 宽；主流机型检查 390dp/411dp 宽；有横屏、平板、折叠屏入口时检查更宽断点。
- 页面容器要处理系统 inset：状态栏、导航栏、沉浸式、刘海、水滴屏、手势导航、软键盘；Compose 中优先用 `Modifier.windowInsetsPadding`、`statusBarsPadding`、`navigationBarsPadding`、`imePadding` 或项目既有 inset 封装。
- 字号用 `sp`，但紧凑控件要验证 font scale 1.15/1.3；重要按钮、`TextField` 和输入框不能因为字体放大而文字被裁。
- 图片区域用明确比例或约束，不用只在一个设备上看起来刚好的固定高度；头像、封面、banner、瀑布流图片要明确 `ContentScale` 和裁剪策略。
- 深色模式、多语言、RTL 不是默认必做，但改动触及通用组件或公开库时要确认是否已有要求。

## 需要按需读取的 references

- 做 Compose 页面、复杂列表、弹窗、横屏/平板/折叠屏、多窗口、键盘、RTL、深色模式或无障碍适配时，读取 `references/compose-adaptation-scenarios.md`。
- 实现文本、图片、按钮、标签、输入框、卡片、Lazy item 等会受内容影响的组件时，读取 `references/compose-dynamic-layout-decisions.md`。

## Compose 动态布局原则

实现任何文本、图片或内容卡片时，先判断组件尺寸来自哪里：设计稿固定值、父容器约束、内容自然尺寸、窗口尺寸、服务端数据或图片真实比例。不要只按当前样例文案和当前截图写一个固定宽高。

- 组合外层优先接收父级约束并向内传递：用 `Modifier.fillMaxWidth`、`widthIn/heightIn`、`wrapContentHeight`、`aspectRatio`、`weight` 和 padding 表达关系，避免到处读取屏幕宽度后手算。
- `Row` 中的动态文本要明确压缩顺序：固定图标/按钮先占位，文本用 `weight`、`maxLines`、`overflow` 或 `widthIn` 承接剩余空间；不要让长文本把右侧按钮、价格、角标挤出屏幕。
- `Column` 中的动态内容要允许父容器增高、滚动或折叠；不要用固定高度裁掉多行文本、错误提示、输入框 helper text 或状态区。
- `Text` 必须明确 `maxLines`、`overflow`、`softWrap`、`lineHeight` 和对齐方式；长文、富文本、emoji、数字、价格、日期要用最长合理样例验证。
- 图片用 `Modifier.aspectRatio`、稳定占位和明确 `ContentScale`；远程图不能依赖原图比例刚好符合设计稿。
- Lazy 列表 item 要按内容独立自适配，使用稳定 key，避免 item 高度变化导致状态错乱、滚动跳动或重组成本失控。

## 列表和动态内容

- Lazy item 必须按内容独立自适配，不依赖屏幕上固定出现几个 item。
- `LazyVerticalGrid`、瀑布流、横滑列表要根据可用宽度、最小 item 宽度和设计间距计算列数/跨度；不要固定只适配一个设备。
- 使用稳定 key、项目既有分页/局部刷新方案和稳定状态持有方式，避免为了 UI 对齐牺牲列表性能或造成状态串位。
- 覆盖加载态、空态、错误态、骨架屏、分页尾部、无更多、刷新中、图片加载失败、权限缺失等状态。
- item 文案、标签、角标、按钮、头像、封面缺失时要有占位或隐藏策略，不能留下错位空洞。

## 实现优先级

1. 先复用项目已有 Compose 组件、theme、typography、spacing token、颜色和图片加载封装。
2. 再新增局部 composable、modifier 或资源，命名跟随邻近模块。
3. 最后才新增自定义 Layout、`SubcomposeLayout` 或复杂测量逻辑；新增时必须考虑测量次数、重组成本、主线程开销和生命周期。
4. 优先用 `Row`、`Column`、`Box`、`Lazy*`、`FlowRow`、`ConstraintLayout` 和 modifier 表达静态结构；运行时只计算真正依赖 constraints、数据或 inset 的值。
5. 复杂页面先对齐布局骨架，再补资源、动效和状态，不要一开始堆 magic number。

## 复核清单

实现后至少做以下检查，并在最终说明里报告结果或阻塞原因：

- 设计稿基准尺寸和目标机型宽度是否明确。
- 默认机型截图与设计稿关键间距、尺寸、颜色、字号是否对齐。
- 小屏、主流屏、字体放大下是否无重叠、无遮挡、无裁字。
- 文本组件是否明确单行/多行/截断/换行/动态高度策略，外层容器是否能承接宽高变化。
- 图片组件是否明确比例、占位、失败态、裁剪和远程图片极端尺寸策略。
- 横屏、分屏、多窗口、平板、折叠屏或更宽窗口下是否有合理布局，不依赖设备型号硬判断。
- 本地化、RTL、资源限定符、深色模式和默认资源兜底是否在触及范围内处理或说明不适用。
- 交互态、禁用态、选中态、弹窗/浮层、键盘弹起、返回恢复后是否保持布局稳定。
- 列表 0/1/多条、长文案、缺图、加载失败、分页态是否可用。
- 状态栏、导航栏、软键盘、沉浸式区域是否正确处理。
- UI 资源或 Compose 代码改动是否执行对应模块 `assembleDebug` 或更窄可行验证。
- 触及 Lazy 列表、图片、自定义 Layout/绘制、动画时，同时按 `aaaaa-xxf-android-performance-gate` 做性能门禁。

## 输出要求

最终回复要说明：对齐了哪些设计要点、哪些尺寸/资源没有写死、验证过哪些机型或状态、是否有设计稿缺失或 Android 渲染导致的残余偏差。
