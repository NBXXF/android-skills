---
name: aaaaa-xxf-maven-library-release-guard
description: Android Maven 发布库的构建变体与运行时配置门禁。新增、维护、重构或发布 Android Library/AAR，修改 buildFeatures、BuildConfig、maven-publish、singleVariant、发布脚本、调试开关、环境开关或宿主初始化参数时必须使用；防止 release AAR 将库内 BuildConfig.DEBUG 常量折叠为 no-op、GONE 或错误分支。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android Maven 发布库门禁

## 目标

保证 Maven AAR 的行为由宿主运行时配置决定，不被 Library 自身的 release 构建类型错误固化。

## 先判断模块性质

满足任一条件即按“可发布 Maven Library”处理：

- 应用了 `maven-publish` 或仓库发布脚本。
- 配置了 `publishing`、`MavenPublication`、`singleVariant("release")`。
- 定义了 Maven group、artifact、version 或 publish task。
- 产物会被其他独立工程以 AAR/Maven 坐标消费。

仅通过 `project(":module")` 在同一工程编译、且确定永不发布的内部模块，才属于工程内 Library。

## 强制规则

### 禁止 Library 自身 BuildConfig

可发布 Maven Library 默认必须满足：

- 不开启 `buildFeatures { buildConfig = true }`；无其他用途时显式关闭或删除配置。
- `src/main` 不引用、导入、反射或按字符串查找 Library 自身的 `BuildConfig`。
- 不使用 `BuildConfig.DEBUG` 控制功能、日志、UI、初始化、网络、环境或 no-op 实现。
- 不通过自定义 `buildConfigField` 向发布库注入运行时业务状态。

发现以上任一项，风险结论默认是 `Block`。原因是 Maven 通常发布 release variant，Library 的 `BuildConfig.DEBUG` 表示“Library 产物变体”，不表示“宿主 App 是否可调试”。R8/Kotlin/Javac 还可能把分支常量折叠，导致 API 变成空方法、固定 `GONE` 或永久关闭。

只有为了保持已经发布的公共 ABI，且有明确调用方证据时，才能临时保留 BuildConfig 生成；即使保留，也禁止业务代码读取它，并记录迁移计划。

### 使用宿主运行时事实

按需求选择一种来源：

1. 优先使用宿主显式注入的配置，默认值必须安全关闭：

```kotlin
data class DebugConfig(val enabled: Boolean = false)

fun init(application: Application, config: DebugConfig) {
    debugEnabled = config.enabled
}
```

宿主调用：

```kotlin
library.init(application, DebugConfig(enabled = BuildConfig.DEBUG))
```

2. 只需要判断宿主 APK 是否 debuggable 时，读取宿主 ApplicationInfo，而不是 Library BuildConfig：

```kotlin
val Context.isAppDebug: Boolean
    get() = applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0
```

3. 需要动态切换、测试环境或远程开关时，使用显式参数、配置接口或 provider lambda。不要把“宿主可调试”“测试环境”“日志开关”“业务 debug mode”混成同一个布尔值。

## 排查流程

1. 确认发布的 variant，重点检查 `singleVariant("release")` 和 publication component。
2. 扫描目标模块：

```bash
rg -n "BuildConfig|buildConfigField|buildConfig\s*=\s*true|singleVariant|MavenPublication|maven-publish" MODULE
```

3. 沿调用链检查宿主是否显式传值，以及 Library 是否真正保存并读取该值。
4. 检查默认值：未初始化、旧调用方或 release 宿主必须默认关闭调试能力。
5. 检查持久化状态是否会覆盖宿主本次初始化值；初始化参数应是当前进程的权威来源。
6. 检查 debug/no-op/release 分支是否因常量折叠变成空方法或固定 UI 状态。

## 修复要求

- 系统性删除目标发布模块所有自身 `BuildConfig` 依赖，不只修当前报错行。
- 公共 API 尽量保持二进制兼容；新增配置字段时提供安全默认值，但宿主接入必须显式赋值。
- 对已无调用的公共类先全仓搜索；删除已发布符号前说明二进制兼容风险并获得用户决定。
- 不用宿主包名反射宿主 `BuildConfig`；优先参数注入或 `ApplicationInfo.FLAG_DEBUGGABLE`。

## 最小验证

必须验证发布使用的 release 变体，不能只跑 debug：

```bash
./gradlew :MODULE:testReleaseUnitTest :MODULE:assembleRelease
```

回归测试至少覆盖：

- 宿主传 `true` 时功能开启。
- 宿主传 `false` 或未传时功能关闭。
- 测试运行在 release unit-test variant，能复现 Library `BuildConfig.DEBUG == false` 的发布场景。

构建后检查 release AAR：

```bash
unzip -p MODULE/build/outputs/aar/*-release.aar classes.jar > /tmp/library-release.jar
javap -classpath /tmp/library-release.jar -c -p fully.qualified.EntryClass
```

确认关键方法仍读取运行时字段/参数，`true` 分支没有被裁成空方法、固定 `GONE` 或直接 `return`。同时确认目标模块产物不再包含对自身 `BuildConfig.DEBUG` 的业务引用。

若有宿主工程，至少编译一个实际消费该 Maven 坐标的 debug variant；发布前按发布流程检查 POM、坐标和 release AAR。

## 交付结论

最终必须说明：

- 发布 variant 和问题是否由 Library BuildConfig 引起。
- 删除了哪些 BuildConfig 依赖，宿主运行时配置从哪里注入。
- release 单测、release AAR 和宿主集成分别验证了什么。
- 是否删除公共符号，以及对应兼容风险。
- 风险结论：存在 Library 自身 BuildConfig 业务依赖或未验证 release 产物时为 `Block`；全部通过后为 `Pass`。
