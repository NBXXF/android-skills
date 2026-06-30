---
name: xxf-aaa-multi-module-structure
description: Android 多模块工程结构设计规则。用于新建工程、单体拆分、多模块重构、模块职责归类、app/feature/data/core/domain/optional/demo 等模块分层、命名和依赖方向判断。
---

# Android 多模块工程结构

## 先判断工程类型

1. 先读取 `settings.gradle` / `settings.gradle.kts`、根 `build.gradle`、`gradle.properties` 和现有模块目录。
2. 区分目标是业务 app、可发布 library 集合、SDK、demo/sample 工程，还是混合工程。
3. 优先延续现有模块命名、Gradle 插件、版本管理和发布方式；没有现有规则时再按本 skill 建议建立结构。
4. 如果涉及新增模块落地，继续读取 `xxf-aaa-module-scaffold`。
5. 如果涉及公共 API、optional、聚合库或发布边界，继续读取 `xxf-aaa-coding-arch` 和 `xxf-aaa-risk-gate`。

## 推荐结构树

优先使用目录分组式结构，适合新工程和需要长期演进的业务 app。默认包含 `app`、`feature`、`data`、`core`；`domain` 和 `optional` 按复杂度和团队约束选择性引入。

```text
project-root/
  app/
  feature/
    login/
    home/
    profile/
  data/
    user/
    order/
  core/
    common/
    ui/
    network/
    database/
    analytics/
    permission/
    logging/
  optional/
    wechat/
    payment/
    image-loader/
  domain/
    user/
    order/
  demo/
  sample/
```

对应 Gradle path 示例：

```text
:app
:feature:login
:data:user
:core:network
:optional:wechat
:domain:user
```

如果既有工程已经使用扁平模块名，继续保持一致，不要中途混用两套结构：

```text
project-root/
  app/
  feature-login/
  feature-home/
  data-user/
  core-common/
  core-ui/
  core-network/
  optional-wechat/
  domain-user/
  demo/
```

## 推荐分层

- `app`：最终应用壳，负责启动、导航装配、依赖注入入口、渠道配置和应用级资源。
- `feature-*`：业务功能入口，承载页面、交互流程和功能级 ViewModel；可直接依赖 data，也可通过可选 domain 层访问业务用例。
- `core-*`：跨业务复用能力，例如 common、ui、network、database、analytics、permission、logging。
- `data-*`：仓储、数据源、DTO、缓存、网络映射和数据模型；向 feature 或 domain 提供数据能力。
- `domain-*`：可选层。仅在业务规则复杂、多个 feature 复用用例、ViewModel 需要明显瘦身时引入；放 use case、领域模型和纯业务规则。
- `core-ui`：设计系统、通用 View/Compose 组件、主题、资源和 UI 工具；不要默认创建独立顶层 `ui-*`。
- `demo` / `sample-*`：验证入口和用法示例，不作为 library 的生产依赖。
- `optional-*`：可选三方 SDK 或宿主能力适配，避免污染核心模块。
- `libs` / `bom` / `catalog`：只在工程已有聚合或版本发布需要时保留，不为方便引用随意新增。

## 依赖方向

- `app` 可以依赖 feature、core、data 装配模块；feature 不依赖 app。
- 简单场景使用 `feature -> data -> core`；不要为了形式引入 domain。
- 复杂场景使用 `feature -> domain -> data -> core`；domain 表达业务用例，data 提供 repository 和数据源实现。
- feature 之间默认不互相依赖，共享能力下沉到 domain、data 或 core。
- domain 不依赖 feature、app、Android UI 实现；是否依赖 data 按工程现有架构保持一致。
- core 模块之间保持单向依赖；出现环时拆出更小的 `core-*` 或移动抽象。
- optional 只能被需要该能力的模块显式依赖；核心库不要为了 demo 或某个宿主强依赖 optional。
- demo/sample 可以依赖被演示模块，但被演示模块不得依赖 demo/sample。

## 命名规则

- 一个工程内统一使用目录分组式或扁平模块式，不要混用。
- 模块名使用小写 kebab 或现有工程惯例，例如 `feature-login`、`core-network`、`data-user`。
- Gradle path 保持语义清晰，例如 `:feature:login` 或 `:feature-login`，不要混用两套风格。
- 包名按职责分层，避免把 app 包名直接复制到所有 library 模块。
- 公开 library 的 `namespace`、Maven 坐标、artifactId 必须稳定且与职责一致。
- 模块名不要用 `common2`、`new-lib`、`temp`、`base2` 这类过渡命名。

## 拆分流程

1. 先画出现有依赖图：模块、包、主要类、资源、Manifest、三方 SDK、发布产物。
2. 识别稳定边界：公共 API、可独立验证的功能、可选能力、跨业务通用能力。
3. 先拆 feature/data/core 的稳定边界；只有业务规则复杂或多 feature 复用时再抽 domain。
4. 每拆一个模块就更新 settings、Gradle 依赖、namespace、资源前缀和验证任务。
5. 保持可回滚的小步提交；跨多个公开库时先记录风险和兼容策略。

## 禁止事项

- 不要为了减少 Gradle 配置把所有能力塞进 `app` 或 `common`。
- 不要为了套分层模板强行创建空的 domain、data 或 core 模块。
- 不要让 feature 之间直接互相调用页面或 ViewModel。
- 不要把三方 SDK、图片引擎、支付、登录、分享等可选宿主能力强绑到核心库。
- 不要让 demo/sample 里的便捷代码进入生产 library。
- 不要在没有验证任务的情况下完成模块拆分。

## 验证

- 新增或拆分 library 后至少运行 `./gradlew :module:assembleDebug` 或更窄的编译任务。
- app 级结构调整后运行目标 app 的 assemble 或 compile 任务。
- 改动 Gradle 依赖暴露、发布坐标、Manifest provider、资源名、混淆规则时进入风险门禁。
- 如果拆分影响调用方源码，补充或更新最小用法示例、demo 或单测。
