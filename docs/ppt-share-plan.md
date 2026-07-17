# Vibe Coding 分享 PPT 策划稿

## 1. 分享定位

### Why

这次分享要解决一个核心问题：同事们已经知道 AI 能写代码，但还不一定知道怎么让 AI 在真实项目里稳定、可控、可复用地交付。

### How

整场分享统一使用 `Why / How / What` 结构：

- **Why**：为什么需要这个概念、流程或 Skill
- **How**：应该怎么落地，具体流程是什么
- **What**：最终产物、规则、命令或 Demo 是什么

### What

推荐标题：

**Vibe Coding 不是让 AI 乱写代码，而是把工程闭环自动化**

备选标题：

- **从 Prompt 到 Skill：团队级 Vibe Coding 实战**
- **AI 辅助 Android 开发：需求、计划、编码、测试、Review、风险闭环**
- **把团队经验写进 AI：Vibe Coding 的正确打开方式**

一句话主旨：

> Vibe Coding 的核心不是“用自然语言让 AI 写代码”，而是通过 **Prompt + Skill + Context + Quality Gate + 工程闭环**，让 AI 在团队工程规范内稳定交付。

---

## 2. 分享主线

### Why

如果没有流程约束，AI 写代码越快，项目里的架构漂移、风格不统一、测试缺口和发布风险也可能放大得越快。

### How

用四个层次展开：

1. **认知篇**：Vibe Coding 是什么，不是什么
2. **计划篇**：为什么先计划，再编码
3. **技能篇**：为什么需要 Skill，把经验沉淀成可执行规则
4. **实战篇**：结合 `android-skills` 和业务项目 Skill Demo 展示团队级落地

### What

整场分享围绕一句话：

> **AI 写代码的能力已经足够强，真正的问题是：我们怎样让它按团队的工程标准工作？**

### 讲师视角 Review 结论

#### Why

这份文档是完整素材版，不是最终逐字照讲版。站在分享者角度，需要区分“准备材料要完整”和“现场讲述要克制”。

#### How

当前结构建议这样取舍：

- **顺序是合理的**：先认知，再计划，再 Skill，再共享 Skill 地图，最后进入业务项目 Demo 和团队落地。
- **第 15 页已改为全量地图**：共享 Skill 实际有 21 个，但现场不应逐个展开，只讲分类和主链路。
- **分类需要按听众理解来分**：不要按文件名排序，要按工程链路分成交付总控、语言风格、架构模块、UI 质量、测试验证、Review 风险、发布混淆、趣味 Demo。
- **讲解和 Demo 要区分**：讲解页序先讲 `delivery-loop` 主入口，再用陪聊 Skill 做行为演示；现场 Demo 执行时可以先用陪聊 Skill 热场，再进入工程 Skill。
- **命令页适合作为附录或实操前置**：如果现场要跑命令，就把命令页提前；如果只是方法论分享，就放在后半段作为备查。

#### What

正式分享建议控制成：

| 版本 | 页数 | 适合场景 |
|:---|:---|:---|
| 30-32 页素材版 | 全部保留 | 自己备课、后续生成完整 PPT |
| 24-26 页主讲版 | 删掉部分命令页和清单页 | 45-60 分钟团队分享 |
| 15-18 页精简版 | 只保留观点、Skill 地图和 1-2 个 Demo | 30 分钟短分享 |

讲师取舍原则：

> **现场重点讲主线和 Demo，不要把每个 Skill 都讲成文档说明。**

---

## 3. PPT 页纲

### 第 1 页：标题页

#### Why

先把分享定位从“AI 很酷”拉回到“真实工程怎么落地”。

#### How

标题直接表达观点，副标题说明范围：

- 主标题：**Vibe Coding 不是让 AI 乱写代码，而是把工程闭环自动化**
- 副标题：从 Prompt 到 Skill 的团队级 AI 编程实践

#### What

本页要让听众记住：这不是工具安利，而是工程流程分享。

---

### 第 2 页：先给结论

#### Why

很多人使用 AI 编程的痛点不是不会问，而是每次都靠临场发挥，缺少稳定流程。

#### How

用五个关键词建立全场地图：

- Prompt：一次性表达
- Skill：可复用流程
- Context：项目上下文
- Quality Gate：质量门禁
- 工程闭环：从需求到验收

#### What

放大一句话：

> **Prompt 是一次对话，Skill 是团队经验，Quality Gate 是工程底线。**

---

### 第 3 页：Vibe Coding 是什么

#### Why

