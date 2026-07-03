---
name: aaaaa-xxf-coding-arch
description: Android/Kotlin 模块架构强制规范。新增、维护或重构 Android library/app/demo 模块时必须遵守；明确单个模块工程目录、包内分层、依赖方向、公共 API、optional、聚合 libs 和 demo/sample 边界。
---

# Android 模块架构约束

> 适用范围：新增模块、拆分模块、重构模块目录、跨层改动、维护可发布 library、公用 app/demo/sample 验证入口时必须遵守。

## 单模块工程结构

每个 Android 模块必须保持下面的工程骨架；缺少目录时先补齐再落代码。除非模块是纯 Gradle 聚合模块且没有源码，否则不得省略包内分层目录。

```text
{module}/
├── build.gradle
├── consumer-rules.pro              # 发布库按需提供
├── proguard-rules.pro              # app/demo 或需要混淆规则的库按需提供
└── src/
    ├── main/
    │   ├── AndroidManifest.xml
    │   ├── java/{package}/          # Kotlin 源码默认也放这里；已有 src/main/kotlin 时沿用
    │   │   ├── api/                 # Retrofit ApiService 接口定义
    │   │   ├── common/              # 当前模块内不属于一级分层的杂项代码
    │   │   ├── domain/
    │   │   │   ├── dto/             # 网络/跨进程/跨模块传输对象
    │   │   │   ├── po/              # 本地持久化对象
    │   │   │   ├── vo/              # 页面展示对象、UI State、UI Event
    │   │   │   └── mapper/          # DTO/PO/VO/DO 转换
    │   │   ├── repository/          # 数据读写：网络、数据库、缓存、文件、DataStore
    │   │   ├── service/             # 业务规则、跨 Repository 编排、领域状态流转
    │   │   ├── di/                  # DI 注册、路由注册、工厂、ServiceLocator 接入
    │   │   └── presentation/        # UI 层；当前无 UI 也保留该层级，后续页面统一落这里
    │   │       ├── page/            # Activity、Fragment、Dialog、Compose Screen
    │   │       ├── viewmodel/       # ViewModel、UI State、UI Event
    │   │       ├── adapter/         # RecyclerView/Pager Adapter、DiffCallback
    │   │       └── widget/          # 自定义 View、Compose 组件
    │   └── res/                     # layout、drawable、mipmap、values 等资源
    ├── test/java/{package}/         # 纯 JVM 单测
    └── androidTest/java/{package}/  # Instrumentation/UI 测试
```

## 分层职责

| 层 | 目录 | 职责 | 依赖方向 |
|---|---|---|---|
| api | `api/` | Retrofit ApiService 接口定义，只描述 HTTP 接口、请求方法、路径、参数和响应类型 | 依赖 domain/dto，不依赖 repository/service/presentation |
| common | `common/` | 当前模块内不属于 api/domain/repository/service/di/presentation 的杂项代码 | 不得承载业务主流程，不对外暴露公共 API |
| domain | `domain/` | `dto/po/vo/mapper`：传输对象、持久化对象、展示对象和模型转换 | 不依赖 UI；DTO/PO/VO 不依赖 repository/service |
| repository | `repository/` | 数据来源组合：网络、数据库、缓存、文件、DataStore | 依赖 api/domain/底层 SDK |
| service | `service/` | 业务规则与跨 repository 编排的唯一落点 | 依赖 repository/domain |
| di | `di/` | 模块内依赖注册、路由注册、工厂和可替换实现绑定 | 可依赖本模块其他层 |
| presentation | `presentation/` | Activity/Fragment/ViewModel/Adapter/View/Compose UI | 依赖 service/domain，不依赖 repository |
| res | `res/` | 资源文件；命名必须带模块语义前缀 | 被 presentation 或 Manifest 使用 |
| test | `test/` / `androidTest/` | 单测、集成测试、UI 测试 | 只验证公开行为和关键边界 |

## 强制规则

### 目录落点

- 新增 Kotlin 文件前必须先判断所属层级，并放入对应目录；不允许直接散落在 `{package}/` 根目录。
- 一个模块内不得自造 `core/`、`common/`、`base/`、`manager/`、`utils/` 等平行分层承载业务代码。
- 当前模块确实存在不属于一级分层的零散代码时，统一放入 `common/`，不得散落包根目录或另建平行目录。
- `common/` 只收纳当前模块内的适配、小型扩展、内部常量、临时兼容代码等杂项；一旦代码具备明确职责，必须迁回 api/domain/repository/service/di/presentation 对应层。
- 当前需求暂时用不到的层级也不得把职责挪到其他层；例如没有独立 service 时，不代表 ViewModel 可以直接访问 repository。
- 纯基础设施模块如果确实不适用 `presentation/service/repository`，必须只放与业务无关的能力，并在模块 skill 或任务说明中写明豁免原因。

### 依赖方向

