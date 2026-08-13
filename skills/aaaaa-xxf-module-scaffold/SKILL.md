---
name: aaaaa-xxf-module-scaffold
description: 为 Android 项目新增或拆分 Android library/app/demo 模块时使用。覆盖 settings.gradle、build.gradle、发布配置、聚合 libs 和 demo 验证约定。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android 模块脚手架

## 模块边界原则

这个 skill 不只管“怎么建模块”，也管“模块之间怎么拆、怎么连、怎么报错”。

### 1. 模块初始化必须通过 `Initialization`

- 每个业务模块、基础能力模块、可选能力模块，只要存在启动期初始化动作，都必须显式实现并注册自己的 `Initialization`。
- 不允许把初始化逻辑散落在 `Application.onCreate()`、静态初始化块、`object init`、顶层属性副作用里。
- 不允许用“顺手访问一次就触发初始化”的隐式副作用代替显式注册。
- 初始化入口必须由宿主 root 统一聚合，不能让子模块自己偷偷完成全局初始化。
- 初始化失败要尽早暴露，报错信息必须明确指向缺失的初始化类型，例如：
  - `you must register ApplicationInitialization before accessing application`
  - `you must add ActivityResultInitialization`

### 2. 跨模块解耦必须通过 `ServiceProvider`

- 模块之间不能直接依赖对方的实现类、具体 repository、manager、viewmodel 或其他业务对象。
- 如果模块 A 需要对外暴露能力，模块 A 必须提供一个独立的 `a-provider` 契约层。
- `ServiceProvider` 接口、SPI 入口、对外服务协议必须放在 `a-provider` 或等价的契约模块里。
- 其他模块只能依赖 `a-provider`，通过接口协作，不能反向引用模块 A 的实现包。
- 模块 A 的实现模块只负责提供 `ServiceProvider` 的实现，宿主或聚合模块负责注册和收集。
- 如果一个功能需要被多个模块消费，优先拆成：
  - `xxx-provider`：契约、接口、模型、ServiceProvider 定义
  - `xxx-impl`：实现
  - `xxx-demo`：示例接入

### 3. 依赖必须有明确失败语义

- 所有依赖 DI 容器、Initialization、ServiceProvider、module 注册项的访问点，都必须在“未注册 / 未声明 / 未初始化”时立即失败。
- 不能用 `null` 静默降级、空对象吞错、返回空集合蒙混过关，除非业务明确允许可选能力。
- 对于必须项，错误应当是明确、可定位、可搜索的文案，而不是后续 NPE。
- 推荐错误格式：
  - `you must register XxxInitialization before accessing xxx`
  - `you must register xxx module before accessing xxx`
  - `you must register xxx provider before accessing xxx`

### 4. 示例约束

- 模块 A 需要初始化时，A 自己提供 `AInitialization : Initialization<Unit>`。
- 模块 A 对外提供服务时，A 自己提供 `AProvider : ServiceProvider` 或 `AServiceProvider`。
- 其他模块只依赖 `a-provider`，通过 `ServiceProvider` 接口读取能力。
- 宿主只负责在 root 入口里统一注册 `Initialization` 和收集 `ServiceProvider`，不直接耦合模块实现。

### 5. 推荐模块模板

#### `a-provider` 契约模块

- 放接口、契约数据、对外能力声明、`ServiceProvider` 标识。
- 只暴露给其他模块依赖，不放实现逻辑。

```kotlin
interface AServiceProvider : ServiceProvider {
    fun provideFoo(): Foo
}
```

#### `a-impl` 实现模块

- 放 `AInitialization`、`AServiceProvider` 实现、仓库、数据源、适配器。
- 初始化依赖必须通过 `Initialization` 注册到宿主 root。

```kotlin
class AInitialization(
    private val context: Context,
) : Initialization<Unit> {
    override suspend fun initialize() {
        // 声明容器对象，注册服务实现，完成 SDK 或模块初始化。
    }
}

class AProviderImpl : AServiceProvider {
    override fun provideFoo(): Foo = Foo()
}
```

#### 宿主聚合模块

- 宿主在 root 入口统一注册所有 `Initialization`。
- 宿主只聚合各模块导出的 `module`，不在 `startKoin` 里内嵌实现类。
- 宿主收集所有 `ServiceProvider`，然后按业务需要分发给下游模块。

```kotlin
// moduleA 由 a-impl 或 a-provider 模块对外导出，宿主只负责聚合。
val moduleA = module {
    single<Context> { applicationContext }
    single<AServiceProvider> { AProviderImpl() }
}

// moduleB 同理，由各自模块导出。
val moduleB = module {
    single<BServiceProvider> { BProviderImpl() }
}

startKoin {
    modules(moduleA, moduleB)

    registerInitialization(scope = initializationScope) {
        register<AInitialization> { AInitialization(get()) }
    }
}
```

#### 失败语义模板

- 任何读入口都必须先检查注册状态，再返回对象。
- 不允许返回 `null` 让调用方自行猜测。

```kotlin
val application: Application
    get() = checkNotNull(getKoin().getOrNull<Application>()) {
        "you must register ApplicationInitialization before accessing application"
    }

val aServiceProvider: AServiceProvider
    get() = checkNotNull(getKoin().getOrNull<AServiceProvider>()) {
        "you must register AServiceProvider before accessing a service"
    }
```

## 新增库模块

1. 在 `settings.gradle` include 新模块。
2. 创建 `build.gradle`，优先沿用邻近模块配置：
   - `com.android.library`
   - `kotlin-android`
   - 需要注解处理才加 `kotlin-kapt`
   - `compileSdk project.COMPILE_SDK_VERSION.toInteger()`
   - `minSdkVersion project.MIN_SDK_VERSION.toInteger()`
   - `targetSdkVersion project.TARGET_SDK_VERSION.toInteger()`
   - JVM target 1.8
3. 设置唯一 `namespace`。
4. 发布库补齐 `ext` 发布字段并按层级 `apply from: '../publish_maven.gradle'`。
5. 如属于核心聚合能力，同步 `libs/build.gradle`。
6. 加 demo/sample 时放在模块下或 `optional` 对应目录，demo 不发布。

## 依赖规则

- 公共 API 暴露的依赖才用 `api`。
- 内部实现依赖用 `implementation`。
- 可选宿主依赖、图片引擎、MLKit、FFmpeg、微信 SDK 等优先 `compileOnly`，避免强绑宿主。
- `optional/*` 不应反向污染核心库。

## 验证

新模块至少运行：

```bash
./gradlew :new_module:assembleDebug
```

如果加入 `libs`，再运行：

```bash
./gradlew :libs:assembleDebug
```
