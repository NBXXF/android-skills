---
name: aaaaa-xxf-android-i18n-strings
description: Android 国际化字符串门禁。新增或修改 Kotlin/Java/XML/Compose UI、Toast、Dialog、Snackbar、错误提示、按钮、标题、hint、contentDescription、Manifest label、菜单、Preference、空态等用户可见文案时必须使用；语言切换和语言敏感字符串读取优先使用 com.NBXXF.xxf_android:lib_i18n 的 `setAppLanguage(...)`、`resetAppLanguage()`、`restoreCachedAppLanguage()`、`getLocalizedString(...)`、`resString()` 等 API；发现既有硬编码显示文案、字符串拼接展示文案、重复散落文案时主动提取到 strings.xml/plurals，并避免误改业务常量、协议字段、key、tag、路由、配置值、日志和测试 fixture。
---

# Android 文案国际化

## 总原则

- 不新增用户可见硬编码文案；发现既有硬编码显示文案时，默认主动迁移到 `res/values/strings.xml`。
- 只提取“给用户看的文案”，不要把业务逻辑常量、协议值、配置值、存储 key、埋点 key 等误提取成字符串资源。
- Gradle、配置文件、BuildConfig、开关配置、远端配置、算法/计算参数、业务 key、协议 key 默认都不是显示文案，禁止为了消除硬编码而提取。
- 文案组合要按目标语言完整句式建一个 key，用格式化参数表达变量，不要把一句话拆成多个可拼接片段。
- 不确定字符串是不是业务常量时，先沿调用链确认用途；仍不确定时保留原样并说明风险，不要为了消除硬编码盲目迁移。
- 触达 Android UI 文件时，要主动检查同一文件和同一 UI 组件内的既有硬编码文案，不只处理用户点名的那一行。
- 国际化改动不能改变业务值、资源 ID 对外契约、构建配置、运行分支或埋点/协议上报；遇到不确定边界时，宁可保留并记录，也不要猜测迁移。

## lib_i18n 优先级

- 只要任务涉及应用内语言切换、语言恢复或语言敏感字符串读取，优先使用 `com.NBXXF.xxf_android:lib_i18n`（源码包 `com.xxf.android.i18n`）。
- 语言切换优先级：`setAppLanguage(...)` / `appLanguage = ...` 设置语言，`resetAppLanguage()` 恢复跟随系统，`restoreCachedAppLanguage()` 负责启动早期恢复。
- 字符串读取优先级：`Context.getLocalizedString(...)`、`Context.getLocalizedQuantityString(...)`、`Context.getLocalizedStringArray(...)`，以及 `Int.resString()`、`Int.resQuantityString()`、`Int.resStringArray()`。
- 全局工具类、Application、Service、Worker、BroadcastReceiver、通知、Toast、后台任务和跨 Context 场景，默认不要直接用 `applicationContext.getString(...)` / `applicationContext.resources...`，先改成本模块的 localized API。
- 只有在当前 UI Context 已经由 AppCompat 正确提供、且不涉及全局读取时，才考虑直接使用原生 `getString(...)` 或 `stringResource(...)`。
- 不要手写 `AppCompatDelegate.setApplicationLocales(...)`、`attachBaseContext` 包装或自建语言缓存，除非任务明确要求绕开 `lib_i18n` 的特殊入口。

## 判定顺序

1. **是否可能显示给用户**：能出现在屏幕、系统辅助功能、通知、弹窗、菜单、错误提示、表单提示、权限解释中的字符串，按用户可见处理。
2. **是否参与机器契约**：被服务端、存储、路由、反射、序列化、埋点、构建配置、Manifest 合并或系统 API 识别的字符串，按业务/协议常量处理。
3. **是否影响业务分支或运算**：参与 `if/when` 判断、排序、过滤、匹配、hash、签名、加密、缓存命中、实验分桶、金额/数量/状态计算的字符串或格式，禁止提取。
4. **是否来自 Gradle/config**：`build.gradle`、`gradle.properties`、`local.properties`、TOML、JSON/YAML 配置、properties 配置、远端配置默认都是构建或业务配置，不按 UI 文案提取。
5. **是否同时具备两种用途**：同一个字面量既用于逻辑又用于展示时，拆开两个来源；逻辑值继续保留常量，展示值新增 string resource。
6. **是否来自服务端可变文案**：服务端直接返回并要求原样展示的文案不要本地化；本地兜底文案、错误码映射文案需要本地资源化。
7. **是否为开发者可见**：日志、异常 detail、调试面板、测试 fixture 默认不提取；如果调试面板面向真实用户或 QA 交付界面，再按用户可见处理。
8. **是否为资源/API 契约**：公共库已有 string key 名、`public.xml`、宿主可能覆盖的资源名不要随意重命名；只改 value 或新增兼容 key。

