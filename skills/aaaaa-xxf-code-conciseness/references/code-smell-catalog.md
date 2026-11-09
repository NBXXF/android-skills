# 坏味道审查目录（Kotlin/Android）

> 本目录供审查存量代码或大范围重构时使用：先通读目标代码，再按六族逐一过检。每条命中记录 文件:行号 + 严重级别，先呈现完整 findings 清单，经确认再动手改。severity 定义：**Blocker**（不改无法安全继续）/ **Major**（本轮必须处理）/ **Minor**（顺手改或另开任务）。

## 族 1：膨胀（Bloat）

### 长函数 Long Method

- 症状：逻辑超 ~20 行（不计空行注释）；嵌套 >3 层；多个 return/throw 路径各干各的；函数体内出现"第一步/第二步"式注释；一个动词短语概括不了它干什么。
- 检测：数函数体行数；找 `// --- xxx ---` 分段注释；一个函数里 5 个以上局部变量通常是多职责。
- 级别：>50 行 Blocker；20–50 行 Major；15–20 行 Minor。
- 修复：按职责提取函数（名字要说清"做什么"而不是"怎么做"）；条件复杂先做 Decompose Conditional（提取谓词函数）。

### God Object / 大类

- 症状：类超 200–300 行；7 个以上公共方法服务不同目的；字段只被部分方法使用（人格分裂——按字段分组能分成 2 组以上就是 2 个类）；类名带 Manager/Handler/Service/Util/Helper。
- 检测：数公共方法；把字段按"被哪些方法使用"分组。
- 级别：>500 行或明确多职责 Blocker；200–500 行 Major。
- 修复：Extract Class（按职责拆）；Move Method（把方法搬到它真正使用的字段旁边）。

### 长参数列表

- 症状：参数 >4 个；含 boolean 旗标参数；同一组参数在多个调用点总是结伴出现。
- 检测：Grep 函数签名中 4+ 个逗号；Grep `Boolean` 参数。
- 级别：>4 参数或含 boolean 旗标 Major；3–4 个非旗标 Minor。
- 修复：Introduce Parameter Object（含 Data Clumps 一起收）；Remove Flag Argument（拆命名函数或枚举）；Kotlin 用默认参数 + 命名参数。

### Data Clumps 数据泥团

- 症状：同样 3+ 个变量/字段总是一起穿过多个函数或类（如 `userId, userName, userEmail` 结伴）；拿掉一个另外的就失去意义。
- 检测：看调用点上重复出现的同组变量名。
- 级别：Major。
- 修复：提取参数对象/数据类。

### 基本类型偏执 Primitive Obsession

- 症状：裸 `String`/`Int` 承载领域概念（ID、金额、手机号、状态码、类型标记）；`if (type == "premium")` 式类型检查；并行 List 代替对象列表（两个下标对应的 list）。
- 检测：Grep `"premium"`、`status == "1"`、`type.equals(` 等字面量比对；Grep `List<String>` + 下标访问。
- 级别：业务逻辑依赖它 Major。
- 修复：`value class` 包装领域值（构造即校验）；`enum class`/`sealed class` 替换类型标记；并行列表合并为对象列表。

## 族 2：面向对象滥用

### 类型判断分发 Switch on Type

- 症状：`when`/if-else 链检查类型标记（type/kind/role 字符串或枚举）；同一判断模式出现在多处；新增一个"类型"要改所有 switch。
- 检测：Grep `when (.*type)`、`is Xxx ->` 集中出现的文件；数同一枚举的 when 出现位置。
- 级别：同一 switch 出现 >2 处 Major；孤立出现 Minor。
- 修复：Replace Conditional with Polymorphism（把行为移进 sealed 子类型）；判断必须留在调用方时，用 when 表达式 + 无 else 穷尽。

### 临时字段 Temporary Field

- 症状：实例字段只在一个方法里赋值，其他路径下是 null/未初始化；注释写"仅在批量模式下有效"。
- 级别：Minor。
- 修复：Extract Class（字段和用它的一组方法一起搬走）；或 sealed 状态建模替代"部分有效"的对象。

### 拒绝的遗产 Refused Bequest

- 症状：子类 override 方法只为 `TODO()`/空实现；子类只用父类一小部分；为复用代码而继承而非 is-a。
- 级别：Major。
- 修复：组合替代继承（`by` 委托）；接口提取到正确的粒度。

### 同类异名 Alternative Classes

- 症状：两个类干同一件事但方法名不同（`fetchUser` vs `getUser`、`UserLoader` vs `UserFetcher`）；改名就能互换。
- 级别：Minor。
- 修复：统一命名合并为一个；确实都保留时明确接口区分语义。

