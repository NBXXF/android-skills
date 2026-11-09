---
name: aaaaa-xxf-code-conciseness
description: Android 项目 Kotlin 代码精炼、逻辑清晰、易读、上手快、职责清晰与设计规范门禁。新增或修改 Kotlin 代码时必须遵守：有限且确定的取值优先建模为枚举/sealed/value class 而非字符串比对，同变量多分支优先 when 表达式；禁防御性冗余、提前抽象、死代码、复制粘贴重复；空安全用类型系统，禁 !! 与嵌套 let；API 禁 boolean 陷阱与超长参数；认知负担守 Miller 阈值（参数≤5/分支≤5/嵌套≤3）、平铺优于嵌套、一概念一名；结构守一句话职责测试、深模块、按知识分组、状态唯一属主、一致性优先与统一布局。发现既有魔法字符串比对、if-else 链、超长函数、深嵌套、God Object、弱类型透传时主动重构。写 Kotlin 惯用法对照 references/kotlin-idioms.md；审查既有代码按 references/code-smell-catalog.md 六族过检；可读性深入读 references/readability-cognition.md；结构与职责深入读 references/structure-responsibility.md；交付前必须过自检清单。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# 代码精炼与可读性门禁

## 核心原则

- 精炼的目标是**理解速度快**，不是行数少。一行嵌套 if-else 表达式链不比五行平铺 if 简单。
- **概念计数测试**：重构是否真的减少复杂度，数读者必须同时持有的概念数量。把逻辑从 A 挪到 B、读者要记的东西没变少，是"迁移复杂度"不是"减少复杂度"；优先选让整个分支、模式或层次消失的改法，而不是把同样逻辑换个地方集中。
- 1000 行实现 100 行就能做完的功能是失败，不是"完整"。
- 每次交付用同一个测试度量：新接手的同事读这版代码，会不会比读改之前更快看懂？答案是否定的就回退。
- 优先遵循当前文件风格与 `aaaaa-xxf-coding-style`；本 skill 管"精炼、逻辑清晰、易读、上手快、职责清晰、设计规范"六个维度。

## 分支建模（强制）

### when 优先于 if-else 链

- 同一变量/同一对象的 3 个及以上分支判断，必须用 `when`，禁止 if-else 链。
- `when` 优先写成**表达式**（有返回值），让编译器强制穷尽；enum/sealed 作 subject 时不写 `else`，新增枚举值时编译报错，而不是静默落进 else 分支埋 bug。
- 条件互不相关的多级判断用 guard clause 早返回拉平，禁止箭头型嵌套。
- 禁止把新条件嫁接到无关流程上（在既有 if 链上再塞一个特殊分支）；同形条件（对同一形状数据的重复判断）出现在 2 处以上，说明缺一个模型或分发器，提取而不是复制。
- 多态分发优先于类型判断：对同一 sealed/继承层级的 `when` 判断逻辑散落在多个文件时，考虑把行为移进类型本身。

```kotlin
// 禁止：同变量 if-else 链 + 魔法字符串
if (type == "video") { showPlayer() }
else if (type == "image") { showGallery() }
else if (type == "text") { showText() }
else { showError() }

// 正确：枚举 subject + when 表达式，穷尽由编译器保证
val renderer = when (content.type) {
    ContentType.VIDEO -> ::showPlayer
    ContentType.IMAGE -> ::showGallery
    ContentType.TEXT  -> ::showText
} // 无 else：ContentType 新增取值时这里编译失败，强制补分支
```

### 枚举优先于字符串比对

- 取值**有限、确定、可穷举**的集合必须建模为 `enum class`；取值需要携带异构数据或状态用 `sealed class`/`sealed interface`。
- 禁止魔法字符串散落比对：`status == "1"`、`type.equals("xxx")`、`if (action == "click_download")` 这类字面量判断不允许出现在业务分支逻辑里。
- 字符串只允许出现在**边界**（网络协议、JSON 解析、持久化、deeplink/路由参数）。边界处一次性映射成枚举，映射收敛在该枚举的 companion（`fromValue`/`@JsonValue`），内部全程用枚举传播；DTO 边界转换规则见 `aaaaa-xxf-network-request-rule`。
- 例外：取值真正开放、由服务端任意下发且无法穷举的（如动态配置 key、资源名），不得强行枚举，保持字符串但集中定义常量。

