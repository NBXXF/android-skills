# resource-encrypt

`resource-encrypt` 是一个面向 Android 业务模块的资源加密方案，目标是把 `assets/` 和 `res/raw/` 中指定的资源在构建期加密，运行时再通过统一 API 解密读取，尽量减少业务侧改造成本。

这套方案现在把“密码学实现”和“运行时接入”拆开了：

- `resource-encrypt-core` 只负责统一的加解密实现、口令解析和 Base64 编解码。
- `resource-encrypt-runtime` 只负责运行时资源读取入口、口令接入和解密调用，底层解密逻辑仍然复用 `core`。
- `resource-encrypt-plugin` 只负责构建期扫描、加密、生成常量类和任务编排。

这样做的好处是：

- 插件和 runtime 不再各自维护一套 AES/GCM 或 Base64 逻辑，减少链路分散带来的改坏风险。
- `core` 是纯 JVM 库，和 Android API 无关，能同时服务插件、runtime 和 demo。
- 以后如果要调整 key 解析、密钥派生或算法实现，只需要收口到 `core` 一处。

这个目录下当前拆成 5 个部分：

- `resource-encrypt-api`：公共接口和模型，只放对外可见的契约。
- `resource-encrypt-core`：纯 JVM 的统一加解密核心，收拢 Base64、口令派生和 AES/GCM 细节。
- `resource-encrypt-runtime`：运行时解密入口，负责读取加密后的 `assets` 和 `raw`，并对外暴露可复用的解密调用方式。
- `resource-encrypt-plugin`：Gradle 构建插件，负责扫描、加密、生成 key 常量类、接入构建流程。
- `demo/app-custom`、`demo/app-custom2`、`demo/app-random`：本地调试用 demo，分别演示 Gradle 回调、app 内 supplier 类和随机 key 生成。

## 构建要求

- `resource-encrypt-api`、`resource-encrypt-runtime`、`resource-encrypt-plugin` 当前都按 Java 11 / Kotlin JVM 11 编译。
- 业务工程如果没有启用 Gradle toolchain 自动下载，构建这些模块时需要本机可用的 JDK 11。
- 业务源码本身不需要升级到 Java 11 语法，只要宿主 Android 工程的 Gradle/AGP 环境能正常加载插件即可。

## 一、快速开始

如果业务要接入远程插件，通常只需要做三件事：

1. 在根工程 `settings.gradle` 的 `pluginManagement` 中加入插件仓库。
2. 在业务 app 模块里应用 `com.xxf.resource-encrypt` 插件。
3. 只引入 `resource-encrypt-runtime`，它已经通过 `api` 依赖透出了 `resource-encrypt-api` 和 `resource-encrypt-core`。

### 1. 配置插件仓库

如果你使用远程发布版本，在根工程 `settings.gradle` 中确保能解析到插件 marker 和 Maven 产物。下面是推荐写法：

```groovy
pluginManagement {
    repositories {
        mavenLocal()
        maven { url 'https://maven.aliyun.com/nexus/content/repositories/google' }
        maven { url 'https://maven.aliyun.com/nexus/content/groups/public' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        mavenLocal()
        maven { url 'https://maven.aliyun.com/nexus/content/repositories/google' }
        maven { url 'https://maven.aliyun.com/nexus/content/groups/public' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        google()
        mavenCentral()
    }
}
```

> 说明：
> - 本仓库当前插件 id 是 `com.xxf.resource-encrypt`。
> - 远程发布版本与 `resource-encrypt-api`、`resource-encrypt-runtime` 保持同一版本号，当前示例版本是 `6.0.0.4-SNAPSHOT`。
> - 如果你在公司内部仓库里发布，请把上面的 Maven 地址替换成你们实际的发布仓库地址。

### 2. 在业务模块中应用插件

```groovy
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
    id 'com.xxf.resource-encrypt' version '6.0.0.4-SNAPSHOT'
}
```

> 说明：
> - 这个插件只对 Android `application`、`library` 和 `dynamic-feature` 模块生效。
> - 纯 JVM 模块不会触发资源扫描和加密流程。
> - 如果你还在用旧的 `com.nbxxf.resource-encrypt`，需要切换到新的 `com.xxf.resource-encrypt`。

### 3. 引入运行时依赖

业务 app 模块至少需要引入运行时库：

```groovy
dependencies {
    implementation 'com.NBXXF.xxf_android:resource-encrypt-runtime:6.0.0.4-SNAPSHOT'
}
```

