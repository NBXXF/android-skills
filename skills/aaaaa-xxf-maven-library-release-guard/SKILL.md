---
name: aaaaa-xxf-maven-library-release-guard
description: Android Maven 发布库的构建变体、运行时配置、混淆与职责收尾门禁。新增、维护、重构或发布 Android Library/AAR（含应用 publish_maven.gradle 的模块），修改 buildFeatures、BuildConfig、maven-publish、singleVariant、publish_maven.gradle、发布脚本、POM、Maven 坐标或版本、调试开关、环境开关、混淆注解或 proguard/consumer 规则时必须使用；防止 release AAR 将库内 BuildConfig.DEBUG 常量折叠为 no-op、GONE、错误分支，或把混淆规则误当成自动保留方案。给出交付结论前必须完成职责收尾清单，并用 AskUserQuestion 强制让用户主动确认是否做到位，未确认不得 Pass。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android Maven 发布库门禁

## 目标

保证 Maven AAR 的行为由宿主运行时配置决定，不被 Library 自身的 release 构建类型或混淆配置错误固化。

## 先判断模块性质

满足任一条件即按“可发布 Maven Library”处理：

- 应用了 `maven-publish` 或仓库发布脚本。特别地，lib 应用了 `publish_maven.gradle`（如 `apply(from = "../../../publish_maven.gradle")`）即为发布库/Maven 库，无论发布配置写在何处。
- 配置了 `publishing`、`MavenPublication`、`singleVariant("release")`。
- 配置了 `publishing`、`MavenPublication`、`singleVariant("release")`。
- 定义了 Maven group、artifact、version 或 publish task。
- 产物会被其他独立工程以 AAR/Maven 坐标消费。

仅通过 `project(":module")` 在同一工程编译、且确定永不发布的内部模块，才属于工程内 Library。

## 强制规则

### 禁止 Library 自身 BuildConfig

可发布 Maven Library 默认必须满足：

- 不开启 `buildFeatures { buildConfig = true }`；无其他用途时显式关闭或删除配置。
- `src/main` 不引用、导入、反射或按字符串查找 Library 自身的 `BuildConfig`。
- 不使用 `BuildConfig.DEBUG` 控制功能、日志、UI、初始化、网络、环境或 no-op 实现。
- 不通过自定义 `buildConfigField` 向发布库注入运行时业务状态。

发现以上任一项，风险结论默认是 `Block`。原因是 Maven 通常发布 release variant，Library 的 `BuildConfig.DEBUG` 表示“Library 产物变体”，不表示“宿主 App 是否可调试”。R8/Kotlin/Javac 还可能把分支常量折叠，导致 API 变成空方法、固定 `GONE` 或永久关闭。

只有为了保持已经发布的公共 ABI，且有明确调用方证据时，才能临时保留 BuildConfig 生成；即使保留，也禁止业务代码读取它，并记录迁移计划。

### 涉及混淆时

- 如果是 Android Library/AAR 且代码会被 R8/ProGuard 处理，优先按 [references/obfuscation.md](references/obfuscation.md) 执行。
- `@Keep` 只能作为源代码级标记，不替代 `proguard-rules.pro` 或 `consumer-rules.pro`。
- 既有 `proguard-rules.pro`、`consumer-rules.pro`、发布脚本里的 `-keep` 规则必须继续维护，不能因为补了注解就删除。
- 对外发布的库，新增注解时同时检查是否需要补 consumer 规则，保证下游接入后仍能稳定解析、反射或序列化。

### 使用宿主运行时事实

按需求选择一种来源：

1. 优先使用宿主显式注入的配置，默认值必须安全关闭。
2. 只需要判断宿主 APK 是否 debuggable 时，读取宿主 `ApplicationInfo`，而不是 Library `BuildConfig`。
3. 需要动态切换、测试环境或远程开关时，使用显式参数、配置接口或 provider lambda。

不要把“宿主可调试”“测试环境”“日志开关”“业务 debug mode”混成同一个布尔值。

## 排查流程

1. 确认发布的 variant，重点检查 `singleVariant("release")` 和 publication component。
2. 扫描目标模块：

```bash
rg -n "BuildConfig|buildConfigField|buildConfig\\s*=\\s*true|singleVariant|MavenPublication|maven-publish|publish_maven|@Keep|consumer-rules|proguard-rules" MODULE
```

3. 如果命中混淆注解或规则，继续读 [references/obfuscation.md](references/obfuscation.md)，确认是“源码注解 + 规则”并存，而不是二选一。
4. 沿调用链检查宿主是否显式传值，以及 Library 是否真正保存并读取该值。
5. 检查默认值：未初始化、旧调用方或 release 宿主必须默认关闭调试能力。
6. 检查持久化状态是否会覆盖宿主本次初始化值；初始化参数应是当前进程的权威来源。
7. 检查 debug/no-op/release 分支是否因常量折叠变成空方法或固定 UI 状态。