```kotlin
// 禁止：字符串比对满天飞
fun label(state: String) = when {
    state == "loading" -> "加载中"
    state == "success" -> "完成"
    else -> "失败"
}

// 正确：边界一次映射，内部枚举传播
enum class LoadState { LOADING, SUCCESS, FAILED;
    companion object {
        // 返回 nullable，未知值交给调用方显式处理；
        // 不要 `?: FAILED` 沉默兜底——那是下面"数据建模"禁止的非法状态掩盖
        fun fromValue(v: String): LoadState? =
            entries.firstOrNull { it.name.equals(v, true) }
    }
}
```

## 数据建模（强制）

- 基本类型偏执（Primitive Obsession）：领域概念（ID、金额、手机号、邮箱、坐标）禁止用裸 `String`/`Int` 传播；用 `value class` 包装，零运行时开销且构造处即校验。
- 主要承载数据的类型用 `data class`，享受 `copy`/`equals`/`destructuring`；修改用 `copy(...)` 产出新值，不在可变字段上原地改。
- `Pair`/`Triple` 禁止跨函数、跨层传播：`first`/`second` 没有语义，出函数签名就必须换成命名字段的结构。
- `Map<String, Any>`、`Bundle` 当业务载体持续透传是弱类型信号，在边界转换成明确对象；见 `aaaaa-xxf-class-declaration-guidelines`。
- 禁止沉默兜底掩盖非法状态：`parse(v) ?: DEFAULT` 把脏数据静默替换成默认值会掩盖 bug；解析失败要么显式进入失败分支（sealed 状态），要么 `require`/抛出，让问题暴露在边界。
- 同一组 3 个以上参数总是一起出现（Data Clumps），提取成参数对象/数据类。

```kotlin
// 禁止：裸 String ID 无校验到处传
fun loadUser(id: String) { ... }

// 正确：构造即校验，类型即文档
@JvmInline value class UserId(val value: String) {
    init { require(value.isNotBlank()) { "UserId 不能为空" } }
}
fun loadUser(id: UserId) { ... }
```

## 空安全与不可变（强制）

- 禁止 `!!`；平台类型（Java 返回值）在接收处立即显式标注可空性，不往深处传。
- 嵌套 `let` 链改安全调用链：`a?.let { it.b?.let { ... } }` → `a?.b?.c?.let { ... }`。
- nullable 是类型信号不是状态：能保证非空的用非空类型 + `require`，需要延迟初始化的用 `by lazy`/`lateinit` 并注明初始化时机，不要一路 `?` 到底。
- `val` 与只读集合（`List`/`Map`）为默认；`var` 与 `MutableList` 只在确有原地变更需求时用，且不暴露到公共 API。
- 预期内的失败不用异常做控制流：可失败的领域操作返回 `Result<T>` 或自定义 sealed 状态，`null` 表示"没有"而不是"出错"。

## 结构纪律

- 一个函数一个职责、一个抽象层级；编排逻辑和底层细节混在一个函数里是"乱"的主要来源。
- 函数超过 50 行、嵌套超过 3 层即触发拆分评估；函数体内出现"第一步/第二步"式注释是拆分信号。
- 类超过 200–300 行且公共方法服务多个不同目的、或字段只被部分方法使用（人格分裂），是 God Object 信号，按职责拆类；名字带 Manager/Handler 而说不清单一职责的同罪。
- 单文件超过 1000 行是检查信号：继续加代码前先考虑拆 helper/子组件/子模块，而不是往大文件上堆。
- 重复逻辑出现第 3 次才提取（Rule of Three）；出现 2 次容忍，不为"将来复用"提前抽象。

## 结构与职责清晰

目标：每个类/函数/文件一眼看得出"负责什么"，职责边界清晰、放代码的位置可预测。深入规则与依据读 `references/structure-responsibility.md`。