如果你要使用 `keyGeneratedClassName` 生成 `BuildConfig` 类，或者通过 `keySupplier { ... }` / `keySupplierClassName` 自定义构建期密钥，只需要引入 `resource-encrypt-runtime`：

```groovy
dependencies {
    implementation 'com.NBXXF.xxf_android:resource-encrypt-runtime:6.0.0.4-SNAPSHOT'
}
```

> 说明：
> - `runtime` 提供 `assets.open(..., password, encryptedAssets)` 和 `resources.openRawResource(..., password, encryptedRaw)`，内部会先根据生成的目标键判断是否需要解密，不命中时直接按明文资源读取。
> - `runtime` 已经通过 `api` 依赖透出了 `ResourceEncryptKeyRequest`、`ResourceEncryptKeySupplier`、`ResourceCryptoManager`，业务侧无需单独再依赖 `resource-encrypt-api` 或 `resource-encrypt-core`。
> - 如果你不生成 key 常量类，而是自己在运行时直接传字符串密码，`runtime` 也可以独立使用。

### 为什么 `core` 里优先用 Kotlin 标准库 Base64

`resource-encrypt-core` 当前优先使用 `kotlin.io.encoding.Base64`，而不是 `java.util.Base64`，原因很直接：

- `java.util.Base64` 要求 Android API 26，和 `minSdk 23` / 低版本兼容目标冲突。
- `core` 的职责只是纯 JVM 密码学实现，不需要额外引入 Android 依赖。
- Kotlin 标准库自带的 Base64 能满足“纯 JVM 库 + 兼容 Android 8 以下 + 只做 Base64”的场景。

如果后续你更希望把 Base64 实现换成第三方纯 Java 依赖，也可以只替换 `core` 内部实现，插件和 runtime 不需要跟着改协议。

## 二、初级 Demo 配置

下面是一套适合初次接入的完整配置。目标是先把“扫描 -> 加密 -> 生成常量类 -> 运行时读取”这条链路跑通，不需要一次性理解全部字段。

```groovy
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
    id 'com.xxf.resource-encrypt' version '6.0.0.4-SNAPSHOT'
}

android {
    namespace 'com.example.app'
    compileSdk 36

    defaultConfig {
        applicationId 'com.example.app'
        minSdk 24
        targetSdk 36
    }
}

dependencies {
    implementation 'com.NBXXF.xxf_android:resource-encrypt-runtime:6.0.0.4-SNAPSHOT'
}

resourceEncrypt {
    enabled.set(true) // 总开关，关闭后插件不参与加密流程。
    moduleId.set('example-app') // 模块标识，建议固定且唯一。

    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
        // 如果要自定义构建期密钥来源，优先使用 keySupplier { ... }。
    }

    assets {
        encryptAsset('config/secret-demo.json') // 相对 src/main/assets 的路径。
    }

    raw {
        encryptRaw('local_demo_payload.json') // 相对 res/raw 的路径。
    }

    output {
        failOnCollision.set(true) // 同一输出路径发生冲突时直接失败。
    }

    verify {
        failOnPlaintextLeak.set(true) // 校验输出是否仍然是明文。
        dryRun.set(false) // true 时只做扫描和报告，不实际写出加密结果。
    }
}
```

## 三、高级配置

#### 示例 1：更完整的初级配置

这套配置适合先在 demo 或业务模块里做第一次接入。

```groovy
resourceEncrypt {
    enabled.set(true)
    moduleId.set('example-app')

    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
    }

    assets {
        encryptAsset('config/secret-demo.json')
    }

    raw {
        encryptRaw('local_demo_payload.json')
    }
}
```

#### 示例 2：自定义 key 生成器

如果你希望直接在 Gradle 里配置密钥，推荐优先使用 `keySupplier { ... }`。
如果同时配置了 `keySupplierClassName`，实际执行时仍以 `keySupplierClassName` 为准。
`keySupplier { ... }` 是纯回调路径，不需要也不应该解析业务模块的 compileClasspath。

```groovy
resourceEncrypt {
    enabled.set(true)
    moduleId.set('example-app')

    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
        keySupplier { request ->
            java.security.MessageDigest.getInstance('SHA-256')
                .digest("demo-secret:${request.applicationId}:${request.variantName}".getBytes('UTF-8'))
        }
    }

    assets {
        encryptAsset('config/secret-demo.json')
    }

    raw {
        encryptRaw('local_demo_payload.json')
    }
}
```

#### 示例 3：使用 `keySupplierClassName`

