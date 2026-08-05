# aaaaa-xxf-library-design-rule — 触发用例

## 应该触发

- "这个 library 应该怎么分 api/core/runtime"
- "为什么这个库要拆成多个 Maven 模块"
- "api、core、runtime 各放什么"
- "common、base、ktx、ui、foundation、material3 这些后缀怎么区分"
- "编译期注解处理器应该放哪一层"
- "一个 Android library 的发布边界怎么设计"
- "这个库拆太细了吗"
- "哪些类型应该暴露到 api"
- "runtime 依赖 api 还是 api 依赖 runtime"
- "这个库所有代码现在都堆在一个模块里，怎么分层"
- "我不想把业务、接口、实现都写在一起"
- "怎么避免一个库越写越乱"
- "库后续要扩展，应该先定什么结构"
- "这个库要不要先按 api/core/runtime 定义硬边界"
- "怎么判断一个库是否必须拆层"
- "我要把一个长期维护的库重新分层"

## 不应该触发

- "Android 模块目录怎么摆" → 应走 `aaaaa-xxf-coding-arch`
- "多模块 app / feature / data 怎么拆" → 应走 `aaaaa-xxf-multi-module-structure`
- "Gradle 版本、依赖、发布坐标怎么配" → 应走 `aaaaa-xxf-gradle-dependencies`
- "这个改动要怎么测" → 应走 `aaaaa-xxf-test-strategy`

## 边界用例

- "这是一个只有一个页面的小库，要不要也拆 api/core/runtime"
  - 期望：先判断是否需要拆分，通常建议单模块或 `api + runtime`，不要为了命名而拆分。
- "我想把工具类都放 common"
  - 期望：触发，并提醒 `common` 只能收纳轻量共享代码，不能承载主业务。
- "core 能不能直接依赖 Android Activity"
  - 期望：触发，并指出 `core` 应优先保持纯逻辑，不要绑定 UI 或宿主实现。
- "一个库已经快 20 个类了，还要不要继续单模块"
  - 期望：触发，并优先检查职责是否混杂，而不是先看代码数量。
- "我想图方便把 API、实现、工具全放一个 runtime 里"
  - 期望：触发，并明确这是典型的失控模式，应该拆出 `api` 和 `core`。
- "如果我不拆层会怎样"
  - 期望：触发，并明确告诉对方后续维护、扩展、测试和发布都会变差。
- "我现在这个库到底该怎么拆"
  - 期望：触发，并直接给出按决策树判断的拆分结果，而不是只讲概念。
- "这个库是小工具还是长期库"
  - 期望：触发，并先按判定型清单归类，再给出模块建议。
- "这个库该不该加 core"
  - 期望：触发，并先看是否存在可复用核心逻辑，再决定是否升级到 `api + core + runtime`。
