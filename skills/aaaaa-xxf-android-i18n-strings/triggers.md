# aaaaa-xxf-android-i18n-strings — 触发用例

## 应该触发

- "这个 Android 页面不要硬编码文案"
- "把这些 Toast/Dialog/Snackbar 文案提取到 strings.xml"
- "新增按钮标题、输入框 hint、错误提示、空态提示"
- "Compose 里 Text(\"加载失败\") 这种要怎么处理"
- "XML 里 android:text 写死了，帮我国际化"
- "把 \"欢迎\" + name + \"回来\" 改成可国际化"
- "检查这次改动有没有硬编码显示文案"
- "已有代码里中文/英文提示语帮我提取资源"
- "contentDescription/label/menu title/preference summary 要补国际化"
- "错误码映射成本地提示文案时怎么命名 string key"
- "切换应用语言优先用什么 API，别手写 AppCompatDelegate"
- "全局取字符串时优先用 lib_i18n 还是直接 applicationContext.getString"
- "这个 demo/sample 页面上的展示文案也顺手处理下"
- "Navigation graph/menu/preference 里的 title/summary 写死了"
- "DataBinding 里 @{\"欢迎 \" + name} 怎么国际化"
- "Spinner/Dialog 列表选项写在代码里了"
- "数量文案用 string 还是 plurals"
- "品牌名/AppName 要不要翻译"
- "无障碍 contentDescription 和通知文案也查一下"

## 不应该触发

- "新增接口 path /user/login" → 这是协议常量，不应提取到 `strings.xml`
- "build.gradle 里的 applicationId/flavorName/versionName 要不要提取" → 这是构建配置，不应提取
- "gradle.properties 里的开关和地址有硬编码" → 这是配置，不应提取到 Android string resource
- "libs.versions.toml 里的版本号/依赖坐标" → 这是构建配置，不应提取
- "JSON/YAML/properties config 里的 key 和 value" → 默认是业务/运行配置，不应提取
- "SharedPreferences key 怎么命名" → 这是存储 key，不应走文案国际化
- "DataStore key、Bundle extra、Intent action、路由参数有字符串" → 这是机器契约，不应提取
- "埋点 eventName 写什么" → 这是埋点契约，不应提取
- "日志 tag 统一一下" → 这是开发诊断标识，不应提取
- "BuildConfig 里配置渠道名" → 这是构建配置，不应提取
- "JSON 字段名和服务端枚举值怎么维护" → 这是接口契约，不应提取
- "路由 path/deeplink 怎么设计" → 这是路由契约，不应提取
- "签名、hash、缓存 key、实验分桶参数里的字符串" → 参与业务运算和匹配，不应提取
- "Compose Preview name 或截图测试名称有英文" → 开发/测试标识，不应提取
- "style parent、theme attr、drawable/layout/color 名称有字符串" → 资源契约，不应提取
- "public.xml 或公共库已有 string key 要改名" → 可能破坏宿主覆盖或外部引用，不应无关改名
- "String.format(Locale.US, \"%s_%d\", id, index) 生成文件名" → 机器格式，不应提取
- "单元测试 fixture 里有硬编码字符串" → 默认不触发，除非 fixture 是 UI 展示快照
- "Kotlin 新文件用 Java 还是 Kotlin" → 应走 `aaaaa-xxf-language-selection`
- "帮我 review 这次改动" → 可由 `aaaaa-xxf-code-reviewer` 主导，本 skill 只负责文案国际化检查点

## 边界用例

- "const val ERROR_NETWORK = \"网络异常\"，最后会显示给用户"
  - 期望：触发。不要继续用逻辑常量承载展示文案；迁移为 `R.string.*`，调用处用 `getString`。
- "const val API_STATUS_OK = \"ok\""
  - 期望：不提取。该值是服务端协议枚举，保留常量。
- "buildConfigField(\"String\", \"CHANNEL\", \"\\\"google_play\\\"\")"
  - 期望：不提取。该值影响构建产物和渠道逻辑，不能迁移到 `strings.xml`。
- "flavorDimensions += \"env\" / productFlavors { create(\"prod\") }"
  - 期望：不提取。Gradle flavor/buildType/sourceSet 字符串都是构建契约。
- "remote_config_key = \"home_card_style\""
  - 期望：不提取。远端配置 key 参与配置读取和业务分支。
- "if (status == \"paid\") 展示 \"已支付\""
  - 期望：只提取展示文案“已支付”；`\"paid\"` 是业务状态值，必须保留常量或枚举。
- "\"删除\" 既是按钮文案，又是埋点 action 名"
  - 期望：触发并拆分来源。按钮使用 `@string/...`，埋点 action 保留业务常量。
- "\"CNY\"、\"USD\"、\"kg\" 参与金额/单位换算"
  - 期望：不提取。参与运算或格式规则的 code/单位标识不能资源化；只有最终展示句子需要本地化。
- "显示 \"金额：%1$s CNY\""
  - 期望：触发。展示模板要资源化；`CNY` 如果是业务货币 code 仍由业务数据传入，不要变成翻译文案。
- "品牌名 \"XXF\" 在标题中展示"
  - 期望：触发但谨慎。若品牌所有语言保持一致，放入 `strings.xml` 并设置 `translatable=\"false\"`，或复用既有 brand/app_name key。
- "arrayOf(\"全部\", \"待支付\", \"已完成\") 作为筛选 tab 展示"
  - 期望：触发。迁移为 `string-array` 或多个 string key；筛选业务状态值必须另行保留。
- "arrayOf(\"all\", \"pending\", \"done\") 作为接口状态参数"
  - 期望：不提取。这是服务端枚举/过滤条件。
- "navigation.xml 里 android:label=\"订单详情\""
  - 期望：触发。Navigation label 是用户可见标题，应使用 `@string/...`。
- "Preference app:summary=\"开启后自动同步\""
  - 期望：触发。Preference 标题/摘要是用户可见文案。
- "Compose Preview @Preview(name = \"Empty State\")"
  - 期望：不提取。Preview 名称是开发工具标识。
- "Remote config 返回 title 文案并要求原样展示"
  - 期望：不提取该服务端文案；本地 fallback title 仍需要提取。
- "已有 strings.xml 里的 key 被宿主覆盖"
  - 期望：不要随意重命名或删除。公共库资源名可能是对外契约。
- "\"第\" + index + \"页\""
  - 期望：触发。迁移为一个格式化 key，例如 `<string name=\"pager_page_index\">第 %1$d 页</string>`。
- "\"剩余\" + count + \"次\""
  - 期望：触发。优先判断是否需要 `plurals`；不需要复数规则时也应使用完整格式化字符串。
- "Text(\"${count} items\")"
  - 期望：触发。英文硬编码展示文案也要提取，不只处理中文。
- "服务端返回 message 直接展示"
  - 期望：谨慎处理。服务端要求原样展示时不本地化；本地兜底、错误码映射和默认提示必须提取。
- "Log.d(TAG, \"加载失败\")"
  - 期望：默认不提取。若同一字面量也展示给用户，应为展示路径单独建 string key。
- "android:label=\"AppName\""
  - 期望：触发。Manifest label 是用户可见文案，应使用 `@string/app_name` 或模块既有命名。
- "contentDescription 写死图标说明"
  - 期望：触发。无障碍文案属于用户可见文案，必须资源化。
