---
name: aaaaa-xxf-code-shrinking-guard
description: 强制审计 Android app、工程内 Android/JVM library 和可发布 Maven library 的 R8/ProGuard 兼容性。凡新增或修改反射、运行时注解、泛型类型解析、ServiceLoader/JNI/序列化、按名称访问、依赖注入、路由、插件发现、Gradle 混淆或发布配置时必须使用；即使用户未提混淆也必须检查规则归属，并按模块类型完成 app rules、consumer rules、产物内容和 minified 集成验证。遇到 Retrofit service 时必须强制进入 response-type-keeper 专项流程。
---

# R8/ProGuard 强制门禁

## 强制条件

对最终进入 Android APK/AAB 的 app、工程内 library 和外部发布 library 执行本门禁。只要改动可能改变 R8 可达性、名称、属性或资源解析，就不得跳过；是否发布 Maven 不影响反射风险，只影响规则存放位置和责任边界。

先读 [references/rules.md](references/rules.md)。如果发现 Retrofit 依赖、`retrofit2.http.*` 注解、`Retrofit.create` 调用或 service 接口定义，立即切换到 [references/retrofit-response-type-keeper.md](references/retrofit-response-type-keeper.md) 专项流程，优先处理 keeper 配置，再继续其他混淆检查。不要因为 Debug 构建成功而判定通过。

## 工作流

1. 定位 app/library 模块、最终 APK/AAB 消费关系、产物类型以及现有 app/consumer rules。
2. 扫描本次改动及模块源码中的反射和隐式动态访问；不能只搜 `java.lang.reflect`。
3. 将每个动态行为映射为实际约束：保留类、名称、成员、构造器、属性、注解或资源。
   - Retrofit service 由当前工程源码定义时，立即执行 keeper 专项流程：确认 service 所在模块、解析实际 Retrofit 版本、在该模块配置同版本的 `response-type-keeper`。不得只依赖 Retrofit/KPower 自带 `.pro`，也不得把这一步延后到普通规则审计之后。
4. 判定规则归属：app 自身动态访问放 app 的规则；工程内 library 优先提供 consumer rules；发布库必须随产物交付规则。业务传入的未知类型使用条件规则、注解契约或明确约束，禁止粗暴全局 keep。
5. 按模块类型放置规则：
   - Android app：放入 release 实际使用的 `proguardFiles(...)`，并验证 minified APK/AAB。
   - Android library：配置 `consumerProguardFiles(...)`，并检查 AAR 内的 consumer rules。
   - JVM JAR library：放到 `src/main/resources/META-INF/proguard/<唯一名称>.pro`。
6. 规则采用最小权限：优先 `-keepclassmembers`、`-keepnames`、`-keepattributes`、`includedescriptorclasses` 和 `allowoptimization/allowshrinking/allowobfuscation` 的安全组合。
7. 构建真实 release 产物；library 还必须解包验证 consumer rules 存在，仅检查源码文件不算完成。
8. 对高风险改动运行启用 R8 full mode/minify 的 app、最小 consumer app 或现有 shrinker 集成测试，执行相关代码路径。
9. 检查 `mapping.txt`、`seeds.txt`、`usage.txt` 或 `-whyareyoukeeping` 输出，确认目标被保留且没有大面积误保留。

## 禁止事项

- 禁止用 `-keep class ** { *; }`、`-keep interface *` 等全局规则掩盖问题。
- 禁止把工程内或发布库自身所需规则推给 app 手工复制；应由 library consumer rules 自动传递。
- 禁止仅添加 `-dontwarn`；它不解决运行时反射和裁剪问题。
- 禁止因为 Kotlin、`reified`、`KClass` 或 `::class.java` 就认定没有反射风险。
- 禁止只保留注解类而忘记 `RuntimeVisibleAnnotations`、被注解目标或反射构造器。
- 禁止保留整个第三方依赖；优先依赖其官方 consumer rules，缺失时只保留本库实际访问的目标。
- 禁止发现源码 Retrofit service 后只保留 `Signature` 或手写猜测 DTO 规则；优先安装官方 `response-type-keeper` 并验证生成结果。
- 禁止对公开库无依据地固定业务类名；混淆不影响正确性时允许 obfuscation。

## 必须升级为失败/阻塞

出现以下任一项时不得宣称完成：

- app release 未应用预期规则，或 library 发布产物中找不到预期 consumer rules。
- 反射目标由业务提供，但没有可执行的保留契约或 consumer 验证。
- 依赖字符串类名、字段名、方法名或 `META-INF/services`，却没有验证混淆后的解析。
- 泛型或运行时注解参与协议选择，却没有保留相应 attributes。
- 当前工程定义 Retrofit service，但其所在模块没有运行 `response-type-keeper`，或者处理器版本与 Retrofit 版本不一致。
- 只能通过宽泛 keep 才能运行，且尚未定位精确目标。
- 高风险路径没有 minified consumer 验证，也没有明确报告残余风险。

## 交付输出

说明动态访问点、增加或确认的规则、规则归属、app/library 配置或产物内路径、执行的 minify 验证、保留范围和残余风险。若无需新增规则，必须给出代码层面的理由。