如果你希望把 key 生成逻辑放在 app 自己的源码里，仍然可以实现 `ResourceEncryptKeySupplier`。
这条路径的实际优先级高于 `keySupplier { ... }`。
这条路径才需要构建期 classpath，因为插件要反射加载你的 supplier 类。

```groovy
resourceEncrypt {
    enabled.set(true)
    moduleId.set('example-app')

    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
        keySupplierClassName.set('com.example.app.encrypt.DemoKeySupplier')
    }

    assets {
        encryptAsset('config/secret-demo.json')
    }

    raw {
        encryptRaw('local_demo_payload.json')
    }
}
```

#### 示例 4：多资源白名单

支持通配符，也支持 `raw-qualifier` 目录。

```groovy
resourceEncrypt {
    enabled.set(true)
    moduleId.set('example-app')

    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
    }

    assets {
        encryptAsset('config/*.json')
        encryptAsset('feature/**/secret-*.json')
    }

    raw {
        encryptRaw('local_demo_payload.json')
        encryptRaw('zh-rCN', 'welcome_text.json')
        encryptRaw('en-rUS', 'welcome_text.json')
    }
}
```

#### 示例 5：只做扫描和报告

适合先检查白名单是否命中、有没有明文泄漏，不急着真正输出加密文件。

```groovy
resourceEncrypt {
    enabled.set(true)
    moduleId.set('example-app')

    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
    }

    assets {
        encryptAsset('config/secret-demo.json')
    }

    raw {
        encryptRaw('local_demo_payload.json')
    }

    verify {
        dryRun.set(true)
        failOnPlaintextLeak.set(true)
    }
}
```

### 3.1 高级配置建议

1. `moduleId` 尽量稳定，不要直接用临时字符串。
2. 如果只是想在 Gradle 里直接写密钥，推荐使用 `keySupplier { ... }`，它不会触发业务模块 compileClasspath 解析。
3. `keySupplierClassName` 仍然支持，而且实际优先级更高，但会把实现类编进 apk，并要求构建期 classpath 可见，建议只在必须复用业务代码时使用。
4. `keyGeneratedClassName` 建议放到固定包下，例如 `com.xxx.app.generated`。
5. `assets` 和 `raw` 白名单先从少量资源开始，不建议一次性全量加密。
6. `verify.failOnPlaintextLeak` 建议保持开启，避免漏配导致产物仍是明文。
7. `dryRun` 适合在第一次接入时先跑一遍，确认白名单和冲突情况。

## 四、构建期配置说明

`resourceEncrypt { ... }` 是插件的主配置入口，下面按字段逐个说明。

### 1. `enabled`

```groovy
enabled.set(true)
```

- 类型：`Boolean`
- 默认值：`true`
- 作用：总开关。
- 说明：关闭后，扫描、加密、校验、key 常量类生成都会跳过，插件会清理已生成的输出。

### 2. `moduleId`

```groovy
moduleId.set('example-app')
```

- 类型：`String`
- 默认值：`project.path`
- 作用：构建期密钥生成上下文的一部分。
- 建议：使用稳定、可读、且在业务范围内唯一的值。
- 说明：如果你不显式配置，插件会默认使用当前 Gradle 项目路径，例如 `:app` 或 `:optional:resource-encrypt:demo:app-custom`。

### 3. `key { ... }`

`key` 用于描述构建期密钥的生成方式。

#### `keyGeneratedClassName`

```groovy
keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
```

- 类型：`String`
- 作用：让插件在构建期生成一个 Java 常量类。
- 生成内容：`ResourceEncryptedBuildConfig`，包含密钥 Base64，以及当前变体命中的 `encryptedAssets` / `encryptedRaw` 数组
- 生成位置：`build/generated/source/resourceEncryptBuildConfig/<variant>/...`
- 适用场景：业务希望在运行时通过固定类名直接读取密钥常量。
- 要求：
  - 类名必须是完整包名。
  - 类需要在 app 编译阶段可见。
- 生成后的类会放进业务源码集，供业务直接引用常量。

#### `keySupplier`

```groovy
key {
    keySupplier { request ->
        java.security.MessageDigest.getInstance('SHA-256')
            .digest("demo-secret:${request.applicationId}:${request.variantName}".getBytes('UTF-8'))
    }
}
```