需要先统一概念，避免把 Vibe Coding 误解成“把需求丢给 AI 然后复制代码”。

#### How

用人机分工定义 Vibe Coding：

| 角色 | 负责什么 |
|:---|:---|
| 人 | 目标、业务判断、架构边界、最终验收 |
| AI | 读代码、写代码、补测试、跑验证、总结风险 |
| 工具链 | 编译、测试、Lint、CI、发布门禁 |

#### What

建议定义：

> Vibe Coding 是一种用自然语言驱动开发的方式。人负责目标、约束和验收标准，AI 负责搜索、编码、测试、总结和辅助决策。

---

### 第 4 页：Vibe Coding 不是什么

#### Why

如果不先划清边界，听众容易把它理解成“更快但更乱的开发方式”。

#### How

列出反面误区：

- 不是把需求丢给 AI，然后直接复制代码
- 不是让 AI 随机引入框架、模式和依赖
- 不是跳过测试、Review 和发布风险判断
- 不是用一堆“万能提示词”替代工程经验

#### What

本页结论：

> **AI 可以加速编码，但不能替代工程判断。**

---

### 第 5 页：参考资料 1 - `vibe-coding-cn` 的核心思想

#### Why

需要从体系化资料里提炼一套可复用框架，而不是只讲个人经验。

#### How

提炼 `vibe-coding-cn` 的五层：

1. **Prompt**：一次性指令，解决表达问题
2. **Skill**：可复用能力，解决高频任务的稳定执行问题
3. **Context**：持续上下文，解决长期协作的信息丢失问题
4. **Quality Gate**：测试、CI、脚本、类型、schema、清单等硬门禁
5. **工程闭环**：问题定义、计划拆解、AI 执行、测试审查、复盘沉淀

#### What

资料来源：

- <https://github.com/NBXXF/vibe-coding-cn>

建议讲法：

> Vibe Coding 的成熟形态，不是“更会写 Prompt”，而是把 Prompt、Skill、上下文和质量门禁组合成工程系统。

---

### 第 6 页：参考资料 2 - Vibe Coding 实战指南

#### Why

需要补充工具、提示词、项目管理、陷阱这些更贴近日常使用的内容。

#### How

提炼四个分享点：

- 工具不是重点，工作流才是重点
- 提示词需要分层：角色、任务、上下文、约束、输出格式
- 项目越复杂，越要先拆计划
- 常见陷阱集中在上下文不足、需求不清、缺少验证、安全与可维护性

#### What

资料来源：

- <https://juejin.cn/post/7622335799020601350>

建议讲法：

> 初学者关注“哪个工具更强”，成熟团队关注“如何让任何工具都按同一套工程标准工作”。

---

### 第 7 页：为什么要先写计划

#### Why

AI 很擅长局部代码生成，但没有计划时容易在错误方向上快速推进。

#### How

计划要固定五件事：

- 目标
- 约束
- 改动边界
- 执行步骤
- 验证方式

#### What

可放到 PPT 的结论：

> **计划不是为了拖慢开发，而是为了防止 AI 在错误方向上高速前进。**

---

### 第 8 页：一个好计划应该包含什么

#### Why

计划不能只是“我要做什么”，还要能让 AI 明确知道“不该做什么”和“怎么证明做对了”。

#### How

使用这个模板：

```text
目标：要解决什么问题？
现状：当前代码或流程是什么样？
差距：为什么现在做不到？
约束：不能改什么？必须遵守什么？
方案：准备怎么改？
步骤：按什么顺序执行？
验证：怎么证明改对了？
风险：还有哪些不确定？
```

#### What

最终产物是一份可执行计划，而不是一句模糊需求。

---

### 第 9 页：从 Prompt 到 Skill

#### Why

Prompt 适合解决一次性问题，但团队高频任务不能长期依赖每个人临场表达。

#### How

用三层对比说明升级路径：

| 方式 | 适合什么 | 问题 |
|:---|:---|:---|
| 单次 Prompt | 临时问题、低风险任务 | 依赖个人表达，复用性差 |
| Prompt 模板 | 高频问答、固定格式输出 | 仍然容易遗漏上下文和门禁 |
| Skill | 团队规范、复杂流程、质量门禁 | 需要持续维护 |

#### What

本页结论：

> **当一类任务重复出现三次，就应该考虑从 Prompt 升级成 Skill。**

---

### 第 10 页：Skill 的 Why / How / What

#### Why

Skill 用来把团队经验从“口头约定”变成“Agent 可执行流程”。

