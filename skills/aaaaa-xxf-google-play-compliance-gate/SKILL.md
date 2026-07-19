---
name: aaaaa-xxf-google-play-compliance-gate
description: Android Google Play 上架审核合规门禁。用于新增、维护、重构或审查 Android app/library/AAR/SDK 时识别和规避 Google Play 政策、权限、隐私、安全、WebView、网络、存储、相机相册、后台任务、日志、安装包、包可见性、设备标识、诊断工具等审核风险；发现既有问题代码或配置且修复会影响业务能力、API 兼容、发布依赖或用户体验时，必须先提示用户决策并记录。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Google Play 审核合规门禁

## 基本原则

1. 先判断“是否会进入 Play-facing app 的最终 APK / AAB”，再判断“代码是否被调用”。Google Play 的静态扫描可能只看最终产物中的代码、Manifest、权限、SDK 和字符串特征，未调用代码也可能造成审核解释成本。
2. 官方文档优先。遇到目标 API、权限政策、Data safety、SDK 政策、后台任务、WebView/TLS、照片视频、全文件访问、安装包、包可见性等问题，必须查询最新官方 Google Play / Android 文档；社区经验只能作为补充，不能覆盖官方要求。
3. 默认最小权限、最小暴露、最小依赖。通用库不得默认合并敏感权限，不得默认暴露高风险组件，不得把仅少数业务需要的能力放入基础库。
4. 发现既有问题时不要直接大改业务语义。先做代码事实核查，分清“必须修复的审核 blocker”和“可选治理项”；修复会改变业务能力、API、兼容性或发布依赖时，必须 prompt 用户决策。
5. 修复后必须验证最终产物，不只看源码。至少检查 merged manifest、release AAR/APK 字符串、依赖树和最小 Gradle 构建。

## 触发时必须执行的流程

1. 明确范围：
   - app 上架：以最终 release APK / AAB 依赖树和 merged manifest 为准。
   - library/AAR 发布：以 consumer 依赖、AAR manifest、consumer rules 和公开 API 为准。
   - 聚合库：递归检查所有 `api` 依赖是否把风险能力传给宿主。
   - demo/sample：除非用户明确要求，否则不作为发布结论；但 demo 中发现的问题可以记录为“不纳入发布”。
2. 查最新依据：
   - 用户提到“最新”“上架”“审核”“Google Play”“合规”“政策”时，必须浏览官方 Google Play / Android 文档。
   - 需要社区经验时，先看官方结论，再用社区经验解释审核实践；不要把论坛经验当政策。
3. 扫描源码和配置：
   - Manifest：权限、`uses-feature`、`queries`、exported 组件、provider、service、receiver、cleartext、backup、foreground service type。
   - Gradle：targetSdk/compileSdk、三方 SDK、`api` 依赖暴露、consumer rules、debug/no-op artifact、release 变体。
   - 源码：WebView/TLS、文件路径、权限申请、安装卸载、root/shell、设备标识、剪贴板、日志、后台任务、通知、广告/分析 SDK。
4. 分类输出：
   - `Block`：会进入 Play release 且可能拒审、下架、权限声明无法自证或存在明确安全漏洞。
   - `Warn`：可发布但有审核解释成本、隐私披露成本或业务误用风险。
   - `Pass`：未发现当前范围内的 Play 审核风险。
5. 决策与记录：
   - 对既有问题代码，先给出推荐修法和影响；如果修复会影响业务功能/API/兼容性，必须询问用户是否修改。
   - 用户确认后，按 `aaaaa-xxf-clarify-question` 记录到对应模块 `vibe-coding-clarify.md`，再编码。
6. 修复闭环：
   - 做最小正确改动。
   - 加必要注释，必须包含类似“为了合规和 Google Play 应用市场审核，必须...”的原因。
   - 运行最小 Gradle 验证和产物扫描。
   - 更新合规文档或最终说明，写明怎么改、改后业务影响、残余风险、验证结果。

## 需要 prompt 用户决策的情况

发现以下情况时，不能擅自按一种业务策略改完：