- 类型：回调
- 参数：`ResourceEncryptKeyRequest`
- 返回值：原始 key 字节，长度必须是 16、24 或 32。
- 作用：让你直接在 Gradle 里配置密钥，不再额外生成一个会打进 apk 的实现类。
- 适用场景：
  - 密钥需要跟 `applicationId`、`variantName`、`versionCode`、`moduleId` 等构建上下文绑定。
  - 你希望密钥逻辑留在 `build.gradle`，不额外引入业务类。
- 说明：
  - 这个回调会在 Gradle 配置阶段执行一次，输出会作为 key material 参与后续任务。
  - 这条路径不会去解析业务模块的 compileClasspath。
  - 这是推荐的第一入口；如果同时配置了 `keySupplierClassName`，实际执行时仍以 `keySupplierClassName` 为准。

#### `keySupplierClassName`

```groovy
key {
    keySupplierClassName.set('com.example.app.encrypt.DemoKeySupplier')
}
```

- 类型：`String`
- 作用：让插件在构建期调用你自定义的密钥提供器。
- 接口要求：实现 `com.xxf.resource.encrypt.api.ResourceEncryptKeySupplier`
- 调用方式：插件会通过构建期 classpath 反射实例化该类，并调用 `provide(ResourceEncryptKeyRequest)`
- 适用场景：
  - 你需要把密钥生成逻辑放进 app 源码或业务模块里复用。
  - 你确实需要一个可编译、可测试的供应器类，而不是直接写在 Gradle 脚本里。
- 要求：
  - 需要 public 无参构造函数。
  - 返回值必须是 16、24 或 32 字节，否则构建会失败。
- 优先级：
  - `keySupplierClassName` 是实际执行时优先级最高的入口。
  - 如果同时配置了 `keySupplier` 和 `keySupplierClassName`，插件会优先使用 `keySupplierClassName`。
  - 这条路径会读取变体 compileClasspath 并反射加载类。

### 4. `assets { ... }`

`assets` 配置加密白名单，目标是 `src/main/assets` 以及各个 flavor/buildType/variant sourceSet 下的 `assets` 目录。

#### `encryptAsset(path)`

```groovy
assets {
    encryptAsset('config/secret-demo.json')
    encryptAsset('config/*.json')
}
```

- 类型：方法
- 参数：`path`
- 作用：把指定 `assets` 文件加入加密白名单。
- 路径规则：
  - 相对 `assets` 根目录。
  - 支持 glob。
  - 路径分隔符统一按 `/` 处理。
- 例子：
  - `config/secret-demo.json`
  - `config/*.json`
  - `**/*.json`

### 5. `raw { ... }`

`raw` 配置加密白名单，目标是 `res/raw` 和 `res/raw-*` 目录。

#### `encryptRaw(path)`

```groovy
raw {
    encryptRaw('local_demo_payload.json')
}
```

- 类型：方法
- 参数：`path`
- 作用：加密 `res/raw` 下的文件。
- 路径规则：
  - 相对当前 `raw` 目录。
  - 支持 glob。
  - 适合普通 `res/raw` 资源。

#### `encryptRaw(qualifier, path)`

```groovy
raw {
    encryptRaw('zh-rCN', 'local_demo_payload.json')
}
```

- 类型：方法
- 参数：
  - `qualifier`：`raw-*` 后缀
  - `path`：目录内相对路径
- 作用：加密带 qualifier 的 `raw` 资源。
- 目录映射：
  - `encryptRaw('zh-rCN', 'a.json')` 对应 `res/raw-zh-rCN/a.json`
  - `encryptRaw('night', 'b.json')` 对应 `res/raw-night/b.json`
- 说明：如果你不传 `qualifier`，会匹配普通 `res/raw`。

### 6. `output { ... }`

`output` 控制加密结果的冲突行为和输出策略。

#### `failOnCollision`

```groovy
output {
    failOnCollision.set(true)
}
```

- 类型：`Boolean`
- 默认值：`true`
- 作用：当多个 source set 命中同一个输出目标时是否直接失败。
- 说明：
  - 开启后，一旦发现冲突，构建会失败，避免资源被静默覆盖。
  - 关闭后，后扫描到的资源会覆盖先扫描到的资源。

#### `preserveFileName`

```groovy
output {
    preserveFileName.set(true)
}
```

- 类型：`Boolean`
- 默认值：`true`
- 当前状态：预留字段，当前版本未进入输出路径计算逻辑。
- 说明：建议先保持默认值，不要依赖它做业务行为判断。

#### `preserveExtension`

```groovy
output {
    preserveExtension.set(true)
}
```

- 类型：`Boolean`
- 默认值：`true`
- 当前状态：预留字段，当前版本未进入输出路径计算逻辑。

