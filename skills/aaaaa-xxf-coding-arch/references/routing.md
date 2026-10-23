# 强制路由导航参考

> 本文档是 `aaaaa-xxf-coding-arch` 的路由细则：**页面跳转、Fragment 获取必须走路由框架，禁止反射**。
> 路由框架较多（KPower Router、ARouter、DRouter、Jetpack Navigation 等），本文按"框架无关硬规则 + 各框架落地方式"组织，避免规则绑定单一框架。

## 为什么强制路由

| 目标 | 直接跳转 / 反射跳转的问题 | 路由方案的价值 |
|---|---|---|
| 多模块 | 调用方必须依赖目标模块的 Activity/Fragment 类，feature 之间编译期强耦合，无法按模块单独裁剪 | 只依赖 URI 字符串，调用方模块无需依赖目标模块；目标模块可整体移除/替换 |
| 多变体 | 同一入口在不同 flavor/渠道/宿主写死同一个类，无法按变体替换页面 | 同一 URI 在不同变体的 `di/` 注册不同实现，调用方无感知 |
| 拦截 | 登录校验、权限、埋点、防抖、DeepLink 分发逻辑散落在每个跳转点，漏改必出事故 | 拦截器统一在路由链路处理，业务跳转零侵入 |
| 结果与失败 | 各页面自己 try/catch、自己 startActivityForResult，行为不一致 | 统一 `RoutingResult` 结果模型和 for-result 能力，失败可观测 |
| 反射 | `Class.forName` 等字符串实例化脆弱、R8 混淆后易碎、无编译期检查 | 显式类型注册，编译期可校验，混淆安全 |

## 框架无关硬规则

1. **所有页面跳转必须走路由**：启动 Activity、startActivityForResult、展示 DialogFragment，一律通过路由 URI 发起；不区分模块内外，模块内跳转也统一走路由，保证拦截、埋点、变体替换全局面生效。
2. **Fragment 获取必须走路由**：跨模块获取 Fragment 不允许直接构造 `TargetFragment()`、不允许 import 对方 `presentation` 类；通过路由注册 `registerFragment` 并按 URI 获取，容器事务由调用方负责。
3. **禁止反射**：`Class.forName(...)`、`className.newInstance()`、`Intent.setClassName(...)`、按字符串 tag/class 查找业务 Fragment、KClass 按名字查找等一律禁止；路由框架内部的实现机制不受此限制。
4. **注册集中在 `di/`**：路由表、URI 到页面/服务的绑定、拦截器、fallback 统一放各模块 `di/` 的路由 DSL 中，由 App root 聚合；不放在 `api/`、`presentation/` 或包根目录，不在 UI 层散落注册。
5. **URI 全局唯一、统一规划**：`scheme://模块/页面/{参数}` 结构由全局路由表约定，模块内新增 URI 先查表防撞名；URI 常量收敛在模块公开协议处，不在调用点硬编码散落字符串。
6. **沿用项目既有路由框架**：项目已选型的路由框架（ARouter、DRouter、KPower Router、Navigation 等）必须继续使用，不得混入第二套路由；新工程默认选 KPower Router（`core/di-android`），选型依据见下文。

## 禁止 / 允许对照表

| 场景 | 禁止写法 | 正确写法（以 KPower Router 为例） |
|---|---|---|
| 跨模块跳 Activity | `Intent(context, DetailActivity::class.java)` | `Router.instance.build("xxf://detail/42").startActivity()` |
| 模块内跳 Activity | `startActivity(Intent(this, SettingActivity::class.java))` | 同上，走路由 URI |
| 等待页面结果 | `startActivityForResult(intent, code)` + `onActivityResult` | `build(uri).startActivityForResult { activityResult -> ... }` |
| 获取业务 Fragment | `DetailFragment()` / `supportFragmentManager.findFragmentByTag("detail")` | `registerFragment<DetailFragment>(uri)` + `execute()` 取实例 |
| 展示弹窗 | `ConfirmDialogFragment().show(supportFragmentManager, tag)` | `registerDialogFragment<ConfirmDialogFragment>(uri)` 后按 URI 发起 |
| 打开外部/隐式意图 | 散落 `Intent(ACTION_VIEW, uri)` 直跳 | `registerIntent(uri) { Intent(...) }` 纳入路由 |
| 反射跳转 | `Class.forName("com.x.DetailActivity")`、`Intent.setClassName(pkg, cls)` | 一律禁止，改注册 + URI |
| DeepLink/推送跳转 | 自己 parse 字符串再反射拼 Intent | 走路由统一分发 + 拦截器 |

