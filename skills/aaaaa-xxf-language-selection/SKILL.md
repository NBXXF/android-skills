---
name: aaaaa-xxf-language-selection
description: Android 项目语言选择门禁。新增、维护、重构或迁移源码时使用；默认必须使用 Kotlin，禁止新增 Java，触达 Java 维护时优先直接转换为 .kt 文件并完成调用方与验证闭环。
---

# Android 语言选择

## 硬性原则

- 新增 Android/业务/工具源码必须写 Kotlin，文件后缀使用 `.kt`。
- 不新增 `.java` 文件；不要用 Java 作为实现语言。
- 修改既有 Java 代码时，不要只在 `.java` 内打补丁；默认把本次触达的 Java 类型完整转换为 Kotlin。
- 转换后删除或停止使用原 `.java` 文件，避免同包同名类型重复。
- 迁移范围以本次任务触达的类型为边界；不要顺手大规模迁移无关 Java 文件。

## Java 转 Kotlin 流程

1. 先读完整 Java 文件和直接调用方，确认构造器、静态成员、重载、继承、泛型、注解、可空性和线程语义。
2. 新建同包同名 `.kt` 文件，保持对外类名、方法名、字段名和可见性稳定。
3. 将 Java 语义等价迁移为 Kotlin：
   - Java `static` 常量、工厂、工具方法迁到 `companion object` 或 `object`。
   - 需要 Java 调用兼容时补 `@JvmStatic`、`@JvmField`、`@JvmOverloads`、`@file:JvmName`。
   - Java nullable/nonnull 注解转成 Kotlin 可空类型，不能凭空把可能为空的值改成非空。
   - Getter/setter、SAM、匿名类、回调和同步块要保持行为一致。
4. 更新受影响调用方、Gradle/sourceSets、测试和反射字符串引用。
5. 删除旧 `.java` 后运行最小相关验证，至少覆盖编译该模块。

## 兼容性门禁

- 公共 API 从 Java 迁移到 Kotlin 时，必须检查 Java 调用方是否仍能以原方式调用。
- 构造函数默认参数不能替代既有 Java 重载；需要 Java 兼容时使用 `@JvmOverloads` 或显式重载。
- `object`、顶层函数、扩展函数会改变 JVM 符号；对外 API 迁移前必须确认调用方和二进制兼容风险。
- Kotlin `internal` 不等于 Java 包可见性；不要误收窄可见性。
- 改动涉及 Maven 发布库时，进入 `aaaaa-xxf-risk-gate` 检查兼容风险。

## 不确定时

- 如果转换会明显扩大改动面、破坏公共 API、影响反射/序列化/注解处理，先按 `aaaaa-xxf-clarify-question` 让用户确认取舍。
- 默认选择 Kotlin 迁移方案；无法安全迁移时说明阻塞点和需要用户确认的兼容取舍。