#### How

一个实用 Skill 至少包括：

- `name`：技能名
- `description`：什么时候触发
- `workflow`：执行步骤
- `rules`：必须遵守的约束
- `verification`：验证命令或验收方式
- `output`：最终输出要求

#### What

Skill 可以理解为：

> 一份可被 Agent 读取和执行的任务说明书，包含触发场景、操作步骤、约束、验证方式和输出要求。

---

### 第 11 页：什么是幻觉

#### Why

AI 幻觉是工程落地里的真实风险，会让团队错误相信不存在的 API、错误的测试结果或错误的项目事实。

#### How

用工程手段压低幻觉：

- 给足上下文
- 要求 AI 先读代码再改
- 用编译、测试、Lint、CI 做硬门禁
- 让 AI 输出证据，而不是只输出结论

#### What

工程里的常见幻觉：

- 编造不存在的 API
- 引入项目没有使用的框架
- 错判模块职责
- 忽略生命周期、线程、权限、混淆等真实风险
- 声称“测试通过”，但其实没有跑测试

---

### 第 12 页：什么是固化

#### Why

团队不能每次都从零教 AI 一遍架构、命名、测试、发布和 Review 规则。

#### How

把稳定规则固化成 Skill：

- 架构分层
- 命名规则
- UI 技术选型
- 测试策略
- 发布流程
- R8/ProGuard 规则
- 风险评估方式

#### What

定义：

> 固化不是把 AI 限死，而是把已经验证有效的团队经验变成可复用、可执行、可检查的规则。

---

### 第 13 页：为什么 AI 写基础代码可能是灾难性的

#### Why

基础代码一旦风格漂移，后续功能都会继承混乱，维护成本比业务代码更高。

#### How

用团队规范约束 AI：

- 统一架构
- 统一状态管理
- 统一命名
- 统一存储方式
- 统一日志方式
- 统一测试和 Review 门禁

#### What

没有约束时的典型问题：

- 每次生成不同架构
- 每个页面使用不同状态管理方式
- 公共逻辑重复散落
- UI 文案硬编码
- 测试和错误处理缺失
- 可发布库忘记 consumer rules

---

### 第 14 页：本项目 `android-skills` 的定位

#### Why

共享 Android 工程规范不应该散落在聊天记录、个人习惯和口头约定里。

#### How

通过共享 Skill 库沉淀通用 Android 规则：

- 新增/修改 Android 代码时默认遵守 Kotlin、架构、命名、测试、Review、风险门禁
- Agent 修改代码前先读取对应规则
- 团队要求从口头约定变成可执行文件

#### What

项目定位：

> `android-skills` 是一套共享 Android 工程规则 Skill 库，不描述具体业务，而是沉淀通用 Android 开发流程和工程约束。

---

### 第 15 页：共享 Skill 全量地图与主讲优先级

#### Why

要让同事看到 Skill 不是一个文件，而是一组覆盖完整交付链路的规则系统。同时也要避免现场逐个展开导致节奏失控。

#### How

按“讲师主讲优先级”分类，而不是简单按文件名罗列：

| 分类 | Skill | 讲法 |
|:---|:---|:---|
| 交付总控 | `aaaaa-xxf-delivery-loop` | **重点讲**，它是入口和总控 |
| 语言与风格 | `aaaaa-xxf-language-selection`、`aaaaa-xxf-coding-style`、`aaaaa-xxf-comment-guidelines` | 讲“统一代码口径” |
| 架构与模块 | `aaaaa-xxf-coding-arch`、`aaaaa-xxf-multi-module-structure`、`aaaaa-xxf-module-scaffold`、`aaaaa-xxf-class-declaration-guidelines`、`aaaaa-xxf-model-naming-guidelines` | 讲“防止 AI 乱建结构” |
| UI 与用户可见质量 | `aaaaa-xxf-android-i18n-strings`、`aaaaa-xxf-ui-design-alignment`、`aaaaa-xxf-android-performance-gate` | 讲“用户能感知的质量门禁” |
| 测试与验证 | `aaaaa-xxf-test-strategy`、`aaaaa-xxf-unit-test-writer`、`aaaaa-xxf-auto-test-orchestrator` | 讲“怎么证明改对了” |
| Review 与风险 | `aaaaa-xxf-code-reviewer`、`aaaaa-xxf-risk-gate`、`aaaaa-xxf-clarify-question` | 讲“什么时候停下来问人，什么时候给风险结论” |
| 发布与混淆 | `aaaaa-xxf-maven-library-release-guard`、`aaaaa-xxf-code-shrinking-guard` | 讲“发布库和 R8 的高风险门禁” |
| 趣味 Demo | `aaaaa-xxf-acknowledge-before-work` | 只作为演示，不归入工程主链路 |

