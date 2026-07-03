# aaaaa-xxf-coding-arch — 触发用例

## 应该触发

- "给这个 Android 模块补一下分层设计"
- "这个模块目录应该怎么放"
- "新增 feature 的 api/domain/repository/service/di/presentation 怎么拆"
- "Retrofit ApiService 应该放哪里"
- "DTO/PO/VO/Mapper 应该放哪个目录"
- "路由注册放 api 还是 di"
- "这段代码是否违反 Android 模块架构约束"
- "ViewModel 直接调 Repository 可以吗"
- "当前模块里这些杂项代码应该放哪"

## 不应该触发

- "Kotlin 语法怎么写" → 应走 `aaaaa-xxf-coding-style` 或语言基础说明
- "新增源码用 Java 还是 Kotlin" → 应走 `aaaaa-xxf-language-selection`
- "新增一个 Android library 模块的 Gradle 怎么写" → 应走 `aaaaa-xxf-module-scaffold`
- "这个功能最小要测哪些" → 应走 `aaaaa-xxf-test-strategy`
- "帮我 review 这次改动" → 应走 `aaaaa-xxf-code-reviewer`
- "某个 XXF 库 API 怎么用" → 应走对应模块 skill

## 边界用例

- "我想临时在 Fragment 里直接请求网络"
  - 期望：触发，并指出应走 `presentation → service → repository → api`，Retrofit ApiService 只放 `api/`
- "这个模块有些代码不属于 api/domain/repository/service/di/presentation"
  - 期望：触发，并要求放入 `common/`，同时确认没有承载业务主流程
- "路由表和页面绑定注册放哪里"
  - 期望：触发，并要求放入 `di/`，不要放在 `api/`、`presentation/` 或包根目录