## KPower Router（di-android）落地

`core/di-android` 基于 `com.nbxxf.kpower:di-koin` 提供 Android 路由装配，是 xxf_android 工程默认路由方案。

### 注册（各模块 di/，App root 聚合）

```kotlin
val detailModule = module {
    routing {
        registerActivity<DetailActivity>("xxf://detail/{id}")
        registerFragment<DetailFragment>("xxf://detail-fragment/{id}")
        registerDialogFragment<ConfirmDialogFragment>("xxf://confirm")
        // 隐式意图或动态目标：工厂只设置目标，flags/extras 仍由路由统一合并
        registerIntent("xxf://open-web") {
            Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
        }
    }
}
```

- Activity 路由执行时使用当前栈顶 Activity，无前台页面时回退 Application Context。
- Fragment 路由只创建并返回 Fragment 实例，加入 FragmentManager 的事务由调用方负责。
- 参数来源三合一：query 参数、URI 模板参数（`{id}`）、`extras` 由路由核心合并后统一写入目标 `Bundle`。
- extras 值必须是 Bundle 可承载类型（基本类型、String、Bundle、Parcelable、Serializable、同质 String 数组）；不支持的类型会以 `RoutingResult.Failure` 失败，不会静默丢参。

### 页面跳转

```kotlin
// 一次性散参数
Router.instance.execute<Any?>(
    uri = "xxf://detail/42",
    extras = mapOf("source" to "main"),
)

// 构建器链式
Router.instance.build("xxf://detail/42")
    .query("tab", "info")
    .extra("source", "main")
    .flags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
    .startActivity()

// 目标存在性探测（用于动态入口显隐）
if (Router.instance.canExecute("xxf://detail/42")) { ... }
```

### startActivityForResult

```kotlin
Router.instance.build("xxf://detail/42")
    .extra("source", "main")
    .startActivityForResult { activityResult ->
        // activityResult: androidx.activity.result.ActivityResult，主线程回调
    }
```

约束：必须主线程发起；当前栈顶需为 `ComponentActivity`；仅 `registerActivity` / `registerIntent` 支持等待结果，Fragment/Dialog 路由的 onResult 永不触发；不要携带 `FLAG_ACTIVITY_NEW_TASK`（系统会立即以 RESULT_CANCELED 回调）。

### Fragment 获取

```kotlin
when (val result = Router.instance.build("xxf://detail-fragment/42").execute()) {
    is RoutingResult.Success<*> -> {
        val fragment = result.value as Fragment
        supportFragmentManager.beginTransaction()
            .replace(R.id.container, fragment)
            .commit()
    }
    is RoutingResult.NotFound -> Unit   // 路由未注册：目标模块未集成或 URI 拼错
    is RoutingResult.Rejected -> Unit   // 被拦截器拒绝：登录/权限等
    is RoutingResult.Failure -> Unit    // 执行失败：参数类型、目标缺失等
    is RoutingResult.Holding -> Unit    // 被拦截器挂起：等待条件满足后继续
}
```

### 拦截器（登录、权限、埋点、防抖的唯一落点）

