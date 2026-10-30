# VariantComponentStub 变体/马甲包组件与路由接入参考

按 Android app 变体最终 `applicationId`(含 flavor 覆盖与 `applicationIdSuffix`)生成组件的空壳
Kotlin 子类，供 Manifest 的 `${applicationId}.Xxx` 占位注册使用；同时按变体生成
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

App 自身源码也可标注组件(包名不能等于 applicationId,否则同 FQCN 冲突需 `name` 改名),
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

## 组件约束(违反即构建期报错)

- public、顶层、可继承(open/abstract 之外不能 final)、非 sealed、无未绑定类型参数的 class。
- 无声明或继承的未实现抽象函数/属性。
- 构造:优先可访问无参构造,其次全参数默认值构造;库允许 public/protected,app 同模块额外允许 internal。
- `name` 非法标识符或 `R`/`BuildConfig` 保留名报错;模块内、跨库、app 与库间 stub 名称冲突报错,
  用 `@VariantComponentStub(name = "...")` 消歧。
- uri 重复报错并列出双方来源;每个组件配唯一 uri。

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
| 构造或抽象成员错误 | 按 KSP 提示补可访问无参/默认参数构造,实现继承的抽象成员 |
| 父类依赖不可见 | 公开父类所需依赖通过库 `api` 暴露 |
| app 源组件自冲突 | 源类包名等于 applicationId 时用 `name` 改名 |
| uri 重复 | 每组件唯一 uri,报错信息含双方来源 |

## 验证命令

```bash
./gradlew :app:assemble<Flavor><BuildType>   # 触发 scan/generate/ksp 全链路
# 产物:
#   build/generated/variant-component-stub/<variant>/kotlin/     库组件 stub
#   build/generated/ksp/<variant>/kotlin/                         app 组件 stub + RouterTable
#   build/intermediates/variant-component-stub/<variant>/index.txt  scan 汇总索引(v2)
```

运行 APK:Manifest 入口启动 → 变体 stub 承接 → URI 跳转落地页显示变体类名。