- 移除权限会让已有业务功能失效，例如相册全量扫描、录音、相机、后台定位、精确闹钟、通知、全文件访问。
- 从基础库迁出 API 会导致调用方编译失败，例如安装包、卸载、root/shell、全文件管理、使用情况访问、蓝牙开关。
- 需要在“保持兼容但有审核风险”和“破坏兼容但更合规”之间选择。
- 需要拆新模块、改发布坐标、改依赖暴露方式、增加 no-op/debug-only artifact。
- 既有代码是否属于核心功能无法从代码事实判断，例如文件管理器、企业设备管理、反病毒、备份恢复、儿童/家庭、安全工具。
- 修复会改变用户体验，例如从全相册访问改成 Photo Picker、从后台常驻改成用户主动触发、从自动下载改成系统下载器。

决策 prompt 模板：

```text
这里需要你确认一个 Google Play 合规决策：

背景：我发现 <模块/文件> 存在 <权限/代码/配置>，进入 Play release 后可能触发 <政策/审核风险>。
推荐：<方案 A>，原因是 <合规理由>。
影响：<业务功能/API/兼容性/用户体验变化>。

可选方案：
1. <方案 A>（推荐）：<优缺点>
2. <方案 B>：<优缺点>
3. 暂不修改：<残余审核风险>

确认后我会把决策记录到 <module>/vibe-coding-clarify.md，再继续修改。
```

用户已经明确要求“全部按审核合规改”“只管发布库”“demo 不管”这类范围时，可以在该范围内直接修复明确 blocker；仍要在最终说明里写清破坏兼容或业务行为变化。

## 常见审核风险与默认修复策略

### WebView / TLS / 网络安全

- 不允许 `onReceivedSslError(...){ handler.proceed() }`。默认删除覆盖逻辑或调用 `handler.cancel()`，让系统拒绝证书错误。
- 不允许自定义 `HostnameVerifier` 放行所有主机、空 `X509TrustManager`、信任所有证书、弱 TLS 配置。
- 不默认开启 cleartext。需要 HTTP 时由宿主通过 network security config 精确域名配置，并说明原因。
- WebView 开启 JavaScript、`addJavascriptInterface`、文件访问、混合内容时要最小化，来源必须受控。

### 权限与 Manifest

- library 不默认合并敏感权限；让宿主按实际业务声明。
- 旧存储权限：`WRITE_EXTERNAL_STORAGE` 限制到 `maxSdkVersion=28`，`READ_EXTERNAL_STORAGE` 限制到 `maxSdkVersion=32`；普通媒体选择优先 Photo Picker / SAF / MediaStore。
- Android 13+ 媒体权限按类型申请 `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`；Android 14+ 处理 selected photos。
- 相机、录音、定位、通知、蓝牙、前台服务、精确闹钟等权限必须能对应用户可理解的核心功能。
- `MANAGE_EXTERNAL_STORAGE`、`QUERY_ALL_PACKAGES`、`REQUEST_INSTALL_PACKAGES`、SMS/Call Log、Accessibility、VPN、Device Admin 等受限能力默认拆到 opt-in/unsafe 模块。
- `uses-feature android:required=true` 只在业务必须依赖硬件时保留；通用库避免强制过滤设备。

### 安装包、卸载、root、shell、系统设置

- 基础库不得默认包含 APK 安装/卸载、静默安装/卸载、`pm install`、`pm uninstall`、root 检测、`su`、通用 shell 执行。
- 这些能力应拆到明确命名的 unsafe / enterprise / device-owner / non-play artifact。
- 直接拨号、关机、悬浮窗、写系统设置、使用情况访问、忽略电池优化等系统能力应按需 opt-in，注释中写明合规前提。

### 文件、Uri、媒体

- 对外分享文件必须使用 `FileProvider` content Uri 和授权 flag；不得对外暴露 `file://`。
- 通知媒体库优先 `MediaScannerConnection.scanFile(...)` 或 MediaStore 写入，不使用 `ACTION_MEDIA_SCANNER_SCAN_FILE + Uri.fromFile(...)`。
- 普通导入/导出使用 SAF、MediaStore 或 app-specific storage；不要为了普通文件功能申请全文件访问。

### 日志、诊断和隐私数据

- release 默认关闭日志输出、HTTP 日志、事件日志、调试面板、数据库浏览器、BlockCanary 等诊断工具。
- 日志不得包含 token、cookie、Authorization、Set-Cookie、完整请求响应、身份证件、手机号、邮箱、精确位置、完整文件路径等敏感信息。
- 线上必须保留的诊断能力要有显式开关、脱敏、访问控制、清理入口和隐私披露。
- debug-only/no-op artifact 是首选；不要让诊断 UI 默认进入 Play release。

