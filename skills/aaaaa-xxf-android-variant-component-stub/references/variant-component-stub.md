# VariantComponentStub 变体/马甲包组件与路由接入参考

按 Android app 变体最终 `applicationId`(含 flavor 覆盖与 `applicationIdSuffix`)生成组件的变体
Kotlin 类（默认 EXTENDS 空壳继承，可选 COPY 实现拷贝），供 Manifest 的 `${applicationId}.Xxx` 占位注册使用；同时按变体生成
`uri → stub Class` 路由表，让共享业务代码以稳定 URI 访问组件，不感知马甲包差异。

架构收益:每个变体实际注册进 Manifest 的四大组件都在自己的 applicationId 包下,共享实现类
不进注册清单——多渠道注册面天然区分(详见 `store-compliance-differentiation.md`)。

组件可来自 app 源码、工程内 library，或带索引的 Maven AAR。适用于 Activity、Service、
BroadcastReceiver、ContentProvider 的共享实现(插件不检查 Android 组件继承体系，
正确组件类型与 Manifest 注册由宿主负责)。

发布坐标:`com.NBXXF.xxf_android:variant-component-stub-{annotation|processor|gradle-plugin}:<版本>`，
插件 ID `com.xxf.variant-component-stub`。**三件套必须同版本**。

## 整体链路(三段)

| 环节 | 载体 | 职责 |
|---|---|---|
| 声明 | 常量清单 + 注解 | 公共库集中声明 `const val` 路由常量，注解 `uri` 引用常量 |
| 生成 | 按变体 RouterTable | KSP app 模式汇总库索引与 app 组件，值是变体 stub Class |
| 注册/跳转 | 宿主 Application + `Router.instance` | 宿主批量注册，业务按 URI 执行 |

马甲包的本质矛盾:Manifest 用 `${applicationId}.Xxx` 占位,每个变体最终类名不同,
共享业务代码无法硬编码类引用;URI 路由用稳定键抹平变体差异。

## 第一步:公共库标注组件

公共库(library)**不应用**本 Gradle 插件,只接 KSP,三行依赖:

```groovy
plugins {
    id 'com.android.library'
    id 'org.jetbrains.kotlin.android'
    id 'com.google.devtools.ksp'
}

dependencies {
    // 注解仅编译期使用
    compileOnly 'com.NBXXF.xxf_android:variant-component-stub-annotation:<版本>'
    // 库模式生成组件索引,随 AAR/classes 发布
    ksp 'com.NBXXF.xxf_android:variant-component-stub-processor:<版本>'
    // 公开父类(如 AppCompatActivity)所属依赖必须 api 暴露给宿主
    api 'androidx.appcompat:appcompat:x.y.z'
}
```

路由常量清单:公共库集中声明,注解与业务查询复用同一常量,避免裸字符串散落:

```kotlin
package com.example.shared

object SharedRoutes {
    const val mainActivity = "app://main"
    const val playerService = "app://player"
}
```

组件标注(`uri` 必填、全 app 唯一、非空无空白;`name` 可选,默认沿用原类名):

```kotlin
@VariantComponentStub(uri = SharedRoutes.mainActivity, name = "MainActivity")
open class SharedMainActivity : AppCompatActivity() { ... }

@VariantComponentStub(uri = SharedRoutes.playerService)
open class PlayerService : Service() { ... }
```

注意:
- 库构建时生成索引类编译进产物;只加注解、未运行 processor 的库不会被发现。
- 公共库通常不重复注册原始组件,最终入口由 app 的 Manifest 声明。
- **Application 不要标注**——由宿主业务统一定义、不随变体改名,路由注册也在宿主完成。

## 第二步:宿主 app 接入插件与 Manifest 占位

```groovy
plugins {
    id 'com.android.application'
    id 'org.jetbrains.kotlin.android'
    id 'com.google.devtools.ksp'
    id 'com.xxf.variant-component-stub' version '<版本>'
}

dependencies {
    implementation project(':shared') // 或带组件索引的 Maven AAR
}
```

processor/annotation 依赖由插件自动注入(按插件 JAR 的 `Implementation-Version` 拼同版本
Maven 坐标),无需手写;需要自管时 `automaticallyAddProcessorDependency.set(false)` 后手动声明同版本依赖。

Manifest 以 `${applicationId}` 占位注册(占坑):

```xml
<application android:name="com.example.host.App"> <!-- 宿主自定义 Application,绝对类名 -->
    <activity android:name="${applicationId}.MainActivity" android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.MAIN" />
            <category android:name="android.intent.category.LAUNCHER" />
        </intent-filter>
    </activity>
    <activity android:name="${applicationId}.ExtraActivity" android:exported="false" />
    <service android:name="${applicationId}.PlayerService" android:exported="false" />
    <receiver android:name="${applicationId}.SyncReceiver" android:exported="false" />
    <provider android:name="${applicationId}.DataProvider"
        android:authorities="${applicationId}.provider" android:exported="false" />
</application>
```