#### `preserveRelativePath`

```groovy
output {
    preserveRelativePath.set(true)
}
```

- 类型：`Boolean`
- 默认值：`true`
- 当前状态：预留字段，当前版本未进入输出路径计算逻辑。

> 说明：
> - 上面三个 `preserve*` 字段目前是扩展入口，便于后续演进输出路径策略。
> - 当前版本真正起作用的输出行为，仍以 source relative path 和 `raw` qualifier 生成目录为准。

### 8. `verify { ... }`

`verify` 控制构建期校验行为。

#### `failOnPlaintextLeak`

```groovy
verify {
    failOnPlaintextLeak.set(true)
}
```

- 类型：`Boolean`
- 默认值：`true`
- 作用：检查加密结果是否仍然和明文完全一致。
- 说明：开启后，可以尽早发现“没有真正加密”的问题。

#### `dryRun`

```groovy
verify {
    dryRun.set(false)
}
```

- 类型：`Boolean`
- 默认值：`false`
- 作用：是否只扫描并生成报告，不实际输出加密文件。
- 适用场景：
  - 想先检查白名单配置是否正确。
  - 想预览会命中的资源列表。
  - 想在不改动产物的情况下排查冲突。

## 五、自定义 key 生成

如果业务不想使用插件默认生成的随机 key，推荐先通过 `keySupplier { ... }` 直接在 Gradle 里配置密钥。
如果你需要把密钥生成逻辑放进业务源码里，再使用 `keySupplierClassName`。
如果两者同时配置，实际执行时仍以 `keySupplierClassName` 为准。

### 1. 直接在 Gradle 里配置 key

```groovy
resourceEncrypt {
    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
        keySupplier { request ->
            java.security.MessageDigest.getInstance('SHA-256')
                .digest("demo-secret:${request.applicationId}:${request.variantName}:${request.moduleId}".getBytes('UTF-8'))
        }
    }
}
```

### 2. 自定义 supplier 接口

```kotlin
package com.example.app.encrypt

import com.xxf.resource.encrypt.api.ResourceEncryptKeyRequest
import com.xxf.resource.encrypt.api.ResourceEncryptKeySupplier
import java.security.MessageDigest

class DemoKeySupplier : ResourceEncryptKeySupplier {
    override fun provide(request: ResourceEncryptKeyRequest): ByteArray {
        val seed = buildString {
            append(request.applicationId)
            append(':')
            append(request.variantName)
            append(':')
            append(request.moduleId)
            append(':')
            append(request.appVersionCode)
        }

        // 必须返回 16 / 24 / 32 字节。
        return MessageDigest.getInstance("SHA-256")
            .digest(seed.toByteArray())
            .copyOf(32)
    }
}
```

### 3. 绑定到插件配置

```groovy
resourceEncrypt {
    key {
        keyGeneratedClassName.set('com.example.app.generated.ResourceEncryptedBuildConfig')
        keySupplierClassName.set('com.example.app.encrypt.DemoKeySupplier')
    }
}
```

### 4. `ResourceEncryptKeyRequest` 参数说明

构建期回调会拿到下面这些字段：

- `applicationId`：当前变体的 applicationId，例如 `com.example.demo`。
- `variantName`：当前变体名，例如 `debug`、`release`。
- `flavorName`：当前 flavor 名，可能为空，例如 `free`、`paid`。
- `channelName`：当前实现中与 flavor 名保持一致，可能为空，例如 `huawei`、`xiaomi`。
- `channelGroup`：当前实现中为空，保留字段，后续可用于 `official`、`partner` 这类分组场景。
- `appVersionCode`：当前版本号，例如 `10204`。
- `appVersionName`：当前版本名，例如 `1.2.4`。
- `moduleId`：`resourceEncrypt.moduleId` 配置值或默认 `project.path`，例如 `:app`。

### 5. 生成的 key 常量类

如果你配置了 `keyGeneratedClassName`，插件会在构建期生成一个类似下面的 Java 类：

```java
/**
 * NBXXF resource-encrypt 自动生成，请不要手动修改。
 */
public final class ResourceEncryptedBuildConfig {
    public static final String[] encryptedAssets = new String[] {
        // asset 的格式固定为 asset:<relativePath>，例如 asset:config/secret-demo.json。
        "asset:config/secret-demo.json"
    };
    public static final String[] encryptedRaw = new String[] {
        // 没有 qualifier 时，中间位保留为空，因此会出现 raw::xxx 这种稳定键。
        // 例如 local_demo_payload.json 的目标键就是 raw::local_demo_payload.json。
        "raw:zh-rCN:welcome.json"
    };
    public static final String KEY_BASE64 = "...";

    private ResourceEncryptedBuildConfig() {
    }
}
```