### SDK、数据安全和包可见性

- 新增或升级第三方 SDK 时检查 Google Play SDK Index、隐私政策、数据收集、广告 ID、儿童/家庭政策和 Data safety 声明。
- 不读取 IMEI、序列号、MAC 等硬件标识；优先使用实例 ID、用户登录态或可重置标识，并说明用途。
- `ANDROID_ID` 也属于标识符，只有必要时使用，避免日志输出。
- `<queries>` 精确声明包名、intent 或 provider；不使用 `QUERY_ALL_PACKAGES`，除非核心功能符合政策。

## 推荐扫描命令

按项目实际路径调整范围，优先排除 demo/sample：

```bash
rg -n --glob '!**/build/**' --glob '!**/demo/**' --glob '!**/*demo*/**' --glob '!**/sample*/**' \
  '<uses-permission|<uses-feature|<queries|usesCleartextTraffic|networkSecurityConfig|android:exported' .
```

```bash
rg -n --glob '!**/build/**' --glob '!**/demo/**' --glob '!**/*demo*/**' --glob '!**/sample*/**' \
  'onReceivedSslError|SslErrorHandler|proceed\\(|HostnameVerifier|X509TrustManager|TrustManager|SSLSocketFactory|SSLContext|addJavascriptInterface|setJavaScriptEnabled\\(true\\)' .
```

```bash
rg -n --glob '!**/build/**' --glob '!**/demo/**' --glob '!**/*demo*/**' --glob '!**/sample*/**' \
  'MANAGE_EXTERNAL_STORAGE|QUERY_ALL_PACKAGES|REQUEST_INSTALL_PACKAGES|REQUEST_DELETE_PACKAGES|READ_EXTERNAL_STORAGE|WRITE_EXTERNAL_STORAGE|READ_MEDIA_|CAMERA|RECORD_AUDIO|ACCESS_FINE_LOCATION|ACCESS_BACKGROUND_LOCATION|POST_NOTIFICATIONS|SCHEDULE_EXACT_ALARM|USE_FULL_SCREEN_INTENT|FOREGROUND_SERVICE|PACKAGE_USAGE_STATS|SYSTEM_ALERT_WINDOW|WRITE_SETTINGS' .
```

```bash
rg -n --glob '!**/build/**' --glob '!**/demo/**' --glob '!**/*demo*/**' --glob '!**/sample*/**' \
  'Runtime\\.getRuntime\\(\\)\\.exec|ProcessBuilder|ShellUtils|execCmd\\(|\\bsu\\b|pm install|pm uninstall|Uri\\.fromFile|file://|ACTION_MEDIA_SCANNER_SCAN_FILE|ClipboardManager|primaryClip|AdvertisingIdClient|ANDROID_ID|Log\\.|logD\\(' .
```

## 验证要求

- app：运行 release manifest 合并、`assembleRelease` 或最小可行 release 构建；检查最终 APK/AAB 中权限、组件、字符串和依赖。
- library：运行 `:module:assembleRelease`；解包 AAR 检查 `AndroidManifest.xml`、`classes.jar`、consumer rules。
- 聚合库：检查 `releaseRuntimeClasspath`，确认 unsafe/debug/optional 依赖没有被 `api` 带入。
- 权限改动：验证 Android 版本分支，尤其 Android 10、13、14、当前 targetSdk 对应版本。
- WebView/TLS：验证证书错误不会继续加载页面。
- 文件/媒体：验证导入、导出、分享、保存、相册可见、部分照片授权、拒绝权限路径。

## 最终输出要求

最终回答或文档必须包含：

- 范围：检查了哪些模块、哪些 demo/sample 未纳入。
- 依据：使用的官方文档链接和必要社区经验。
- 结论：`Pass` / `Warn` / `Block`。
- 问题清单：模块、文件/行号、风险原因、是否会进入最终产物。
- 修复方案：怎么改、为什么合规、是否需要用户决策。
- 业务影响：API 兼容、运行时行为、权限弹窗、用户体验、发布依赖变化。
- 验证：Gradle 命令、产物扫描命令、未验证项和残余风险。