构建后生成 `com.example.brand.MainActivity : com.example.shared.SharedMainActivity()` 等空壳子类。
插件不修改 Manifest;authorities、exported、权限由宿主按业务设置。

App 自身源码也支持两种 mode；源类与生成类不能同包同名，包名等于 applicationId 时用 `name` 改名，
由 KSP app 模式直接生成到 applicationId 包下。

### 马甲包矩阵(flavor / suffix)

```groovy
flavorDimensions 'brand'
productFlavors {
    brandA { dimension 'brand'; applicationId 'com.example.branda' }
    brandB { dimension 'brand'; applicationId 'com.example.brandb' }
}
buildTypes {
    debug { applicationIdSuffix '.debug' } // 同样参与 stub 包名推导
    release { minifyEnabled true }
}
```

同一套共享实现,每个变体各生成各的 stub 与路由表,Manifest 一份占坑全变体通用。

## 第三步:宿主 Application 批量注册路由(结合 di-android)

宿主依赖 `implementation 'com.NBXXF.xxf_android:di-android:<版本>'`,在自定义 Application 的
唯一 `startKoin` 入口直引生成的 RouterTable 批量注册(编译期直引,免反射、R8 可追踪):

```kotlin
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        startKoin {
            modules(module {
                routing {
                    RouterTable.routes.forEach { (uri, target) ->
                        if (Activity::class.java.isAssignableFrom(target)) {
                            val activityClass = target.asSubclass(Activity::class.java)
                            registerHandler(uri) { RoutingActivityHandler(activityClass) }
                        }
                    }
                }
            })
            initialization {
                register<ApplicationInitialization> { ApplicationInitialization(this@App) }
            }
        }
    }
}
```

导入:`com.nbxxf.kpower.di.initialization.initialization`、`com.nbxxf.kpower.di.routing.routing`、
`com.xxf.application.initializer.ApplicationInitialization`、
`com.xxf.di.android.routing.ui.handler.RoutingActivityHandler`、
`com.xxf.variant.component.generated.RouterTable`。

上例只注册 Activity;Service/Receiver/Provider/Application 不能当页面启动,仍保留在生成表中,
由业务按所需机制处理。不引入 di-android 时,业务也可直接消费
`RouterTable.routes` Map(`routes[SharedRoutes.mainActivity]` 取 Class 后自行 `Intent`)。

## 第四步:业务按 URI 跳转

任意依赖路由框架的业务模块在主线程调用,URI 引用常量而非裸字符串:

```kotlin
import com.nbxxf.kpower.di.routing.instance
import com.nbxxf.kpower.router.Router
import com.nbxxf.kpower.router.execute

val result = Router.instance.execute<Any?>(uri = SharedRoutes.mainActivity)
// RoutingResult.Success / Failure:按路由框架语义处理未找到、拒绝或启动失败
```

共享业务代码(公共库内)同样只写 URI,不感知 applicationId/flavor/suffix。

## 路由表

默认生成 `com.xxf.variant.component.generated.RouterTable.kt`(KSP app 阶段,需执行 app 编译):

```kotlin
public object RouterTable {
    @JvmField
    public val routes: Map<String, Class<*>> = java.util.Collections.unmodifiableMap(
        linkedMapOf(
            "app://main" to com.example.brand.MainActivity::class.java,
        ),
    )
}
```

- 同一 RouterTable 类名各变体不变,Class 值随 applicationId 改变;`routes` 不可修改。
- 路由表与业务常量清单是两个东西:前者插件按变体生成,后者业务自持;同名不冲突(不同包),
  同文件共用需 import 别名,建议命名错开。
- 每个生成的空壳 stub 注释携带该组件 URI 与路由表全名(KDoc 链接),可从任意 stub 跳到路由总表。
- 可配置输出:`variantComponentStub { output { routerConfig { className('com.example.generated.RouterTable.java') } } }`
  (`.kt`/`.java` 二选一);即使没有组件也生成空表。
- 插件仅生成映射,不强制依赖任何运行时路由框架。

## mode 参数与模式选择

`mode` 是每个组件的注解参数，不是 Gradle 全局开关。同一个公共库或 app 可以混用两种模式；
未填写时使用 `VariantComponentStubMode.EXTENDS`。

```kotlin
annotation class VariantComponentStub(
    val uri: String,
    val name: String = "",
    val mode: VariantComponentStubMode = VariantComponentStubMode.EXTENDS,
)
```