业务侧可以直接读取它的常量并拿到运行时解密所需的密钥信息。

其中：

- `encryptedAssets` 表示当前变体最终命中的 `assets` 目标键清单。
- `encryptedAssets` 的键格式固定为 `asset:<relativePath>`，例如 `asset:config/secret-demo.json`。
- `encryptedRaw` 表示当前变体最终命中的 `raw` 目标键清单。
- `raw` 的键格式会保留 qualifier 占位：没有 qualifier 时是 `raw::<relativePath>`，例如 `raw::local_demo_payload.json`；有 qualifier 时是 `raw:<qualifier>:<relativePath>`，例如 `raw:zh-rCN:welcome.json`。
- 两个数组为空时，表示当前变体没有加密任何对应类型的资源。
- 数组元素是稳定的 `targetKey()`，不是源文件绝对路径；业务侧只适合做排查和展示，不要依赖它作为业务逻辑输入。
- 数组顺序仅用于反映当前生成结果，不建议把顺序当成长期协议。

## 六、运行时读取方式

`resource-encrypt-runtime` 提供两个核心入口：

- `AssetManager.open(path, password, encryptedAssets)`
- `Resources.openRawResource(resId, password, encryptedRaw)`

它们都支持加密和未加密文件共存，内部会根据 `encryptedAssets` / `encryptedRaw` 自动判断是否进入解密流程。

### 1. 读取 `assets`

```kotlin
import com.xxf.resource.encrypt.runtime.open

val password = ResourceEncryptedBuildConfig.KEY_BASE64

assets.open("config/secret-demo.json", password, ResourceEncryptedBuildConfig.encryptedAssets).use { input ->
    val text = input.readBytes().toString(Charsets.UTF_8)
}
```

### 2. 读取 `res/raw`

```kotlin
import com.xxf.resource.encrypt.runtime.openRawResource

val password = ResourceEncryptedBuildConfig.KEY_BASE64

resources.openRawResource(
    R.raw.local_demo_payload,
    password,
    ResourceEncryptedBuildConfig.encryptedRaw,
).use { input ->
    val text = input.readBytes().toString(Charsets.UTF_8)
}
```

### 3. 口令解析规则

运行时 `password` 支持两种输入：

1. 直接传入可解码为 AES key 的 Base64 字符串。
2. 传入普通口令，运行时会先做 SHA-256，再派生出 32 字节 key。
3. `assets` 读取还需要传入当前变体生成的 `encryptedAssets`，只有命中 `asset:<relativePath>` 时才会走解密。

> 说明：
> - 如果你传的是 `ResourceEncryptedBuildConfig.KEY_BASE64`，运行时会直接按 Base64 key 处理。
> - 如果你传的是人为输入的密码字符串，运行时也可以工作，但需要确保构建期和运行期对同一套密码策略达成一致。

## 七、任务和产物

插件在每个 Android variant 上会注册一组任务，便于排查和调试：

- `scan<Variant>ResourceEncryptInputs`
- `generate<Variant>ResourceEncryptKey`
- `encrypt<Variant>Resources`
- `generate<Variant>ResourceEncryptBuildConfig`
- `verify<Variant>EncryptedResources`

常见产物位于：

- `build/intermediates/resourceEncrypt/<variant>/...`
- `build/generated/resourceEncrypt/<variant>/...`
- `build/generated/source/resourceEncryptBuildConfig/<variant>/...`
- `build/reports/resourceEncrypt/<variant>/...`

如果你想确认当前变体到底加密了哪些文件，可以直接看 report 文件。

## 八、资源匹配规则

### 1. `assets`

- 扫描范围：`src/main/assets` 以及各 source set 的 `assets`
- 配置方式：`encryptAsset(...)`
- 匹配规则：glob
- 目标路径：相对 `assets` 根目录

### 2. `raw`

- 扫描范围：`src/main/res/raw` 和 `src/main/res/raw-*`
- 配置方式：
  - `encryptRaw(path)`
  - `encryptRaw(qualifier, path)`
- 匹配规则：glob
- 目标路径：
  - 普通 raw：`res/raw/<path>`
  - 带 qualifier 的 raw：`res/raw-<qualifier>/<path>`

### 3. source set 优先级