#### What

本页结论：

> 共享 Skill 不是要现场逐个背诵，而是要让大家理解：它覆盖了从编码、架构、UI、测试、Review 到发布风险的完整工程链路。

---

### 第 16 页：`delivery-loop` 是怎样串起交付闭环的

#### Why

全量地图讲完后，必须马上抓住一个主入口。否则听众会觉得 Skill 很多但不知道从哪里开始。

#### How

`aaaaa-xxf-delivery-loop` 把一次编码任务串成：

1. 读取模块和项目约束
2. 默认使用 Kotlin
3. 遵守编码风格和架构规则
4. 按需加载类型声明、模型命名、UI、性能、混淆等专项 Skill
5. 判断测试范围
6. 运行最小相关 Gradle 验证
7. 做代码审查和风险评估
8. 输出改了什么、跑了什么、残余风险是什么

#### What

一句话总结：

> **delivery-loop 把一个“写代码请求”升级成一个“可验收的工程交付流程”。**

---

### 第 17 页：Skill Demo - 陪聊 Skill

#### Why

在讲完工程主链路后，用一个轻松、可感知的 Demo 让大家直观看到：Skill 可以强制改变 Agent 行为。

#### How

展示 `aaaaa-xxf-acknowledge-before-work`：

- 每次用户请求前，先执行 `scripts/current_time.py`
- 再输出固定开场白和当前时间
- 然后继续执行用户任务

#### What

转场话术：

> 如果一个 Skill 可以强制 Agent 先打招呼，那它也可以强制 Agent 先读架构规范、先补测试、先跑验证、先做风险评估。

---

### 第 18 页：从趣味 Skill 到工程 Skill

#### Why

陪聊 Skill 的价值不是“好玩”，而是证明 Agent 行为可以被规则化。讲师要立刻把听众从趣味演示拉回工程价值。

#### How

用对比讲清楚迁移路径：

| 趣味 Skill | 工程 Skill |
|:---|:---|
| 固定开场白 | 固定开发流程 |
| 获取当前时间 | 获取项目上下文 |
| 改变对话行为 | 改变编码行为 |
| 低风险演示 | 高价值沉淀 |

#### What

本页结论：

> Skill 的本质不是“让 AI 更会聊天”，而是“让 AI 按流程行动”。

---

### 第 19 页：实战 Demo 设计总览

#### Why

分享不能只讲概念，要让同事看到 Skill 如何影响 Agent 的真实执行路径。Demo 要先给总览，再逐个拆细节。

#### How

建议做 12-15 分钟 Demo，按“轻松感知 -> 工程主线 -> 业务项目”递进：

1. **陪聊 Skill**
   - 展示 Skill 可以强制改变 Agent 行为

2. **版本号升级 Skill**
   - 展示发版脚本和 flavor 校验

3. **渠道配置 Skill**
   - 展示复杂业务流程如何标准化

4. **禁止写法 Skill**
   - 展示 Review 规则如何前置

#### What

Demo 组合：

| Demo | 预计时长 | 重点 |
|:---|:---|:---|
| 陪聊 Skill | 2 分钟 | Skill 可以改变 Agent 行为 |
| `android-bump-version` | 3 分钟 | 发版动作必须走脚本和校验 |
| `android-channel-flavor-config` | 5 分钟 | 复杂业务配置流程标准化 |
| `android-prohibited-rules` | 3 分钟 | 禁止项前置到编码和 Review |

业务项目 Skill 路径：

```text
/Users/xxf/Documents/developer/android/work_space/OverseasGameIaaAndroid/.agents/skills
```

---

### 第 20 页：Demo 1 - `android-bump-version`

#### Why

版本号升级看似简单，但如果手工修改容易出现渠道写错、版本号规则不一致、分支同步遗漏、脚本行为被绕过等问题。

#### How

这个 Skill 把发版前升版本固定成流程：

1. 必须拿到明确 flavor/channel 名称
2. 校验当前目录存在 `update_version.sh` 和 `config.gradle`
3. 校验 flavor 是否存在于 `config.gradle`
4. 通过 `bash update_version.sh "$FLAVOR"` 执行
5. 交互确认后再继续
6. 输出 flavor、versionCode/versionName 变化、提交分支和同步结果