- **一句话职责测试**：能否用一个动词短语说清这个类/函数的唯一职责？句子出现"和/还有"即多职责，拆；起名卡壳或名字不带信息量（`DataProcessor`），先怀疑切分边界错了再怀疑词汇量。
- **深模块**：接口窄、功能深；调用方必须按序调用本模块多个方法才能完成一件事 = 太浅，把编排拉进模块。模块能自己定合理默认值时，不加配置参数把决策推给调用方。
- **按知识分组，不按执行顺序分组**：调用方必须按特定顺序调一组方法才正确是隐式时序耦合（时序分解反模式）——把"知道某件事"的所有代码归一个类型，顺序由编排层显式表达；同一决策（格式/协议）只允许一个模块知道。
- **相邻层不同抽象**：两层接口高度相似 = 分解错了；连体方法（必须成对读才懂）合并或把隐式契约显式化成类型。
- **长度从不是拆分理由**：共享信息、简化接口、消除重复才是；拆出来的每片仍要"做一件事且做完整"。
- **状态唯一属主**：每份可变状态只有一个属主、一个修改入口；同一事实存两份必然漂移；UI 状态集中建模为 UiState/sealed，不散落多个可变流；构造注入 7+ 依赖即职责扩散信号。
- **一致性优先**：同类场景（重试/缓存/错误映射/线程切换）全库用同一种既有写法；"更好的想法"不是引入第二种风格的理由，全局改进单独开重构任务；新代码落位前先看邻居怎么写。
- **文件内布局统一**：成员排序模板（属性 → init → override 生命周期 → 公共 API → 私有 helper → companion）；空行分组（一段空行一个想法）；相似结构相似排版。
- **Design it twice**：非平凡类型/API/重构实现前用几句话对比两个根本不同的方案（接口简洁度/实现复杂度/变更承受力），与 `aaaaa-xxf-agent-high-quality-operation` 的方案先行要求衔接。

## 防御性冗余禁令

- 非空类型再判空、`!!` 之后又 `?.`、`checkNotNull` 之后继续 `?:`，一律删除。
- 前面已经 `check`/`require`/早返回保证过的条件，后续分支不允许再判一遍。
- 禁止空 catch 块和 `catch (e: Exception) {}` 式吞异常；异常处理要么恢复、要么转换上抛、要么记录后明确终止，见日志规范。
- 防御只加在**真正的边界**（外部输入、反序列化、反射、跨进程/跨模块回调、三方 SDK 返回值）；内部信任边界内对自家 API 的重复防御是噪音，不是健壮性。

## 禁止提前抽象

- 单实现的接口、只有一个策略的策略模式、只有一个产品的工厂，直接写实现。
- 纯转发的 Middle Man 类/方法（只调用另一个对象的同名方法，不加行为、不加翻译、不加保护）内联掉。
- 只有一处使用的泛型参数、配置项、回调参数、"为将来预留"的扩展点，删除（Speculative Generality）。
- 单次使用的单行包装函数、纯转发属性/方法，内联。
- 不保留"将来可能有用"的投机抽象；需要时再加，YAGNI。

## 表达力

- 手写循环优先换标准库：`map`/`filter`/`firstOrNull`/`associateBy`/`groupBy`/`partition`/`sumOf`。链式调用嵌套超过 3 层时拆出带名字的中间变量，可读性优先。
- 简单函数用表达式体：`fun isEmpty(): Boolean = list.none()`。
- 字符串拼接用模板 `"${user.name}"`；条件赋值用 `?:`、`takeIf`/`takeUnless`。
- scope 函数只在提升可读性时用；嵌套 `let`、`?.let{}.let{}` 连写禁止。
- Java 风格残留（显式 getter/setter、匿名内部类、Java 式单例、index 循环遍历集合）按 `references/kotlin-idioms.md` 的对照表改写成惯用 Kotlin。
- 禁止 `if (x) return true else return false`，直接 `return x`。
- 注释只能解释"为什么"；注释在复述代码"做什么"时，删注释改代码，而不是留双份。注释门禁见 `aaaaa-xxf-comment-guidelines`。

## API 设计

- Boolean 陷阱参数禁止：`load(showLoading: Boolean, cache: Boolean)` 的调用点 `load(true, false)` 不可读；拆成命名函数（`loadWithCache()`）或枚举/参数对象。
- 参数阈值统一口径：**≥4 个触发参数对象评估，5 为硬上限**（data class 构造豁免）；Kotlin 用默认参数 + 命名参数替代重载爆炸，不加 Java 式重载链。
- 多方法回调接口改 lambda/suspend/Flow：单方法 `(data) -> Unit`；两个以上回调事件用 sealed 事件流或拆分接口，不堆 `interface Listener { fun onA(); fun onB(); fun onC() }`。
- 扩展函数 vs 成员函数：类型不属于本模块（三方/框架类型）用扩展；本模块类型用成员；成员函数只用到另一个对象的数据（Feature Envy）时把函数搬过去。
- 可见性最小化：默认 `private`，跨模块才 `public`；`internal` 用于模块内共享。公共 API 上的可变状态、`var`、`MutableList` 暴露禁止。
- 常量：文件内私有常量用顶层 `private const val`，与类强相关的放 companion `const val`；魔法数字（超时、重试次数、尺寸阈值）必须命名。