插件会按下面顺序扫描并合并：

1. `main`
2. flavor source set
3. buildType source set
4. variant source set

如果 `failOnCollision` 关闭，后面的 source set 会覆盖前面的同名输出。

## 九、限制与边界

这一节专门说明插件当前能做什么、不能做什么，以及常见的构建失败如何定位。

### 1. 支持范围

- 仅支持 Android `application`、`library` 和 `dynamic-feature` 模块。
- 仅处理 `assets/` 和 `res/raw/`、`res/raw-*` 中的资源。
- 仅支持当前实现内的 `AES/GCM/NoPadding` 流程。
- 生成的 key 常量类是 Java 类，不是 Kotlin 类。

### 2. 配置约束

- `keyGeneratedClassName` 必须是完整包名形式的合法 Java 类名。
- `keySupplierClassName` 必须能在构建期 classpath 上被找到，并且有 `public` 无参构造函数。
- `keySupplierClassName` 返回的 key 必须是 16、24 或 32 字节，否则会直接失败。
- `preserveFileName`、`preserveExtension`、`preserveRelativePath` 当前仍是预留字段，不建议依赖它们做业务判断。

### 3. 冲突与失败

- `failOnCollision.set(true)` 时，只要多个 source set 命中同一个输出目标，构建就会失败。
- 发生冲突时，错误里应该能看到具体的 `sourceSet`、源文件路径、目标输出路径，便于直接定位是谁覆盖了谁。
- `GenerateKeyBuildConfigTask` 如果生成失败，会直接终止构建，不再回退成零 key。
- `ScanResourceInputsTask` 如果规则解析失败，会直接终止构建；仅仅是没有命中规则时，才保留为诊断信息。
- `failOnCollision.set(false)` 时，后扫描到的 source set 会覆盖前面的同名输出。
- `dryRun.set(true)` 时只做扫描和报告，不实际写出加密文件。
- `enabled.set(false)` 时插件会跳过加密流程，构建期增强也会一起关闭。
- `GenerateKeyMaterialTask` 只保留“直接生成随机 key”、“Gradle 回调生成 key”和“自定义 supplier 生成 key”三种模式，任一自定义来源失败都会直接终止构建。
- 如果没有配置 `keySupplier` 也没有配置 `keySupplierClassName`，随机 key 会在每次构建时重新生成，不会长期复用上一次的 `material.properties`。

### 4. 路径与匹配

- `assets` 路径是相对 `assets/` 根目录的路径。
- `raw` 路径是相对 `res/raw/` 或 `res/raw-*` 目录的路径。
- 路径分隔符统一按 `/` 处理。
- `assets` 和 `raw` 都支持 glob 匹配。
- `channelName`、`channelGroup` 属于构建上下文字段，可能为空，不要把它们当成固定值。

### 5. 排查建议

- 如果构建失败，优先看插件任务生成的 report 文件。
- 如果是冲突类问题，优先比对同一输出目标对应的多个输入文件。
- 如果是 key 生成类问题，优先确认 `keySupplierClassName` 是否在当前变体的编译 classpath 上可见；如果是 Gradle 回调问题，先确认 `keySupplier { ... }` 返回值是否符合 key 长度要求。
- 如果你只想先确认白名单和冲突，不想真正改写产物，先开 `dryRun`。

### 6. 常见报错示例

#### `ScanResourceInputsTask`

当资源没有命中白名单，或者规则解析失败时，`scan-report.tsv` 会记录详细诊断。
如果是规则解析失败，任务会直接失败；如果只是没有命中规则，会保留为诊断信息，不阻断构建。

示例：

```text
NO_MATCH	ASSET	main	/Users/xxf/project/app/src/main/assets/config/secret.json	config/secret.json		config/*.yaml || config/*.xml
NO_MATCH	RAW	free	/Users/xxf/project/app/src/free/res/raw-zh-rCN/welcome.json	welcome.json	zh-rCN	zh-rCN|welcome-*.txt
```

你可以直接从这几列看：

- `sourceSet`
- `sourceFile`
- `relativePath`
- `qualifier`
- `ruleSummary`

#### `EncryptResourcesTask`

当 `failOnCollision.set(true)` 触发冲突时，错误会把冲突来源展开。

示例：

