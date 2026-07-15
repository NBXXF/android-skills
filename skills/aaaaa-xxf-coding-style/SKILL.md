---
name: aaaaa-xxf-coding-style
description: Android 项目的 Android/Kotlin/XML/Gradle 编码规范。修改 Kotlin、资源、Manifest、Gradle 或发布配置时必须遵守；语言选择先按 aaaaa-xxf-language-selection 执行。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android 编码规范

## Kotlin

- 优先遵循当前文件风格，不做无关格式化。
- 新增源码和触达 Java 维护时，先按 `aaaaa-xxf-language-selection` 执行：默认使用 Kotlin，必要时把触达 Java 类型转换为 `.kt`。
- 公共库 API 保持二进制和源码兼容；必须改签名时同步检查调用方、demo 和聚合 `libs`。
- Kotlin 目标为 JVM 1.8；不要引入需要更高语言级别或更高 minSdk 的 API。
- Android 生命周期对象不要泄漏 `Activity`/`Fragment`/`View`；异步回调必须考虑销毁态。
- UI、权限、文件、相机、图片、下载、网络相关改动必须考虑 Android 版本差异和运行时权限。
- 不把业务 demo 代码反向塞进基础库；demo/sample 只验证用法。
- 日志必须克制且服务于排查问题：不要满篇打印日志，不要一步一打，不要用日志替代清晰的代码结构。
- 新增日志前先判断是否能定位真实问题；优先记录关键入口、异常、边界状态和必要上下文，避免重复、噪声和无意义流水账。
- 日志内容不要泄漏隐私、token、完整请求响应、文件路径等敏感信息；调试临时日志完成后必须删除。

## XML / 资源

- 修改资源名时检查所有引用、Manifest、style、layout、drawable、mipmap。
- 公共库资源命名保持模块前缀或明确语义，避免和宿主 app 冲突。
- UI 资源改动需要至少 assemble 对应模块或 demo。

## Gradle

- 现有工程使用 AGP 8.2.2、Kotlin Gradle Plugin 1.9.24、Java 8 目标。
- 发布库通常包含：
  - `ext.publishVersion = rootProject.xxfVersion`
  - `ext.publishGroup = rootProject.xxfGroup`
  - `ext.moduleName = project.name`
  - `apply from: '../publish_maven.gradle'` 或按目录层级调整路径
- 对外依赖用 `api` 需谨慎；只有公共 API 暴露该类型时才使用。内部实现优先 `implementation`，可选宿主能力优先 `compileOnly`。
- 不提交本地凭证、签名文件、私有 token、机器路径。

## 仓库约束

- `settings.gradle` 是模块启用事实来源。
- `libs` 是聚合库，变更核心库依赖时检查是否需要同步 `libs/build.gradle`。
- `optional/*` 是可选能力，避免让核心库强依赖可选库。