| 参数 | 默认值 | 含义 |
|---|---|---|
| `uri` | 必填 | 全 app 唯一、非空且无空白的稳定路由键；推荐引用公共 `const val` |
| `name` | `""` | 生成类的简单名；空白时沿用源类名，两种模式均生效 |
| `mode` | `EXTENDS` | `VariantComponentStubMode` 枚举，选择空壳继承或实现拷贝 |

| 比较项 | `EXTENDS`（默认） | `COPY` |
|---|---|---|
| 生成结果 | `class Variant : Host()` | `class Variant : 原来的父类()`，包含拷贝的实现 |
| 与源类关系 | 生成类是源类的子类 | 生成类与源类没有直接继承关系；原类保留 |
| 适用情况 | 组件可继承，希望共享原类实现 | final 组件，或明确需要独立的变体实现类 |
| 源类要求 | 可继承，不能有未实现的抽象成员 | 可以 final，但不能 abstract/sealed |
| 构造校验 | 必须能通过 `Parent()` 调用可访问构造器 | 构造原样拷贝，不执行 EXTENDS 的无参构造校验 |
| 源文件约束 | 可以在同文件标注多个组件 | 文件内只能有一个被标注组件 |
| 公共库消费 | 宿主能访问源类及公开父类依赖 | 宿主能编译拷贝文件用到的全部类型和 API |

两种模式都要求 public 顶层 class、非 sealed、无未绑定类型参数；`name` 和 `uri` 的查重规则一致。
库中的 EXTENDS 构造器允许 public/protected，app 同模块额外允许 internal；全部参数有默认值也视为可无参调用。
COPY 不会自动生成构造参数或注入依赖，Manifest 组件仍须满足实际 Android 创建机制的要求。

## COPY 模式

先按前文接入步骤配置 library 的 annotation/processor 与宿主插件，三件套使用同一版本。
以下两个文件分别放在公共库 `src/main/kotlin/com/example/shared/` 下，不要合并为一个组件示例大文件。

`SharedRoutes.kt`：

```kotlin
package com.example.shared

object SharedRoutes {
    const val copyActivity = "app://copy"
}
```

`SharedCopyActivity.kt`（默认 final，无需添加 `open`）：

```kotlin
package com.example.shared

import android.app.Activity
import com.xxf.variant.component.stub.annotation.VariantComponentStub
import com.xxf.variant.component.stub.annotation.VariantComponentStubMode

@VariantComponentStub(
    uri = SharedRoutes.copyActivity,
    name = "CopyActivity",
    mode = VariantComponentStubMode.COPY,
)
class SharedCopyActivity : Activity() {
    fun componentClass(): Class<*> = SharedCopyActivity::class.java
}
```

当最终 applicationId 为 `com.example.brand` 时，生成结果的核心代码如下（省略生成注释）：

```kotlin
package com.example.brand

import android.app.Activity

class CopyActivity : Activity() {
    fun componentClass(): Class<*> = CopyActivity::class.java
}
```

宿主在 `<application>` 内注册：

```xml
<activity android:name="${applicationId}.CopyActivity" android:exported="false" />
```

路由表中的 `routes[SharedRoutes.copyActivity]` 指向变体 `CopyActivity::class.java`，沿用现有 URI 注册/跳转流程。
COPY 生成类不能转换为 `SharedCopyActivity`；需要统一类型时使用共同的父类或公开接口。
外部文件的 `SharedCopyActivity::class`、显式 Intent 和字符串类名不会自动指向拷贝件。

### 源码处理规则

1. 按源文件拷贝，包含同文件的辅助声明；换到最终 applicationId 包，类名遵循 `name`。
2. 自身代码引用按标识符处理，包括 `this@X`、`X::class`、源类全限定引用及字符串模板表达式；
   字符串正文、注释、import 和其他限定类型名称保留。处理器使用词法扫描，并非完整的 Kotlin 符号重构器；
   有同名局部声明、遮蔽或复杂导入时应检查生成源码，避免把其他符号误当作自身引用。
3. 剥离组件注解，删除不再使用的注解/枚举 import；其他注解保留，`@file:...` 保持在 package 前。
   支持同行和全限定名注解的剥离；预处理器能处理别名不等于 KSP 组件发现已支持别名，接入示例使用普通导入。
4. `R`/`BuildConfig` 已有显式导入时保留，不根据组件子包覆盖导入；`android.R` 等全限定引用不补导入。
   无对应导入且检测到裸引用时补原包 import；通配导入保留原样。推荐显式导入真实 namespace 的资源类，
   不依赖插件推断 Android namespace。字符串模板表达式中的引用同样参与检测。

### COPY 使用边界