## 命名

- 名字长度与作用域成正比：局部变量可以短，跨模块 API 必须完整描述行为。
- 禁止 `Util`/`Utils`/`Helper`/`Manager` 垃圾桶后缀；有明确职责按职责命名（`DateFormatter`、`DownloadScheduler`），纯函数集合用顶层扩展函数 + `Ext` 后缀文件。
- 布尔命名 `isXxx`/`hasXxx`/`shouldXxx`；领域模型命名细则见 `aaaaa-xxf-model-naming-guidelines`。

## 认知负担与上手速度

目标：新接手的人以最小认知负担看懂并安全改出第一行代码。深入规则与依据读 `references/readability-cognition.md`。

- **Miller 认知阈值**：函数参数 ≤5、单函数分支 ≤5、嵌套 ≤3、单函数逻辑行 ~15 为理想（50 行是拆分评估上限）；连续布尔条件 ≤3 个操作数。超阈值先拆，确实拆不动（如长 when 映射表）要能讲清理由。
- **平铺优于嵌套（认知复杂度口径）**：嵌套结构里的判断按深度计分——第 3 层里一个 if ≈ 顶层三个 if；guard clause 拉平永远比嵌套便宜。
- **阅读流**：文件自上而下从高层到细节（报纸隐喻）；编排函数读作大纲，每行一个意图，实现细节在下一层；变量声明就近；同文件同模式同写法。
- **一概念一名**：同一领域概念全库唯一名字（user/account/member 不许混指一物），改名只发生在 DTO/层边界转换处；引入新概念先 Grep 既有词汇复用；反向同样成立——一个名字不许指两个概念。
- **可搜索命名**：跨行出现的变量必须全名可 grep；名字携带消歧属性（`retryDelayMs`、`cacheSizeBytes`、`userId`）；禁止与外层作用域遮蔽。
- **最小惊讶**：名字带 `get` 不许有副作用，`load` 不许悄悄写穿缓存；行为超出名字范围时改名或拆函数。
- **作用域与变量最小化**：一次性中间变量内联；能局部不成员、能 private 不 public；不留半成品状态跨段流转。
- 交付前做一次新读者模拟：只读 diff ±30 行能否说清这段代码做什么、有没有哪行需要停顿反推（停顿处即重构点）。

## 改动范围纪律

- 只精炼本次 diff 触达的代码。不顺手重构无关代码——drive-by 重构污染 diff、制造回归风险；无关问题记录后另行处理。
- 删除既有"绕弯"代码前先弄清它为什么存在（查 git blame）：性能热点、平台兼容 workaround、三方 SDK 行为兜底都长得像坏代码。看不懂原因的不删（Chesterton's Fence）。
- 死代码删除前先 Grep 确认零调用点并列出清单（函数/类/常量/import/特性开关），不确定的先问再删，不静默删。
- 重构提交与功能/修复提交分开，不混在一个 diff 里。

## 过度简化的反例

- 为减行数把两个不相关函数合并成一个带 boolean 参数的函数——不是简化。
- 内联掉有概念名字的 helper，让调用点重新变难读。
- 以"更干净"为由删掉错误处理或降级逻辑——这是破坏行为，不是简化。
- 一行塞多个副作用（`a = b = c`、`also { }` 里做业务）。
- 把 Feature Envy 误当简化信号：函数访问别的对象的数据不一定要搬，跨层数据搬运破坏封装时反而不动。

## 审查既有代码

分两档执行：