## 修复要求

- 系统性删除目标发布模块所有自身 `BuildConfig` 依赖，不只修当前报错行。
- 公共 API 尽量保持二进制兼容；新增配置字段时提供安全默认值，但宿主接入必须显式赋值。
- 对已无调用的公共类先全仓搜索；删除已发布符号前说明二进制兼容风险并获得用户决定。
- 不用宿主包名反射宿主 `BuildConfig`；优先参数注入或 `ApplicationInfo.FLAG_DEBUGGABLE`。
- 如果目标是 Android lib，补混淆注解时同步维护已有 pro 规则，不得把原来的 `proguard-rules.pro` / `consumer-rules.pro` 当成过时文件删除。

## 最小验证

必须验证发布使用的 release 变体，不能只跑 debug：

```bash
./gradlew :MODULE:testReleaseUnitTest :MODULE:assembleRelease
```

回归测试至少覆盖：

- 宿主传 `true` 时功能开启。
- 宿主传 `false` 或未传时功能关闭。
- 测试运行在 release unit-test variant，能复现 Library `BuildConfig.DEBUG == false` 的发布场景。

构建后检查 release AAR：

```bash
unzip -p MODULE/build/outputs/aar/*-release.aar classes.jar > /tmp/library-release.jar
javap -classpath /tmp/library-release.jar -c -p fully.qualified.EntryClass
```

确认关键方法仍读取运行时字段/参数，`true` 分支没有被裁成空方法、固定 `GONE` 或直接 `return`。同时确认目标模块产物不再包含对自身 `BuildConfig.DEBUG` 的业务引用。

若有宿主工程，至少编译一个实际消费该 Maven 坐标的 debug variant；发布前按发布流程检查 POM、坐标、release AAR，以及混淆注解和 pro 规则是否同时生效。

## 职责收尾与强制确认

### 职责描述

谁封装、谁改造的发布库，谁负责收尾。下游多团队按 Maven 坐标消费，发布者不得把坑留给接入方：问题必须在自己模块内消化，不得以"下游自己注意""后续再补"收场。这是硬性门禁，不是建议，不因任务紧急、改动小或用户未提及而豁免。

### 收尾清单

交付前逐项自查，"做到位"= 以下全部满足，缺任一项即视为未做到位，必须先补齐再进入强制确认：

- API 二进制兼容：新增/变更公共 API 有安全默认值；删除或变更已发布符号有全仓调用方证据，或已加 `@Deprecated` 加迁移说明。
- 文档同步：README、接入文档、变更记录已更新；破坏性变更写明迁移步骤。
- 混淆规则同步：新增注解同步维护 `consumer-rules.pro`，下游 minify 后仍可解析。
- demo/sample：有接入示例的库，demo 已同步新 API 并编译通过。
- release 变体验证：release unit-test、release AAR 字节码检查、宿主集成编译至少完成一项且覆盖本次改动。
- 遗留问题：未解决的 TODO、已知缺陷、临时方案已明确记录在案，不以"应该没问题"沉默发布。

### 强制询问

给出交付结论前，必须用 AskUserQuestion 向用户发起确认，让用户主动选择回复。无例外：禁止模型代答、禁止自由文本默认通过、禁止默认用户同意、禁止跳过确认直接发布：

1. 全部做到位，可以交付/发布
2. 有残留问题，继续修（列出具体项）
3. 有残留但接受，先记录到 `vibe-coding-clarify.md` 再发布

规则：

- 用户未选择前，不得给出交付结论，不得执行发布动作。
- 用户选 2：回到修复，修完后重新发起确认。
- 用户选 3：必须先按 `aaaaa-xxf-clarify-question` 的记录格式把接受的风险写入对应模块 `vibe-coding-clarify.md`，风险结论最高 `Warn`。
- 用户跳过、忽略或中断确认：按未确认处理，风险结论 `Block`。

## 交付结论

最终必须说明：

- 发布 variant 和问题是否由 Library BuildConfig 引起。
- 删除了哪些 BuildConfig 依赖，宿主运行时配置从哪里注入。
- 如果涉及混淆，补了哪些注解，保留了哪些 `proguard-rules.pro` / `consumer-rules.pro` 规则。
- release 单测、release AAR 和宿主集成分别验证了什么。
- 是否删除公共符号，以及对应兼容风险。
- 职责收尾确认：用户主动选择的选项；选择"有残留但接受"时附 `vibe-coding-clarify.md` 记录路径。
- 风险结论：存在 Library 自身 BuildConfig 业务依赖、混淆注解/规则不同步、未验证 release 产物，或未完成职责收尾强制确认时为 `Block`；用户选择"有残留但接受"并已记录决策时最高 `Warn`；全部通过且用户主动确认做到位后为 `Pass`。