#### What

Skill 的核心规则：

- 不允许手工编辑 `config.gradle` 升级版本号
- 不允许缺少渠道名时执行脚本
- 不允许跳过 flavor 存在性校验
- 脚本失败时报告失败阶段和关键错误

可现场 Demo 请求：

```text
给 xxx 渠道发版前升一个版本号
```

讲解重点：

> 这个 Skill 的价值不是“帮我执行命令”，而是防止 Agent 绕过仓库既有发版脚本和渠道校验。

---

### 第 21 页：Demo 2 - `android-channel-flavor-config`

#### Why

创建渠道包是高风险、高步骤、高上下文任务，涉及配置、资源、广告位、Firebase、Gradle、分支同步和敏感文件边界。

#### How

这个 Skill 把“创建或同步渠道”拆成流程：

1. 先确认 flavor 是否已存在
2. 用户选择参考模板 flavor
3. 读取项目流程和配置入口
4. 先补 `new_product/flavor_profiles.json`
5. 通过 `./gradlew createFlavor -Pflavor=<flavor>` 生成
6. 对齐 `config.gradle`、`flavorConfig.gradle`、`app/build.gradle`、本地广告配置、Firebase 客户端配置
7. 跑 `verifyFlavor` 或相关 BuildConfig、Google Services、Manifest 任务
8. 主动询问是否同步到 `common_pkg_release`
9. 用户确认后通过脚本同步，默认不 push

#### What

Skill 的核心规则：

- 不直接调用底层 bash 脚本创建渠道
- 不手工复制粘贴生成文件，优先走 Gradle 入口
- 不打印或提交服务端密钥内容
- 同步打包分支前必须确认
- 默认只同步渠道相关路径，避免带入无关脏改动

可现场 Demo 请求：

```text
给我创建一个渠道包 xxx，信息参考渠道表
```

讲解重点：

> 这个 Skill 展示了业务项目 Skill 的真正价值：它把“只有熟手知道的渠道创建流程”写成 Agent 可以稳定执行的步骤。

---

### 第 22 页：Demo 3 - `android-prohibited-rules`

#### Why

代码质量问题如果等到 Review 才发现，成本已经偏高；如果 AI 生成时就引入禁止写法，后续维护会越来越难。

#### How

这个 Skill 把禁止项前置成阻断规则：

1. 编码前判断是否会触达 JSON、日志、异步流程、Retrofit、KV 存储
2. 编码中发现准备引入禁止写法时，立即切换到项目认可方案
3. 提交前逐条检查 diff
4. Review 时命中即要求修改，不接受“后面再改”

#### What

五类阻断项：

- 禁止直接使用 `org.json`
- 禁止一行代码打一行日志
- 禁止地狱式回调
- 禁止把 Retrofit API 写成统一工具方法
- 禁止直接使用 `KVUtil.kt` / `MMKV`

可现场 Demo 请求：

```text
请 review 这次 Android 改动，重点检查是否命中项目禁止写法
```

讲解重点：

> 这个 Skill 的价值是把 Review 高频意见提前到编码阶段，让 AI 不只是写代码，也主动避开团队已经明确禁止的技术债。

---

### 第 23 页：业务项目 Skill 的方法论总结

#### Why

同事需要知道什么时候该写项目级 Skill，而不是所有问题都堆到共享 Skill 里。

#### How

判断标准：

- **共享 Skill**：跨项目通用，例如 Kotlin 风格、测试策略、R8 门禁
- **项目 Skill**：只在当前仓库成立，例如渠道表、发版脚本、配置文件、业务禁止项
- **模块 Skill**：只在某个模块成立，例如模块路径、发布坐标、专属验证命令

#### What

项目级 Skill 最适合沉淀：

- 发版流程
- 渠道配置
- 业务配置表字段映射
- 禁止写法
- 特定分支同步方式
- 敏感文件处理边界

---

### 第 24 页：Skill 库如何搭建

#### Why

Skill 库不是一次性写完的，而是从团队重复踩坑和重复 Review 意见里长出来的。

#### How

搭建步骤：

1. **收集高频问题**
   - 哪些 Review 意见反复出现？
   - 哪些 Bug 经常回归？
   - 哪些发布事故可以提前门禁？

2. **抽象成规则**
   - 触发条件是什么？
   - 必须读哪些文件？
   - 必须遵守哪些边界？
   - 必须跑哪些验证？