## 必须提取

以下字面量如果会展示给用户，必须放到 string resource：

- XML：`android:text`、`android:hint`、`android:contentDescription`、`android:label`、菜单标题、Preference 标题/摘要。
- Kotlin/Java：`TextView.setText("...")`、`Toast`、`Snackbar`、`AlertDialog`、错误提示、空态提示、按钮文案、标题、副标题、表单校验文案。
- Compose：`Text("...")`、`Button` 内文案、`contentDescription`、`stringResource` 可替代的用户可见文本。
- DataBinding/ViewBinding 表达式中拼出来的展示文案，例如 `@{"欢迎 " + user.name}`。
- Navigation graph、toolbar title、tab title、bottom navigation/menu item title、Preference XML、shortcut label、widget label。
- `string-array`、`plurals`、dialog list item、spinner/dropdown 选项等用户可见选项文案。
- Notification、RemoteViews、AppWidget、Shortcut、权限说明、分享面板标题、文件选择器标题等系统 UI 可见文案。
- 业务返回码映射后的本地展示文案，例如把服务端错误码转为“网络异常，请稍后重试”。
- 测试、demo、sample 中会展示在 UI 上的文案；除非该文件明确只是单元测试断言内部协议值。

## 不要提取

这些字符串通常参与业务逻辑、协议或系统集成，不能因为“硬编码”就迁移到 `strings.xml`：

- API path、host、query 参数名、JSON 字段名、服务端枚举值、错误码、MIME type、User-Agent。
- `Intent` action、extra key、`Bundle` key、`SharedPreferences` key、DataStore key、数据库表名/列名。
- 路由名、DeepLink path、文件名、缓存 key、目录名、权限名、Manifest authority。
- 埋点事件名、实验 key、AB 配置值、日志 tag、调试日志内容、正则表达式、SQL 片段。
- `const val`、`enum`、注解参数、反射类名、序列化名称等被代码或外部系统依赖的值。
- Gradle 配置、plugin id、task 名、flavor/buildType、sourceSets、依赖坐标、仓库地址、签名配置、版本号、BuildConfig 字段。
- `gradle.properties`、`local.properties`、`libs.versions.toml`、JSON/YAML/properties 配置里的开关名、配置 key、渠道名、包名、Maven 坐标、ProGuard/R8 keep 规则中的字符串。
- 参与业务逻辑和运算的格式字符串、单位标识、货币/语言/地区 code、排序字段、过滤条件、hash/sign 参数、缓存命中 key。
- Compose Preview 名称、截图测试名称、测试用例名、mock 数据 ID、调试入口 ID，除非它们会在真实 UI 中展示给用户。
- 资源文件名、drawable/layout/style/color/dimen 名称、style parent、theme attr、manifest meta-data name/value 等资源或系统契约。
- 只用于单元测试内部断言、mock 协议、fixture 数据的字符串。

误提取以上内容可能改变运行时值、资源加载时机、混淆结果、构建产物、服务端协议、缓存命中、实验分流或业务分支，属于业务 bug 风险。

## 允许保留的硬编码