```kotlin
val appModule = module {
    routing {
        registerInterceptor {
            object : RoutingInterceptor {
                override val priority: Int = 100   // 数值越大越先执行

                override fun intercept(chain: RoutingChain): RoutingResult<Any?> {
                    val uri = chain.context.request.uri
                    if (requiresLogin(uri) && !SessionManager.isLoggedIn) {
                        // 方案一：直接拒绝
                        return chain.reject("login-required")
                        // 方案二：先跳登录页，登录成功后 resume 继续
                    }
                    return chain.proceed(chain.context)
                }
            }
        }
        // 兜底：未匹配 URI 的统一处理（全局错误页、降级、上报）
        registerFallback { NotFoundFallbackHandler() }
    }
}
```

- 拦截器按 `priority` 排序链式执行，`chain.proceed(context)` 放行、`chain.reject(reason)` 拒绝、返回 `Holding` 挂起等待。
- 业务不得绕过路由自行实现"登录再跳转"逻辑，统一收敛到拦截器。

## 其他路由框架对应关系

项目已用其他框架时沿用既有框架，但本文硬规则（注册集中、URI 唯一、可拦截、禁反射）不变：

| 框架 | 页面跳转 | Fragment 获取 | 拦截 | 备注 |
|---|---|---|---|---|
| KPower Router（di-android） | `build(uri).startActivity()` | `registerFragment` + `execute()` | `registerInterceptor` | 默认方案，Koin 装配 |
| ARouter | `ARouter.getInstance().build(uri).navigation(...)` | `navigation(clazz)` / `Fragment` 注解目标 | `IInterceptor` | 不得退化为 `navigation(Class)` 直引类跳转；编译期字节码注入注意 R8 规则 |
| DRouter | `Router.build(uri).start()` | 服务/Fragment 注册获取 | 拦截器 | 同上，URI 跳转优先 |
| Jetpack Navigation / Compose Navigation | 同 nav graph 内按 destination route 跳转 | — | 导航回调/拦截 | destination route 即路由；跨模块不允许 import 对方 `Screen` composable，需路由 URI 或模块公开协议；单 Activity 架构见 `aaaaa-xxf-ui-technology-selection` |

## 常见违规与修正

### 违规：跨模块直接类引用跳转

```kotlin
// 调用方模块直接依赖 :feature-detail
startActivity(Intent(this, DetailActivity::class.java))
```

修正：目标模块 `di/` 注册 `registerActivity<DetailActivity>("xxf://detail/{id}")`，调用方 `Router.instance.build("xxf://detail/42").startActivity()`，并删除对 `:feature-detail` 的 Gradle 依赖。

### 违规：反射拼装目标

```kotlin
val target = Class.forName("com.xxf.feature.DetailActivity")
startActivity(Intent(this, target))
```

修正：删除反射；改注册 + URI。反射跳转同时违反 `aaaaa-xxf-code-shrinking-guard`（R8 后类名不可预测）。

### 违规：直接构造其他模块 Fragment

```kotlin
val fragment = DetailFragment()   // import 了对方 presentation 类
supportFragmentManager.beginTransaction().replace(R.id.container, fragment).commit()
```

修正：目标模块注册 `registerFragment<DetailFragment>("xxf://detail-fragment/{id}")`，调用方按 URI `execute()` 获取实例后自行提交事务。

### 违规：弹窗直接 show

```kotlin
ConfirmDialogFragment().show(supportFragmentManager, "confirm")
```

修正：注册 `registerDialogFragment<ConfirmDialogFragment>("xxf://confirm")`，统一走 URI 发起，使弹窗可被拦截、可被变体替换。

## 相关 skill

- `aaaaa-xxf-code-shrinking-guard`：禁反射与 R8 混淆规则的联动审计。
- `aaaaa-xxf-ui-technology-selection`：单 Activity + Compose Navigation 架构下的 destination 接入方式。
- `aaaaa-xxf-coding-arch`：本文的宿主规范，路由注册落点（`di/`）以宿主规范为准。