3. **写成 Skill**
   - 保持短小、过程化、可执行
   - 不写空泛原则
   - 明确输入、步骤、验证、输出

4. **接入项目**
   - 放入项目级 `.agents/skills`
   - 或安装到用户级 skill 目录
   - 或通过 `npx skills` 安装

5. **持续迭代**
   - 每次 AI 犯错，优先判断是否需要补充 Skill
   - 每次 Review 发现共性问题，沉淀为规则

#### What

最终产物是一套分层 Skill 库：

```text
共享 Android Skills
  -> 项目级业务 Skills
    -> 模块级专属 Skills
```

---

### 第 25 页：Skill 库的三种引入方式

#### Why

团队要让 Skill 可复制、可安装、可接入不同 Agent，而不是只存在某个人机器上。

#### How

结合本项目 README，可以讲三种方式：

| 方式 | 命令/入口 | 适合场景 |
|:---|:---|:---|
| 本地 `install.sh` | `bash /path/to/android-skills/install.sh codex project` | 团队项目自动化安装 |
| 项目 `setup-ai-skills.sh` | `./setup-ai-skills.sh` | 项目初始化，一次装 Codex + Claude |
| `npx skills` | `npx -y skills add NBXXF/android-skills --all --copy` | 手动安装，机器已有 Node.js/npm |

#### What

补充说明：

- Codex project install 会复制到 `.agents/skills`，并在 `AGENTS.md` 写入托管说明
- Claude install 会复制到 `.claude/skills`
- Cursor project install 会复制 rules 到 `.cursor/rules`

---

### 第 26 页：现场 Demo 执行清单

#### Why

Demo 现场最怕失控：命令卡住、上下文太多、任务跑太远、敏感信息被展示。需要提前准备执行清单。

#### How

Demo 前准备：

- 提前打开 `android-skills` 仓库和业务项目 Skill 目录
- 只展示 Skill 结构和关键规则，不展示敏感配置内容
- 版本号升级 Demo 可以只演示校验流程，不一定真正提交
- 渠道配置 Demo 重点展示流程，不建议现场完整创建真实渠道
- 禁止写法 Demo 最适合做静态 review，风险最低

#### What

现场执行顺序：

| 顺序 | 展示内容 | 控制点 |
|:---|:---|:---|
| 1 | 陪聊 Skill | 只展示行为改变 |
| 2 | `delivery-loop` | 只讲流程，不跑完整任务 |
| 3 | `android-bump-version` | 展示 flavor 校验和脚本入口 |
| 4 | `android-channel-flavor-config` | 展示流程图和关键文件，不现场泄露表格内容 |
| 5 | `android-prohibited-rules` | 用 review 视角讲阻断项 |

兜底方案：

> 如果现场环境不稳定，就直接展示 Skill 文件、流程图和预期输出，不强行跑真实命令。

---

### 第 27 页：现场命令速查 - 安装与项目接入

#### Why

同事要能把分享内容带回自己的项目，至少知道如何安装和查看 Skill。

#### How

展示常用命令：

```bash
bash /path/to/android-skills/install.sh codex project
bash /path/to/android-skills/install.sh codex user
./setup-ai-skills.sh
npx -y skills add NBXXF/android-skills --all --copy
find skills -maxdepth 2 -name 'SKILL.md'
```

#### What

本页让大家知道：

- Skill 可以项目级安装
- Skill 可以用户级安装
- Skill 可以通过脚本批量接入
- `AGENTS.md` 是 Agent 发现项目规则的重要入口

---

### 第 28 页：现场命令速查 - Codex CLI 常用命令

#### Why

命令不是为了炫技，而是把 AI 编程拆成可控动作。

#### How

本地可确认的 Codex CLI 命令：

| 命令 | 用途 | 分享时怎么讲 |
|:---|:---|:---|
| `codex` | 进入交互式编码会话 | 最常用入口，适合日常结对开发 |
| `codex exec` | 非交互执行任务 | 适合脚本化、批处理、CI 辅助 |
| `codex review` | 非交互代码审查 | 适合 PR 前自查风险 |
| `codex login` / `codex logout` | 登录与退出 | 解决认证问题 |
| `codex mcp` | 管理 MCP 服务 | 接入外部工具和上下文能力 |
| `codex plugin` | 管理插件 | 扩展 Codex 能力 |
| `codex resume` | 恢复历史会话 | 接着上次上下文继续做 |
| `codex apply` | 应用最近一次 Agent diff | 适合先审 diff 再落地 |
| `codex doctor` | 诊断本地安装、配置、认证、运行环境 | 排查环境问题 |
| `codex update` | 更新 Codex | 演示前确认工具版本 |

