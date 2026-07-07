# Retrofit Response Type Keeper

## 为什么内嵌 `.pro` 不够

Retrofit 自带规则可以保留 service 接口、方法注解和泛型 attributes，但 Maven library 发布时不知道业务将定义哪些返回模型。例如：

```kotlin
interface UserApi {
    @GET("users/{id}")
    suspend fun user(@Path("id") id: String): ApiResult<User>
}
```

如果 `ApiResult` 或 `User` 只出现在泛型返回位置，R8 可能裁剪类型并把签名改成通配形式。Retrofit 运行时随后无法把合法类型交给 converter。

官方 `response-type-keeper` 是注解处理器。它必须在定义 service 源码的模块编译期间运行，扫描真实方法并为所有嵌套泛型类型生成精确 `-keep` 规则。普通 `implementation`/`api` 依赖不会替下游模块执行注解处理器。

官方参考：<https://github.com/square/retrofit/tree/trunk/retrofit-response-type-keeper>

## 强制识别

在全工程搜索：

```text
import retrofit2.http.
@GET @POST @PUT @DELETE @PATCH @HEAD @OPTIONS @HTTP
Retrofit.create
retrofit.create
```

按源码归属列出每个定义 Retrofit service 的 Gradle 模块。不要只在 app 添加：service 可能定义在 feature、工程内 library 或单独发布的 API library。

读取 resolved dependency、version catalog、BOM 或 dependency constraint，取得该模块实际使用的 Retrofit 版本。Keeper 版本必须与 Retrofit 对齐；禁止凭记忆填写 `latest` 或硬编码与项目不同的版本。

## 自动配置

### Kotlin 或 Kotlin/Java 混合模块

确保模块启用 kapt：

```kotlin
plugins {
    kotlin("kapt")
}

dependencies {
    kapt("com.squareup.retrofit2:response-type-keeper:<retrofit-version>")
}
```

Groovy DSL：

```groovy
plugins {
    id 'org.jetbrains.kotlin.kapt'
}

dependencies {
    kapt "com.squareup.retrofit2:response-type-keeper:${retrofitVersion}"
}
```

优先复用 version catalog：

```toml
retrofit-response-type-keeper = {
    module = "com.squareup.retrofit2:response-type-keeper",
    version.ref = "retrofit"
}
```

```kotlin
kapt(libs.retrofit.response.type.keeper)
```

### 纯 Java 模块

```groovy
dependencies {
    annotationProcessor "com.squareup.retrofit2:response-type-keeper:${retrofitVersion}"
}
```

不要放入 `implementation`、`api`、`compileOnly` 或仅放根工程。处理器必须配置在定义 service 源码并实际执行编译的模块。

若工程统一使用 KSP，不得假设 kapt 注解处理器能用 `ksp(...)` 替换；先核对官方是否提供 KSP processor。没有时为相关模块保留 kapt，或者采用经过验证的等价生成方案。

## Maven library 责任

- service 接口定义在发布 library：在该 library 编译时运行 keeper，并确认生成规则进入最终 AAR/JAR consumer rules。
- service 接口定义在业务 app/feature：在对应业务模块运行 keeper；上游 Maven library 无法预生成这些业务模型规则。
- library 只调用 `Retrofit.create(Class)`、但不定义 service：不要无意义添加 keeper；配置应跟随 service 源码。

## 验证

1. 运行定义 service 模块的 clean 编译，避免把旧生成文件误认为成功。
2. 在 `build/generated`、`build/intermediates` 和最终 AAR/JAR 中定位 processor 生成的 ProGuard/R8 规则。
3. 抽查嵌套泛型、`Response<T>`、RxJava/Flow wrapper 和 Kotlin `suspend` 返回模型是否出现在生成规则中。
4. 对 app/consumer 执行 minified release 构建。
5. 运行至少一个请求解析路径；只编译成功不算通过。
6. 检查 mapping/usage，确认 DTO 没有被裁剪成导致 Retrofit 泛型失真的形式。

如果处理器未生成规则、生成规则未进入最终 consumer，或者无法执行 minified 请求路径，必须报告门禁未通过。