## 族 3：变更阻碍（Change Preventers）

### 发散式变化 Divergent Change

- 症状：一个类因多种不同原因被改（auth 变了改它、UI 变了改它、数据模型变了还改它）；`git log --oneline <file>` 的提交信息横跨不相关主题。
- 级别：Major。
- 修复：Extract Class 按变更原因拆分。

### 霰弹式修改 Shotgun Surgery

- 症状：一个概念变更要改一堆文件（"加个字段"动 8 个文件）；改动碎小散落。
- 检测：问"改 X 会牵连什么"，Grep 数受影响文件数。
- 级别：Major。
- 修复：把和概念相关的逻辑搬进同一个类/模块（Move Method）；相关常量/映射收敛到唯一属主。

### 平行继承体系

- 症状：每加一个 A 的子类就得加一个 B 的子类；两个继承体系镜像；类名共享前缀（`PremiumOrder`/`PremiumInvoice`、`StandardOrder`/`StandardInvoice`）。
- 级别：Major。
- 修复：把一个体系的数据/行为并入另一个（字段持引用替代双轨继承）。

## 族 4：可有可无（Dispensables）

### WHAT 注释复述代码

- 症状：注释翻译代码（`// i 加一` 在 `i++` 上方）；注释掉的代码块留在原地。
- 检测：Grep `^[[:space:]]*//.*[;{}()]`（形似代码的注释）。
- 级别：Minor（但提示命名/结构不清的深层问题）。
- 修复：改名让意图自明；提取函数用名字承载意图；注释掉的代码直接删（git 里有历史）。WHY 注释（非显然约束、已知问题绕行、隐性不变量）保留。

### 重复代码

- 症状：近似块只差变量名/字面量；复制粘贴微调；同一算法两处实现；工具函数每文件各抄一份。
- 检测：拿一处 distinctive 子表达式 Grep 全局。
- 级别：承载逻辑 Major；琐碎 Minor。注意 Rule of Three：第 3 次出现才提取。
- 修复：提取共享函数；参数化差异点；搬进已有属主而不是另建近重复。

### 惰性类 / 死代码

- 症状：只有 1–2 个琐碎方法的类；零调用的函数；import 了但没用；永远开/关的特性开关。
- 检测：Grep 符号名确认零调用点；IDE 灰色提示交叉验证。
- 级别：Minor（制造虚假复杂度时 Major）。
- 修复：删除；不确定的列清单问用户，不静默删。

### 投机泛化 Speculative Generality

- 症状：只有一个具体实现的抽象基类；"将来用"的参数实际总是传 null/默认值；零调用者的 hook/回调/扩展点；第二个用例出现前就搭好的"通用"基建。
- 级别：Minor。
- 修复：折叠继承层级；删参数；删未用扩展点；需要时再加回。

## 族 5：耦合（Couplers）

### 特性依恋 Feature Envy

- 症状：方法访问另一个对象的数据/方法多过自己的；拿到对象立刻伸进字段替它干活。
- 检测：函数体内 `otherObj.` 出现密度远高于 `this.`/自身字段。
- 级别：Major。
- 修复：Move Method（函数搬进它依恋的对象）；注意例外——跨层搬运破坏封装时不搬。

### 不当亲密 Inappropriate Intimacy

- 症状：两个类互访对方 private/internal 状态；双向依赖；A 把 `this` 传给 B 让 B 回调 A 的内部。
- 级别：Major。
- 修复：Move Method/Field；Extract Class 收拢共同状态；Hide Delegate（不暴露内部对象）。

### 消息链 Message Chains

- 症状：`a.getB().getC().doThing()` 一路点到底（迪米特法则）；链中间一变，所有调用点跟着变。
- 检测：一行内 3+ 个 `().` 连续调用（区分 Kotlin 安全调用 `?.` 链——数据访问链可接受，跨对象行为链才是问题）。
- 级别：多处出现 Major；孤立 Minor。
- 修复：Hide Delegate（在被访对象上加一个语义方法）；提取函数给链条命名。

### 中间人 Middle Man

- 症状：类只做委托，每个方法只是调用另一对象的同名方法；包装层不加行为、不加翻译、不加保护。
- 级别：Minor。
- 修复：内联掉中间人，调用方直接用目标对象。跨模块防腐层/二进制兼容包装除外。

## 族 6：架构越界（Android 语境）

> 命中本族时不先做代码级重构：先回到 `aaaaa-xxf-coding-arch` / `aaaaa-xxf-multi-module-structure` 确认目标分层，修复方向影响公共 API 时按 `aaaaa-xxf-clarify-question` 先问用户。本族只输出 findings。