#### What

可现场展示：

```bash
codex --help
codex doctor
codex review
codex mcp --help
```

注意：命令细节会随 Codex 版本变化，演示前以 `codex --help` 为准。

---

### 第 29 页：交互命令与概念关系

#### Why

同事容易混淆 Prompt、智能体、Skill、MCP、命令，需要在实操前统一概念。

#### How

用表格解释关系：

| 概念 | 解决什么问题 | 类比 |
|:---|:---|:---|
| Prompt | 本次要做什么 | 一次任务说明 |
| 智能体 | 谁来执行、按什么能力执行 | 一个可行动的执行者 |
| Skill | 高频任务怎么稳定执行 | 操作手册 |
| MCP | AI 怎么连接外部工具和数据 | 工具接口协议 |
| 命令 | 人怎么控制工具流程 | 操作按钮 |

#### What

本页结论：

> **命令控制节奏，Skill 固化流程，门禁验证结果。**

---

### 第 30 页：团队怎么落地

#### Why

Vibe Coding 如果只停留在个人技巧层面，很难形成团队收益。

#### How

推荐落地路径：

1. **先不追求大而全**
   - 从最痛的 3 个问题开始
   - 例如：国际化、测试范围、R8 混淆、渠道配置、版本号升级

2. **把 Review 高频问题写成 Skill**
   - 例如：新增 UI 文案必须进入 `strings.xml`
   - 例如：公共库反射必须检查 consumer rules
   - 例如：禁止新增直接 `org.json` 和噪音日志

3. **把验证命令写进 Skill**
   - 不只告诉 AI 应该注意什么
   - 还要告诉 AI 怎么证明它做对了

4. **用 AGENTS.md 做入口**
   - 告诉 Agent 从哪个总控 Skill 开始
   - 项目私有规则和共享规则分开维护

5. **每次事故后更新 Skill**
   - 让事故经验变成下一次的自动门禁

#### What

团队落地结果：

> 每个项目都有自己的 Agent 操作手册，每次改动都有明确流程、验证和风险说明。

---

### 第 31 页：团队协作中的角色变化

#### Why

AI 进入研发流程后，人的价值不会消失，但工作重心会变化。

#### How

角色变化：

| 过去 | 现在 |
|:---|:---|
| 人写代码 | AI 承担大量执行工作 |
| 人查文档 | AI 读取项目上下文和规则 |
| 人跑测试 | AI 选择并执行最小验证 |
| 人做 Review | AI 先做自审，人做关键判断 |
| 人总结风险 | AI 输出初版风险，人最终确认 |

#### What

建议表达：

> **未来更重要的不是会不会让 AI 写代码，而是能不能设计出 AI 也必须遵守的工程系统。**

---

### 第 32 页：最后总结

#### Why

结尾要把听众从概念带回行动：回去就能开始沉淀自己的 Skill。

#### How

三句话收束：

1. **Vibe Coding 的核心是人机协作，不是 AI 代替工程判断。**
2. **计划让 AI 不跑偏，Skill 让经验可复用，Quality Gate 让结果可信。**
3. **团队级 Vibe Coding 的关键，是把工程规范写进 Agent 的工作流。**

#### What

最后一页放：

> **不要只追求 AI 写得快，要追求 AI 在正确边界里稳定交付。**

---

## 4. 演讲提词

### 开场

#### Why

大家可能都已经用过 AI 写代码，但今天要讲的不是“AI 能写多少代码”，而是“怎么让 AI 写出来的代码符合团队标准”。

#### How

可以这样开场：

> 如果 AI 只是一个更快的复制粘贴工具，它会带来很多维护问题。但如果我们把团队工程规范、测试策略、Review 经验、发布风险都沉淀成 Skill，AI 就可以变成一个更可靠的结对开发者。

#### What

开场目标：建立“工程闭环”主线。

### 讲 Skill 时

#### Why

同事可能听过 Prompt，但不一定理解 Skill 为什么比 Prompt 更适合团队协作。

#### How

可以这样讲：

> Skill 可以理解为写给 Agent 的操作手册。它不是泛泛地告诉 AI“你要写好代码”，而是明确告诉它：什么时候触发、先读什么、按什么步骤做、哪些事不能做、最后怎么验证。

#### What

本段目标：让大家接受“团队应该维护 Skill，而不是每个人各自收藏一堆 Prompt”。