| 条件 | 接入要求 |
|---|---|
| 一文件一个标注组件 | COPY 文件不能同时放第二个 COPY 或 EXTENDS 标注组件；辅助声明会一起拷贝 |
| 名称冲突 | `name` 不能与同文件其他顶层声明同名；多个文件换包后也不能产生冲突 |
| 同包跨文件引用 | 正文里使用同包工具类、常量等时显式 import；只出现在被剥离注解参数中的路由常量无需为拷贝件导入 |
| 库可见性 | 库的 internal/private 跨文件成员不可供宿主访问；将所需能力改为公开 API 或采用 EXTENDS |
| 编译依赖 | 拷贝正文使用的第三方依赖必须对宿主编译可见，按 API 边界选择库 `api` 或宿主显式依赖 |
| 库源码载体 | 预处理源码编码后随索引注解进入库产物；单条索引常量限 65535 字节，包含编码开销，不能按原文件大小等同估算 |
| App 自身组件 | 同样支持 COPY，但源类与生成类不能同包同名；必要时用 `name` 改名 |
| Java 与多轮 KSP | 默认面向首轮可见的 Kotlin 源码，不承诺 Java 源码拷贝或后续轮次生成组件支持 |

COPY 会同时保留原始实现和生成实现；未使用的原类是否被裁剪由 R8 可达性决定。
本插件不自动迁移已有的反射/JNI/序列化规则；若业务按名称访问组件或成员，应核对变体类对应规则。
普通 Manifest 入口和生成路由表 Class 引用沿用已有 AGP/aapt 与 R8 规则，无需仅因选择 COPY 增加全局 keep。

### 验证步骤

1. 构建实际 app 变体，确认生成目录中的类包名为最终 applicationId，类名符合 `name`。
2. 库组件检查 `build/generated/variant-component-stub/<variant>/kotlin/`；
   app 自身组件检查 `build/generated/ksp/<variant>/kotlin/`，确认 COPY 类包含实现且不继承源类。
3. 检查 `RouterTable.routes` 指向生成类，Manifest 合并结果注册相同入口。
4. 构建启用 minify 的 release 变体，再运行组件入口和 URI 跳转；编译成功不能替代设备运行验证。

## 公共名称约束

- `name` 必须是合法简单类名，不能使用 `R`/`BuildConfig`；模块内、跨库和 app 与库间的冲突都会报错。
- 两种模式均使用全 app 唯一的 `uri`，不能用 mode 区分重复的路由键。
- app 源类与生成类不能同 FQCN，可用 `name` 改名。

## 混淆与边界

- Manifest 引用的 stub 使用 AGP/aapt 组件 keep 规则,插件不额外生成 consumer rules。
- 路由表与 Application 直引 stub Class,R8 可静态跟踪,**无需新增 keep 规则**。
- 父类名称不承诺不变;索引类编译进库产物,未开压缩的 APK 可能携带。
- 预混淆 AAR 若丢失索引类名、注解或父类名称,将无法消费。
- 目前只处理 KSP 首轮可见源码类;unitTest KSP 任务按库模式运行。

## 故障排查

| 现象 | 处理 |
|---|---|
| “索引版本不兼容,请使用同版本 annotation/processor 重新构建” | annotation/processor/gradle-plugin 版本劈叉:统一三件套版本,重新构建所有组件库并重新发布 AAR |
| 库组件生成数为 0 | 确认库构建运行了 processor(`ksp` 依赖),scan 日志“从编译类路径发现 N 个” |
| KSP 被跳过 | 检查 `enabled`、`automaticallyAddProcessorDependency` 与手动 `ksp` 依赖 |
| 构造或抽象成员错误 | 先检查 mode：EXTENDS 补可访问无参/默认参数构造并实现抽象成员；COPY 禁止抽象类，且仍须满足 Android 实例化要求 |
| 父类依赖不可见 | 公开父类所需依赖通过库 `api` 暴露 |
| app 源组件自冲突 | 源类包名等于 applicationId 时用 `name` 改名 |
| uri 重复 | 每组件唯一 uri,报错信息含双方来源 |
| COPY 文件包含多个标注组件 | 每个 COPY 组件拆到独立源文件 |
| COPY 正文找不到类型/资源/成员 | 检查 import、实际 namespace、跨模块可见性及宿主编译依赖 |
| COPY 索引常量超限 | 精简源文件、拆分辅助实现或使用 EXTENDS |
| COPY 转换为源类失败 | 使用共同父类/公开接口，或选 EXTENDS |

## 验证命令

```bash
./gradlew :app:assemble<Flavor><BuildType>   # 触发 scan/generate/ksp 全链路
# 产物:
#   build/generated/variant-component-stub/<variant>/kotlin/     库组件 stub
#   build/generated/ksp/<variant>/kotlin/                         app 组件 stub + RouterTable
#   build/intermediates/variant-component-stub/<variant>/index.txt  scan 汇总索引
```

运行 APK:Manifest 入口启动 → 变体 stub 承接 → URI 跳转落地页显示变体类名。
