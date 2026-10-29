---
name: aaaaa-xxf-coding-style
description: Android 项目的 Android/Kotlin/XML/Gradle 编码规范。修改 Kotlin、资源、Manifest、Gradle 或发布配置时必须遵守；新增、修改或审查业务日志时强制使用 com.xxf.log 的六个 lambda 扩展 API，禁止其他日志入口；语言选择先按 aaaaa-xxf-language-selection 执行。
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

## 日志规范（强制）

### 适用范围与唯一入口

- 新增、修改、重构或审查业务日志时必须执行本节；覆盖 app、feature、data、业务组件及 demo/sample 的业务代码。
- **业务日志只能调用 `com.xxf.log` 包中 `LogUtilsKt.kt` 定义的 `logV`、`logD`、`logI`、`logW`、`logE`、`logJson` 六个 lambda 扩展函数。这是强制白名单，不是建议；任何非白名单日志调用均为交付阻断项。**
- API 事实来源为 `xxf_android/core/lib_log/src/main/java/com/xxf/log/LogUtilsKt.kt`。必须确认 import 和声明来源，不能仅凭函数同名认定合规。
- 依赖缺失时，必须核查目标工程的 version catalog、模块依赖和既有接入方式，接入 `lib_log` 后再调用；禁止编造依赖坐标、复制扩展函数、创建同名替代品或退回其他日志 API。
- 仅 `lib_log` 自身实现、专用日志适配层可因实现需要调用底层输出接口；不得把业务代码命名为“适配层”绕过白名单。全局日志配置只能由宿主统一初始化层管理，业务页面和业务组件不得修改全局配置或自行注册输出通道。

### API 白名单与调用方式

六个函数的共同签名为 `inline fun <reified T : Any> T.<方法名>(tag: String? = T::class.java.simpleName, noinline log: () -> Any)`，返回 `Unit`。

| What | Why | How |
| --- | --- | --- |
| `logV` | 必要的细粒度诊断 | `logV { "阶段=$stage" }`；禁止循环、逐帧、逐项刷屏 |
| `logD` | 开发排查 | `logD { "缓存命中=$cacheHit" }` |
| `logI` | 关键业务状态 | `logI { "同步完成，数量=$count" }` |
| `logW` | 可恢复异常或降级 | `logW { "缓存失效，切换远端读取" }` |
| `logE` | 操作失败及异常 | `logE { error }`；异常对象交给统一解析器处理 |
| `logJson` | 必要的结构化诊断 | `logJson { sanitizedSummary }`；传脱敏后的最小对象，由框架序列化；当前实现使用 INFO 级别 |

- 必须显式导入对应扩展，例如 `import com.xxf.log.logD`；禁止通过 import alias 隐藏入口来源。
- 必须在合适的类或对象接收者上调用；默认 Tag 是接收者静态类型 `T` 的简单类名。需要固定业务 Tag 时使用 `tag = "Sync"`，禁止用手机号、用户标识或请求内容作 Tag。
- 日志内容必须在 lambda 内构造。字符串拼接、对象摘要和必要序列化不得在调用前预计算；`logJson` 禁止先自行转成 JSON 字符串再传入。
- lambda 只允许构造诊断内容，禁止执行请求、数据库读写、状态修改等业务副作用；日志关闭后 lambda 可能不执行，业务行为不得依赖它。
- lambda 返回类型是非空 `Any`，可空内容必须显式提供安全兜底；禁止为打印日志使用 `!!`。

```kotlin
import com.xxf.log.logD
import com.xxf.log.logE
import com.xxf.log.logJson

private class SyncTask {
    fun execute(sync: () -> Int) {
        try {
            val count = sync()
            logD(tag = "Sync") { "同步完成，数量=$count" }
            logJson(tag = "Sync") { mapOf("count" to count) }
        } catch (error: Exception) {
            logE(tag = "Sync") { error }
            throw error
        }
    }
}
```

### 禁止事项

- **禁止直接调用 `android.util.Log`、`android.util.Slog`、`println`、`print`、`System.out`、`System.err`、`Throwable.printStackTrace()` 等输出日志。**
- **禁止直接调用 `LogUtils.logV/logD/logI/logW/logE/logJson`、`Logger`、`AndroidLogger` 或其他底层输出实现。** 即使来自同一个 `lib_log`，也不能替代白名单扩展入口。
- **禁止业务代码使用 Timber、SLF4J、java.util.logging、第三方 Logger/LogUtils 等日志入口，禁止新增自建 Logger、包装函数、扩展或转发门面绕过白名单。** 既有包装层不是豁免理由。
- 禁止仅记录 `error.message`、`error.toString()` 或通过字符串插值替代异常对象，造成堆栈丢失；异常必须用 `logE { error }` 或按可恢复语义用 `logW { error }` 传入。异常内容也必须检查敏感信息，必要时先做安全处理并保留可用堆栈。
- 禁止用空 `catch` 或“只打日志”吞掉原本应传播、回调或展示的失败；替换日志入口不得改变原有错误处理语义。
- 禁止满篇打印、一步一打、重复记录同一异常；只保留能定位真实问题的关键入口、异常、边界状态与必要上下文，临时调试日志交付前必须删除。
- 禁止输出 token、cookie、Authorization、完整请求响应、手机号、邮箱、精确位置、完整文件路径等敏感信息；使用 `logJson` 不构成隐私豁免。
- 禁止在高频回调、主线程或大数据处理中构造昂贵日志；必须按 `aaaaa-xxf-android-performance-gate` 检查必要性、摘要、限频和惰性求值。
- 禁止为了“看见日志”在业务中强行开启输出。release 输出、脱敏和诊断开关按 `aaaaa-xxf-google-play-compliance-gate` 执行；发布库同时遵守 `aaaaa-xxf-maven-library-release-guard`，不得假定 lambda 或库内 `BuildConfig.DEBUG` 会自动关闭 release 日志。

### 执行与验证

1. 修改前确认目标工程实际依赖的 `com.xxf.log` 扩展声明和宿主初始化方式，禁止凭记忆增加不存在的重载或参数。
2. 本次触达的业务文件中发现非白名单日志调用，必须一并替换或删除无意义日志，保留必要上下文与原有业务语义；不得只规范新增行而放任同文件违规入口。
3. 交付前扫描本次触达的业务文件及其 import，检查全限定调用、静态导入、别名、自建包装、预计算日志和敏感数据；同名方法必须追踪到真实声明。可用以下命令初筛，命中项必须逐条判断，不能把正则无命中当作合规证明。

```bash
rg -n -g '*.kt' -g '*.java' \
  'android\.util\.(Log|Slog)|\b(Log|Slog|Timber|Logger|LogUtils|AndroidLogger)\s*\.|\b(print|println|printStackTrace)\s*\(|System\.(out|err)|org\.slf4j|java\.util\.logging|import .*\blog(V|D|I|W|E|Json)\b|fun .*\blog(V|D|I|W|E|Json)\b' \
  <本次触达的业务文件或目录>
```

4. 对实际业务源码改动运行最小相关编译验证，检查扩展 import、接收者和 lambda 返回类型；仅修改本规范时核对 API 源码与镜像一致性即可。
5. 最终说明日志入口替换范围、验证结果及未解决项。触达业务文件仍存在非白名单日志入口时必须明确标为交付阻断，不得宣称已符合规范；本规范不授权顺带改写无关模块或第三方源码。

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