### 讲业务项目 Demo 时

#### Why

需要说明业务项目 Skill 不是重复共享 Skill，而是补足项目特有流程。

#### How

可以这样转场：

> 共享 Skill 解决通用 Android 工程规范，但每个项目还有自己的发版脚本、渠道配置流程、禁止写法和分支同步规则。这些东西最适合写成项目级 Skill。

#### What

本段目标：引出 `android-bump-version`、`android-channel-flavor-config`、`android-prohibited-rules` 三个 Demo。

### 结尾

#### Why

需要强调 Vibe Coding 不是偷懒，而是更严格地表达工程规范。

#### How

可以这样收束：

> Vibe Coding 不是放弃工程规范。相反，它要求我们把工程规范写得更清楚、更可执行，因为 AI 只会严格受益于明确的上下文和硬门禁。

#### What

结尾目标：促使团队开始沉淀自己的项目级 Skill。

---

## 5. 适合放在 PPT 里的金句

### Why

金句用于帮助听众记忆核心观点。

### How

每个章节挑 1 句，不要一页塞太多。

### What

- **Prompt 是一次对话，Skill 是团队经验。**
- **计划不是拖慢开发，而是防止 AI 在错误方向上高速前进。**
- **AI 可以加速编码，但不能替代工程判断。**
- **当一类任务重复出现三次，就应该考虑从 Prompt 升级成 Skill。**
- **Skill 的本质不是让 AI 更会聊天，而是让 AI 按流程行动。**
- **共享 Skill 解决通用规范，项目 Skill 解决业务流程。**
- **不要只追求 AI 写得快，要追求 AI 在正确边界里稳定交付。**
- **每次 AI 犯错，都是一次补充团队 Skill 的机会。**
- **命令控制节奏，Skill 固化流程，门禁验证结果。**

---

## 6. 后续可扩展内容

### Why

一次分享很难覆盖所有落地细节，可以拆成系列。

### How

后续可以做四个方向：

1. **Vibe Coding 入门课**
   - 工具选择
   - Prompt 基础
   - 读代码和改代码的基本流程

2. **Skill 编写工作坊**
   - 从一次 Prompt 提炼成 Skill
   - 写触发条件和执行步骤
   - 加入验证和输出要求

3. **Android 工程闭环实战**
   - 国际化门禁
   - 性能门禁
   - R8/ProGuard 门禁
   - Maven Library 发布门禁

4. **业务项目 Skill 实战**
   - 发版版本号升级
   - 渠道 Flavor 配置
   - 禁止写法和日志治理
   - 打包分支同步

### What

后续系列目标：从“会用 AI”升级到“会建设团队级 AI 工程系统”。

---

## 7. 素材来源

### Why

素材来源用于后续生成 PPT、补充引用和现场展示。

### How

按资料类型归类：

- 方法论资料
- 命令资料
- 共享 Skill
- 项目级 Skill

### What

方法论资料：

- `vibe-coding-cn`：<https://github.com/NBXXF/vibe-coding-cn>
- Vibe Coding 终极实战指南：<https://juejin.cn/post/7622335799020601350>
- Vibe Coding 命令与概念介绍：<https://blog.csdn.net/axuanqq/article/details/161261844?spm=1001.2014.3001.5501>

共享 Skill：

- `README.md`
- `skills/aaaaa-xxf-delivery-loop/SKILL.md`
- `skills/aaaaa-xxf-acknowledge-before-work/SKILL.md`
- `skills/aaaaa-xxf-code-reviewer/SKILL.md`
- `skills/aaaaa-xxf-risk-gate/SKILL.md`
- `skills/aaaaa-xxf-code-shrinking-guard/SKILL.md`

业务项目 Skill：

- `/Users/xxf/Documents/developer/android/work_space/OverseasGameIaaAndroid/.agents/skills/android-bump-version/SKILL.md`
- `/Users/xxf/Documents/developer/android/work_space/OverseasGameIaaAndroid/.agents/skills/android-channel-flavor-config/SKILL.md`
- `/Users/xxf/Documents/developer/android/work_space/OverseasGameIaaAndroid/.agents/skills/android-channel-flavor-config/references/project-map.md`
- `/Users/xxf/Documents/developer/android/work_space/OverseasGameIaaAndroid/.agents/skills/android-channel-flavor-config/references/channel-workflow.md`
- `/Users/xxf/Documents/developer/android/work_space/OverseasGameIaaAndroid/.agents/skills/android-prohibited-rules/SKILL.md`