- **快速审查**（默认，随每次 diff）：只过本文件的自检清单 + `references/code-smell-catalog.md` 的 grep 速查段。
- **深度审查**（用户明说"审查/重构这个模块"时）：`code-smell-catalog.md` 六族坏味道（膨胀 / OO 滥用 / 变更阻碍 / 可有可无 / 耦合 / 架构越界）逐一过检；可读性专项（认知阈值、词汇一致性、阅读流）按 `references/readability-cognition.md`；结构职责专项（职责测试、深模块、信息隐藏、状态属主、布局）按 `references/structure-responsibility.md`。

输出按 Blocker/Major/Minor 分级、带文件行号的 findings，先呈现清单经确认再动手改。

## 工具化验证

本 skill 的阈值与 detekt 默认口径对齐（LongMethod 60、函数参数 5、嵌套 4、ComplexCondition 3、每类方法 11；本 skill 的阈值均不宽于 detekt）。项目配置了 detekt/ktlint 时，精炼类交付按 `aaaaa-xxf-auto-test-orchestrator` 一并跑静态检查，机器报出的违例优先于人工豁免；未配置的项目按人工口径执行，不得以"没配工具"为由跳过清单。

## 交付自检清单

交付前逐项核对，任何一项不满足必须回到对应章节修正：

- [ ] 同一变量的 3+ 分支判断全部是 `when` 表达式，enum/sealed subject 无 `else`
- [ ] 业务分支逻辑里没有魔法字符串/数字比对，取值有限的数据已建模为枚举或 sealed
- [ ] 领域概念没有裸 `String`/`Int` 传播；`Pair`/`Triple`/`Map<String,Any>` 没有跨层透传；没有沉默兜底掩盖非法状态
- [ ] 没有 `!!`、嵌套 `let`、异常控制流；`val` + 只读集合为默认
- [ ] 没有非空重判、重复防御、空 catch、死代码、未用 import 和未用变量
- [ ] 没有单实现接口、纯转发 Middle Man、投机抽象；重复 ≥3 次的逻辑已提取，<3 次的保留原样
- [ ] 没有 boolean 陷阱参数；参数 ≥4 的已评估参数对象；没有 Java 风格残留
- [ ] 函数 ≤50 行、嵌套 ≤3 层、单一职责单一抽象层级；手写循环已换标准库且链式未超 3 层
- [ ] 认知阈值达标：参数 ≤5、分支 ≤5、连续布尔 ≤3；嵌套已用 guard clause 拉平
- [ ] 每个改动触达的类/函数过一句话职责测试；无时序耦合（无需按序调用才正确）；状态属主唯一
- [ ] 同类场景写法与邻居一致（重试/缓存/错误映射/线程切换无第二种风格）；成员排序与空行分组符合布局模板
- [ ] 新引入的概念名全库唯一（一概念一名），与既有词汇无同义冲突；跨行变量可 grep、带单位/类型消歧属性；无无信息量名字（data/info/temp）与匈牙利残留
- [ ] 编排函数读作大纲（每行一个意图）；名字与行为严格一致（无最小惊讶违例）
- [ ] 新代码通读一遍即可理解，无需"停顿反推"的密集表达式

## 与其他 skill 的边界

- `aaaaa-xxf-coding-style`：通用编码规范与日志白名单；本 skill 只管精炼、逻辑清晰、易读、上手快、职责清晰这五个代码质量维度。
- `aaaaa-xxf-code-reviewer`：回归风险审查；审查中发现的可读性/精炼类 findings 按本 skill 判定和修复。
- `aaaaa-xxf-class-declaration-guidelines`、`aaaaa-xxf-coding-arch`、`aaaaa-xxf-multi-module-structure`：类型声明、模块分层与依赖方向；本 skill 的架构越界 findings 归它们收口。
- `aaaaa-xxf-comment-guidelines`：注释补齐要求；本 skill 只约束"删掉复述代码的注释"。
- `aaaaa-xxf-model-naming-guidelines`：领域模型命名；本 skill 的命名节只管"名字长度与作用域、垃圾桶后缀"。
- `aaaaa-xxf-flow-guide`：KPower Flow/协程操作符选型；本 skill 只管协程与 Flow 链路的精炼形态（冗余 withContext、嵌套作用域）。
- `aaaaa-xxf-android-performance-gate`：性能与重组；本 skill 只管 Compose 代码的可读性（modifier 重复、嵌套容器、参数爆炸），性能口径以它为准。
- 内置 `/simplify`：写完后的批量清理；本 skill 是写时约束，两者叠加使用。