- 空字符串、单个空格、换行、分隔符、纯格式模板内部控制字符，且不会作为独立文案展示。
- 符号类 UI 文案，例如 `+`、`-`、`/`、`:`，只有在它们不是自然语言文案且不会影响国际化语序时可保留。
- 第三方 SDK 要求传入的固定字符串、系统常量字符串、协议字段值。
- 仅用于开发诊断的异常消息和日志；如果异常消息会透出给终端用户，必须改成本地化展示文案。
- 品牌名、产品名、公司名、商标、专有名词如果必须所有语言保持一致，可以放在 `strings.xml` 并设置 `translatable="false"`，或复用既有 `app_name`/brand key。
- 法务、证书、协议版本、第三方要求原文展示的固定文本，先确认是否允许翻译；不允许翻译时使用 `translatable="false"` 或保留原来源。

## 资源选择

- 普通单句使用 `<string>`。
- 数量相关优先使用 `<plurals>`，即使中文没有复数变化，也要给其他语言留下正确表达空间。
- 多个用户可见选项使用 `<string-array>`，但不要把业务枚举值和展示名混在一个数组里；业务值保持常量，展示名走资源。
- 品牌、渠道展示名、第三方固定名如果不翻译，使用 `translatable="false"`，不要因为它在 `strings.xml` 就默认翻译。
- 包含 HTML/span/换行/占位符的文案要保持 Android string resource 语义，必要时检查 `formatted="false"` 是否需要；不要让 `%`、`<`、`&` 破坏资源编译。
- 公共库中已有资源名可能被宿主覆盖或被外部引用，不要无关重命名；需要替换文案时优先保留 key。

## 处理流程

1. 先定位硬编码来源和用途，判断是否用户可见。
2. 如果字符串位于 Gradle/config/常量定义/协议模型/存储 key/埋点/运算逻辑附近，先默认不提取；只有能证明它会展示给用户时才迁移。
3. 迁移前检查该字符串是否被比较、匹配、序列化、反射、作为 key 读写、作为参数传给 SDK/API、参与计算或构建配置；命中任一项时禁止直接替换为 `R.string.*`。
4. 搜索同一文件、同一页面、同一资源目录是否还有明显用户可见硬编码，纳入同一小范围迁移。
5. 查找当前模块已有 `res/values/strings.xml`、`plurals.xml`、命名风格和同义文案。
6. 同一语义优先复用既有 key；相同字面量但语义不同要拆成不同 key。
7. 新增 key 使用稳定语义命名，优先按页面/组件/语义命名，避免 `text1`、`title_new`、`tips` 这类模糊名称。
8. XML 改为 `@string/key_name`；Kotlin/Java 改为 `getString(R.string.key_name)` 或 `context.getString(...)`；Compose 改为 `stringResource(R.string.key_name)`。
9. 对已有 locale 文件：
   - 已有明确翻译时同步补齐对应 key。
   - 没有可靠翻译时不要臆造外语翻译；至少补默认 `values/strings.xml`，并在最终说明缺少哪些 locale 翻译。
   - 发现已有 `tools:ignore="MissingTranslation"`、`translatable="false"`、专门的翻译流程时，遵循项目现有策略。
10. 运行最小验证，优先编译受影响模块；可用时再跑 Android lint 或项目已有检查。

## 文案拼接

用户可见句子不能用 `"a" + value + "b"`、`"$a$value"`、多个 `@string` 片段拼出最终文案。不同语言的语序、空格、复数和标点可能不同。

正确做法：

```xml
<string name="profile_followers_count">%1$s 位关注者</string>
```

```kotlin
followersView.text = context.getString(R.string.profile_followers_count, countText)
```

从拼接迁移时，把整句作为一个资源：

```kotlin
// 迁移前
titleView.text = "欢迎 " + userName + " 回来"

// 迁移后
titleView.text = context.getString(R.string.home_welcome_back, userName)
```

```xml
<string name="home_welcome_back">欢迎 %1$s 回来</string>
```

要求：