```text
Found conflicting resource outputs:
- asset:config/secret.json
  sourceSet=main
  source=/Users/xxf/project/app/src/main/assets/config/secret.json
  output=/Users/xxf/project/app/build/generated/resourceEncrypt/debug/assets/config/secret.json
  relativePath=config/secret.json
  qualifier=
- asset:config/secret.json
  sourceSet=freeDebug
  source=/Users/xxf/project/app/src/freeDebug/assets/config/secret.json
  output=/Users/xxf/project/app/build/generated/resourceEncrypt/debug/assets/config/secret.json
  relativePath=config/secret.json
  qualifier=
```

重点看：

- `targetKey`
- `sourceSet`
- `source`
- `output`

#### `VerifyEncryptedResourcesTask`

如果输出还是明文，验证阶段会指出 report 行号、输入文件和输出文件。

示例：

```text
Encrypted output is identical to plaintext input at line 3 in /Users/xxf/project/app/build/reports/resourceEncrypt/debug/encrypt-report.tsv. sourceSet=main, targetKey=asset:config/secret.json, sourceFile=/Users/xxf/project/app/src/main/assets/config/secret.json, outputFile=/Users/xxf/project/app/build/generated/resourceEncrypt/debug/assets/config/secret.json
```

重点看：

- `line`
- `sourceSet`
- `targetKey`
- `sourceFile`
- `outputFile`

#### `GenerateKeyMaterialTask`

当 `keySupplier` 或 `keySupplierClassName` 生成的 key 长度不对，或者内部异常时，会明确告诉你当前上下文。
如果你配置了 `keySupplierClassName`，它失败后会直接终止构建，不再随机回退；`keySupplier` 也会按同样规则失败，不会悄悄降级成随机 key。

示例：

```text
[resource-encrypt-gradle-plugin] :app:generateDebugResourceEncryptKey: generate key material failed. keySupplierClassName=com.example.app.encrypt.DemoKeySupplier, variantName=debug, moduleId=example-app, applicationId=com.example.app, output=/Users/xxf/project/app/build/intermediates/resourceEncrypt/debug/key/material.properties
```

重点看：

- `keySupplierClassName`
- `variantName`
- `moduleId`
- `applicationId`
- `output`

### 7. 链路契约

这几个文件和格式是整条链路的硬约定，改之前必须同步改插件和 runtime：

- `material.properties`
  - `algorithm=<value>`
  - `keyBase64=<Base64 key>`
  - `status=<generated|custom|disabled>`
- `encrypt-report.tsv`
  - 新格式固定为 `type \t sourceSet \t targetKey \t sourceFile \t outputFile`
  - `VerifyEncryptedResourcesTask` 仍兼容旧的 3 列格式，但新产物只写 5 列
- 加密 payload
  - 前 12 字节是 IV
  - 后面是 AES/GCM 密文和认证标签
- `ResourceEncryptKeySupplier`
  - 必须返回原始 `ByteArray`
  - 不能返回 Base64 字符串
- `ResourceEncryptedBuildConfig`
  - `encryptedAssets` 和 `encryptedRaw` 记录本变体最终命中的 `targetKey()`，空数组表示当前没有命中对应类型
  - `KEY_BASE64` 提供运行时解密所需信息
  - 数组内容仅用于排查和展示，不建议把顺序或数量当成业务协议
  - 不建议再补 `byte[]` 常量字段，避免可变数组被误用

## 十、本地联调

如果你是在当前仓库里调试这套模块，推荐先把插件发布到本地 Maven，再跑 demo：

```bash
bash publish-local.sh
```

然后再执行 demo：

```bash
./gradlew :optional:resource-encrypt:demo:app-custom:assembleDebug \
  :optional:resource-encrypt:demo:app-custom2:assembleDebug \
  :optional:resource-encrypt:demo:app-random:assembleDebug
```

如果你只是想刷新本地发布产物和 demo 生成类，直接执行：

```bash
bash optional/resource-encrypt/refresh.sh
```

`publish-local.sh` 只负责把 `resource-encrypt-api`、`resource-encrypt-core`、`resource-encrypt-runtime`、`resource-encrypt-plugin` 发布到 `mavenLocal`，不会去跑整个大工程。

## 十一、补充说明

- 旧的 `resource-guard` 命名已经废弃，当前统一使用 `resource-encrypt`。
- 当前插件 id 已从 `com.nbxxf.resource-encrypt` 改为 `com.xxf.resource-encrypt`。
- `resource-encrypt-api`、`resource-encrypt-runtime`、`resource-encrypt-plugin` 三个模块都按统一发布配置发布。
- 如果你需要更深入的实现设计，可以参考同目录下的 `resource-encrypt-gradle-plugin-design.md`。