- 单向依赖：`presentation → service → repository → api/domain`。
- 禁止 `Activity/Fragment/View/Adapter/Composable` 直接调用 `repository`、网络 SDK、数据库或文件存储。
- 禁止 `repository` 依赖 `presentation`、`ViewModel`、Android View 类型。
- Feature/模块之间不得直接依赖对方内部实现；跨模块能力通过 `di/` 注册的路由、服务入口或模块约定的公开协议获取，不能把 Retrofit ApiService 当业务公开入口。

### 业务逻辑归属

- 业务规则、权限组合、状态流转、多数据源编排、业务字段计算只能放 `service/`。
- `repository/` 只负责取数、存数、缓存和数据源选择，不做“是否允许”“如何展示”“下一步跳哪”的业务决策。
- 禁止用 `Manager`、`Tool`、`Utils`、`Helper`、`Handler`、`Processor`、`Center` 承载业务逻辑；出现这类命名时先判断是否应迁到 `service/`。
- 真正无业务含义的通用扩展和工具放基础模块或 `domain/mapper` 等明确位置，不塞进全局单例。

### 模型和数据

- 网络请求/响应对象放 `domain/dto/`，不要散落在 `api/` 或 `repository/`。
- 本地数据库、缓存、文件持久化对象放 `domain/po/`。
- 页面展示对象、UI State、UI Event 放 `domain/vo/`；不要直接把 DTO 给 UI 渲染。
- DTO、PO、VO、DO、BO 命名按 `aaaaa-xxf-model-naming-guidelines` 执行。
- 不同层模型优先显式转换，转换逻辑集中放 `domain/mapper/`。

### DI 与路由

- 依赖注入注册、工厂绑定、模块初始化注册统一放 `di/`。
- 模块路由注册、Router 表、路由到页面/服务的绑定也统一放 `di/`，不要放在 `api/`、`presentation/` 或包根目录。
- `api/` 只放 Retrofit ApiService，不放路由协议、Facade、Provider 或业务入口；具体注册和实现绑定由 `di/` 负责。

### UI 数据驱动

- UI 层不得硬编码业务集合：菜单、Tab、入口、Section、列表项、业务文案、图标、跳转 action 必须由 `service` 构建，`viewmodel` 暴露数据源，UI 循环渲染。
- 禁止在 UI 层写 `return 2`、固定多个入口按钮、按 `index == 0/1` 写业务分支。
- 固定布局骨架可以在 UI 层定义，但 cell、section、菜单项、入口数量必须来自数据源。

### 模块边界

- 只有可发布 library 模块建立 installable skill；demo/app/sample 只作为验证入口写入对应 library skill。
- 核心库不得依赖 `optional/*`；可选能力通过 optional library 单独发布。
- `libs` 是核心聚合库；新增/移除核心发布库时检查 `libs/build.gradle`。
- demo/sample 不反向成为 library 的依赖，也不定义公共 API。

### Gradle 依赖

- 公共 API 暴露的类型才使用 `api`。
- 内部实现使用 `implementation`。
- 宿主可选能力、三方 SDK、图片引擎、MLKit、FFmpeg、微信 SDK 等优先 `compileOnly`。
- 禁止为了 demo 方便把 optional 或 sample 依赖塞进核心库。

### 发布边界

- 发布库必须保持 `publishVersion`、`publishGroup`、`moduleName` 和 `publish_maven.gradle` 路径正确。
- 变更 Maven 坐标、依赖暴露、Manifest provider、资源名前缀时必须进入 `aaaaa-xxf-risk-gate`。

## 新增或重构模块检查清单

- [ ] 模块根目录包含 `build.gradle`、`src/main/AndroidManifest.xml`、源码包、`res/`、测试目录？
- [ ] 包内分层目录符合 `api / common / domain(dto/po/vo/mapper) / repository / service / di / presentation`？
- [ ] 新增文件没有散落在包根目录，也没有自造平行分层绕过标准目录？
- [ ] 不属于一级分层的当前模块杂项已统一放入 `common/`，且没有承载业务主流程？
- [ ] 依赖方向保持 `presentation → service → repository → api/domain`，无反向依赖和跨层跳跃？
- [ ] 业务逻辑全部落在 `service/`，没有用 Manager/Tool/Utils/Helper 等承载业务？
- [ ] DTO/PO/VO/Mapper 分别放在 `domain/dto`、`domain/po`、`domain/vo`、`domain/mapper`，展示模型和 UI State 未直接复用网络 DTO？
- [ ] DI 注册和路由注册都放在 `di/`，未散落到 `api/`、`presentation/` 或包根目录？
- [ ] UI 集合和业务内容由 Service/ViewModel 数据驱动，未写死条目数量、索引分支或固定入口？
- [ ] 跨模块调用通过 `di/` 注册的路由、服务入口或模块公开协议完成，未把 Retrofit ApiService 当业务入口，也未 import 对方内部实现？
- [ ] Gradle 的 `api`、`implementation`、`compileOnly` 使用符合依赖暴露边界？
- [ ] 发布库同步检查 `libs`、`publish_maven.gradle`、Manifest、资源名前缀和风险门禁？
