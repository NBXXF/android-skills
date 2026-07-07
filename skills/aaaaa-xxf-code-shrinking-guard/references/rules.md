# R8/ProGuard 审计规则

## 1. 扫描范围

至少搜索：

```text
Class.forName
loadClass
getAnnotation / annotations
getDeclaredField / getDeclaredMethod / getDeclaredConstructor
newInstance / Constructor.newInstance
java.lang.reflect / kotlin.reflect
ServiceLoader
MethodHandles
Proxy.newProxyInstance
Resources.getIdentifier
getIdentifier
System.loadLibrary
external / native
Class.getName / canonicalName / simpleName
SerializedName / JsonAdapter / TypeToken
Room / Gson / Jackson / Moshi / Retrofit
Parcelize / Parcelable / Serializable
```

同时检查注解处理器、KSP/KAPT 生成目录、`META-INF/services`、manifest 类名、XML 自定义 View、导航/路由表、JNI 注册、序列化模型和泛型父类解析。

发现 Retrofit 时执行 [retrofit-response-type-keeper.md](retrofit-response-type-keeper.md) 的专项流程。

以下不一定需要规则：仅比较 `SomeType::class.java`、`isAssignableFrom`，或者反射目标完全可由 R8 静态推断。必须根据目标是否被裁剪、改名或移除属性判断，不能按 import 判断。

## 2. 动态行为到规则的映射

| 行为 | 通常需要 | 注意 |
|---|---|---|
| `Class.forName("a.b.C")` | `-keepnames class a.b.C`，并保留实际调用成员 | 类仍可能被裁剪；需要可达性规则 |
| 按字段/方法字符串查找 | 对目标使用 `-keepclassmembers` | 若类名也字符串化，另加 `-keepnames` |
| 反射创建实例 | 保留目标类可达性及准确构造器 | Kotlin 默认参数不等同 Java 无参构造器 |
| 读取运行时注解 | 保留 annotation attributes、注解类和被读取目标 | `Retention.RUNTIME` 是前提，不是 R8 规则替代品 |
| 解析泛型 `Type` | `-keepattributes Signature`，并保持承载签名的类可达 | R8 full mode 对非 kept endpoint 更严格 |
| 内部类/匿名类泛型 | `Signature,InnerClasses,EnclosingMethod` | Retrofit/TypeToken 常见 |
| 参数注解 | `RuntimeVisibleParameterAnnotations,RuntimeInvisibleParameterAnnotations` | Retrofit 接口常见 |
| 注解默认值 | `AnnotationDefault` | 运行时读取默认成员值时需要 |
| `ServiceLoader` | 保留 provider 构造器并验证服务资源适配 | 必须用 minified consumer 实测 |
| JNI 按名称绑定 | 保留 native 方法和相关类名 | 动态注册 JNI 规则不同 |
| Java serialization | 保留协议要求的字段、构造器或特殊方法 | 不要默认 keep 整个模型包 |

## 3. 常用最小规则

```proguard
# 只保留运行时元数据
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations,RuntimeInvisibleParameterAnnotations
-keepattributes AnnotationDefault

# 反射创建某接口实现；允许类改名，但保留公开无参构造器
-keep,allowoptimization,allowobfuscation class * implements com.example.Factory {
    public <init>();
}

# 注解驱动的成员访问
-keepclassmembers,allowoptimization class * {
    @com.example.RuntimeField <fields>;
    @com.example.RuntimeMethod <methods>;
}

# 仅名称构成外部协议时
-keepnames class com.example.ProtocolEntry
```

不要机械复制示例。`-keep` 默认同时禁止裁剪、优化和改名；能允许的能力应显式允许，以控制体积和优化损失。

## 4. 规则归属

app 自己的动态访问规则放进 app release 实际加载的 ProGuard 文件。工程内 Android library 也应使用 `consumerProguardFiles`，让规则跟随依赖关系自动汇入最终 app；不要依赖 app 人工复制。工程内 JVM library 按 JAR 嵌入规则处理。

库必须内置以下规则：

- 库内部反射自己的类或第三方固定实现。
- 库的公开 API 通过注解/接口要求 consumer 提供实现，且规则能用接口或注解精确表达。
- 库运行必须保留的 attributes。

业务规则适用于：

- 业务自行按字符串反射且库无法知道目标。
- 业务选择的模型/实现无法通过库公开注解、基类或接口表达。

若库 API 天生要求业务额外配置，优先改 API：提供 marker annotation/interface、生成代码或显式注册，让库能携带精确规则。只有无法工程化表达时才文档化业务规则。

## 5. 发布形态

### Android AAR

```kotlin
android {
    defaultConfig {
        consumerProguardFiles("consumer-rules.pro")
    }
}
```

构建后解包 AAR，确认 consumer rules 存在。不要把 consumer rules 只放在库自身 `proguardFiles`；后者主要控制库自身构建，不会自动保护下游应用。

### JVM JAR

放置：

```text
src/main/resources/META-INF/proguard/<group-or-library-name>.pro
```

文件名必须唯一，避免多个依赖合并时冲突。构建后执行：

```bash
jar tf module.jar | grep META-INF/proguard
unzip -p module.jar META-INF/proguard/<name>.pro
```

确认真实发布任务使用的 JAR 与本地 `jar` 任务一致；若发布有重打包、shadow、relocation 或资源过滤，必须检查最终 Maven artifact。

## 6. 验证层级

1. 编译：只证明规则语法未参与或源码可编译，不证明安全。
2. 产物检查：证明规则被打包，不证明 R8 会得到正确结果。
3. minified consumer 构建：证明 R8 接受规则并完成 shrink。
4. 运行关键路径：证明反射、注解、泛型、ServiceLoader 或 JNI 在混淆后仍工作。
5. mapping/seeds/usage 分析：证明保留精确，没有体积灾难。

发布 Maven library 的高风险动态行为至少做到第 4 层。无法运行时必须报告未验证风险，不得用普通单测替代。

## 7. Review 清单

- 规则是否跟随最终 Maven artifact？
- 是否覆盖 R8 full mode？
- 是否只保留必要类、成员、名称和 attributes？
- 是否错误依赖 `-dontwarn`？
- 是否保留了业务整个包、所有接口或所有枚举？
- 规则引用的可选依赖不存在时是否会告警或失效？必要时使用条件规则或拆分模块。
- Kotlin object、companion、suspend、默认参数和 internal 名称是否与预期 JVM 结构一致？
- 枚举常量字段名是否属于协议？有序列化注解时能否允许常量改名？
- ServiceLoader 资源内容和 provider 构造器是否在混淆后验证？
- 更新依赖版本后，是否重复、冲突或覆盖其官方规则？
- 每个定义 Retrofit service 的源码模块是否运行了同版本 `response-type-keeper`？