### 胖 Activity/Fragment/Controller

- 症状：超过 ~50 行还含业务规则（价格、资格、折扣的 if 链）；为完成一个动作串调 4+ 个服务；直接发通知/起任务/做计算。
- 检测：`grep -n "discount\|eligibility\|calculate\|if.*status\|if.*role"` 在 ui 包下命中即疑似。
- 级别：>50 行含领域逻辑 Major；业务规则在多个页面重复 Blocker。
- 修复：下沉 ViewModel/UseCase/领域层。

### UI 含业务逻辑

- 症状：View/Activity/Fragment/Compose 组件计算派生状态（合计、过滤、格式化）；事件处理含领域校验；组件直连 Repository/DAO。
- 检测：`grep -rn "calculate\|validate\|discount\|\.filter {\|\.map {"` 在 ui/ 下；ui 包 import repository/dao。
- 级别：Major。
- 修复：派生计算进 ViewModel/remember推导链；校验进领域层。

### 贫血领域模型

- 症状：领域对象只有字段和 getter/setter 零行为；所有逻辑在 `*Service`/`*Manager`/`*Helper` 里以领域对象为参数；同一条领域规则在多个 Service 重复实现；非法状态可被表示（对象自己管不住不变量）。
- 检测：领域包里只有 data class 无方法；Service 里 `fun validate\|fun calculate\|fun compute` 密集。
- 级别：规则重复 Major；简单少规则模型 Minor。
- 修复：把规则推进类型（`init { require }`、工厂函数只产出合法实例）。

### 分层越界

- 症状：UI 直接 import data/repository/db 包跳过领域层；领域对象 import Repository/HTTP 客户端；依赖箭头与模块分层设计相反。
- 检测：`grep -rn "import.*repository\|import.*dao" ui/`；`grep -rn "import.*retrofit\|import.*http" domain/`。
- 级别：Major。
- 修复：见 coding-arch 的依赖方向规则，先修方向再做其他重构。

### 散落数据访问

- 症状：同一实体的查询出现在 ui/service/presenter 多处，没有唯一属主；同一份数据 5+ 文件各自取用各取所需投影；换数据源要动一堆文件。
- 检测：`grep -rn "FROM\|\.query(\|api\." --include="*.kt"` 看访问点分布。
- 级别：Major。
- 修复：收敛 Repository/唯一数据门面。

### 弱类型跨界透传

- 症状：JSON `String`、`Map<String, Any>`、`Bundle` 从网络层一路穿透到 UI 层；层与层之间靠字符串 key 约定。
- 检测：`grep -rn "Map<String, Any>\|getJSONObject\|Bundle" ui/ domain/`。
- 级别：Major。
- 修复：边界一次性解析成 DTO/VO/Result（衔接 `aaaaa-xxf-network-request-rule`、`aaaaa-xxf-class-declaration-guidelines`）。

## Kotlin/Android 常用检测 Grep 速查

> 模式兼容 macOS BSD grep（`-E` 下用 `[[:space:]]` 代替 `\s`）；空 catch 常跨行，grep 只做初筛，最终以阅读确认。

```bash
# boolean 旗标参数
grep -n "fun .*(.*: Boolean" <file>
# 魔法字符串类型比对
grep -nE '(type|status|kind|action|state) *(==|\.equals\()' <file>
# 类型判断 when（多态分发候选）
grep -n "when (" <file>
# !! 强解包
grep -n '!!' <file>
# 嵌套 let（逐个看是否连写）
grep -n '?\.let' <file>
# 注释掉的代码
grep -nE '^[[:space:]]*//.*[;{}()]' <file>
# 空 catch（单行形态；跨行的靠阅读）
grep -nE 'catch \([a-zA-Z]+\)[[:space:]]*\{[[:space:]]*\}' <file>
# 可变集合暴露
grep -nE "(val|var) .*(MutableList|MutableMap|MutableSet)" <file>
```

## 结构修复手段速查

发现结构问题时提出"改法"，不只报"问题"：

| 问题 | 命名修复 |
|---|---|
| 条件链判断类型 | 换成类型化模型（enum/sealed/value class）或显式分发器 |
| 重复分支 | 合并成单一清晰流程 |
| 编排混业务 | 拆开，各自独立可读 |
| 共享模块混入业务特有逻辑 | 搬进拥有该概念的包/层 |
| 近重复造轮子 | 复用既有唯一实现 |
| 弱类型边界 | 显式建模类型，让下游分支消失 |
| 纯转发包装 | 删掉间接层 |
| 大文件/大类 | 提取 helper/子组件/子模块 |

优先选择**减少活动部件**的修复，而不是把同样复杂度摊开的修复。