- 一个完整展示句子建一个 key，用 `%1$s`、`%2$d` 等位置参数。
- 需要数量变化时优先使用 `plurals`，不要自己拼“个/条/次”。
- 列表拼接、范围拼接、A/B 两个业务名组合展示时，也要把完整展示模板放入资源，例如 `%1$s 至 %2$s`，不要只提取固定片段。
- 日期、金额、百分比、文件大小等使用当前项目已有格式化工具或 locale-aware API，避免把业务格式硬塞进字符串拼接。
- 参数来自用户输入或服务端时，确保格式化前后仍经过必要的转义、脱敏或空值兜底。
- 字符串里有 `%` 字面量时写成 `%%`；有单引号、换行、HTML/span 标记时按 Android string resource 规则处理。
- 不为了复用拆出“前缀”“后缀”“冒号”等碎片 key，除非它们本身就是独立 UI 文案。
- 如果原代码用 `String.format(Locale.US, ...)` 生成协议值、文件名、签名串或数字格式，不要迁移为 UI 资源；这类格式属于业务/机器格式。

## 既有硬编码清理

当任务触达相关文件时，顺手清理同一职责范围内明显的显示文案硬编码：

- 优先清理当前改动文件、同一 UI 组件、同一页面或同一资源文件内的硬编码。
- 不要扩大到全仓批量迁移，除非用户明确要求。
- 清理前先区分显示文案和业务常量；对疑似 key/tag/协议值只记录，不迁移。
- 不清理 Gradle/config/常量池里的字符串，除非调用链明确证明它们最终只作为用户可见文案使用。
- 对拼接句子、模板字符串、`String.format("...")`、Compose `Text("...$value")` 优先整体迁移为格式化资源。
- 迁移后检查 import、资源冲突、R 引用包名、library 模块资源暴露是否正确。
- 公共库新增资源名要有模块前缀或清晰业务前缀，避免宿主资源冲突。
- XML/DataBinding/Navigation/Menu/Preference 中的硬编码也要纳入检查，不要只扫 Kotlin/Java。
- 若发现字符串已经在 `strings.xml` 中但被代码当业务值读取，不能继续扩大这种用法；新增展示文案必须和业务值分离。

可用搜索起点：

```bash
rg -n '"[^"\n]*[\\p{Han}A-Za-z][^"\n]*"' --glob '*.kt' --glob '*.java'
rg -n 'android:(text|hint|contentDescription|label)="[^@?]' --glob '*.xml'
rg -n 'Text\\("[^"]+"' --glob '*.kt'
rg -n '(Toast|Snackbar|AlertDialog|setTitle|setMessage|setText|setHint)\\([^)]*"[^"]+"' --glob '*.kt' --glob '*.java'
rg -n 'android:(title|summary|entries|positiveButtonText|negativeButtonText)="[^@?]' --glob '*.xml'
rg -n '@\\{[^}]*"[^"]+"' --glob '*.xml'
```

搜索结果必须人工判定，不要机械全改。

## 最终说明

完成后要简要说明：

- 新增或复用的 string/plurals key。
- 哪些硬编码被判定为业务常量并保留，原因是什么。
- 是否排除了 Gradle/config/key/业务运算相关字符串，原因是什么。
- 是否新增了 `plurals`、`string-array` 或 `translatable="false"`，原因是什么。
- 是否发现未补齐的 locale 翻译。
- 运行了哪些编译、lint 或测试；未运行时说明原因。

## 审查清单

- 新增或触达的用户可见文案是否都来自 `strings.xml`、`plurals` 或已有资源？
- 是否有 `"a" + value + "b"`、多个资源碎片拼句子、硬编码冒号/单位/标点？
- 是否误把 key、tag、路由、协议字段、配置常量、埋点名迁移到资源？
- 是否误把 Gradle/config/BuildConfig/远端配置/业务运算参数迁移到资源？
- 字符串替换是否改变了比较、匹配、排序、缓存、签名、实验分桶、协议传输或构建产物？
- 是否错误翻译了品牌名、协议原文、第三方固定名，或漏加 `translatable="false"`？
- 是否遗漏 DataBinding、Navigation、Menu、Preference、string-array、plurals、contentDescription 等非普通 TextView 文案？
- 相同字面量是否按语义复用或拆分，而不是盲目共用？
- 新增 key 是否命名清晰，并放在正确模块的资源文件？
- Compose、XML、Kotlin/Java 是否使用了各自正确的资源读取方式？
- 是否说明未补齐的 locale 翻译和未运行的验证？
