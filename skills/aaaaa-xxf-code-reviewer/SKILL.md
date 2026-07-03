---
name: aaaaa-xxf-code-reviewer
description: 对 Android 项目改动做代码审查。用于跨模块、公共 API、生命周期、线程、权限、存储、网络、图片、下载、Gradle 发布配置等有回归风险的改动。
---

# 代码审查规则

审查输出以 findings 为先，按严重程度排序，包含文件和行号。

重点检查：

- 公共库 API 是否破坏调用方或 Maven 发布兼容性
- `api`/`implementation`/`compileOnly` 是否选择正确
- Activity/Fragment/View 生命周期、Context 持有、回调解绑、线程切换是否安全
- 是否存在网络层到业务层再到 UI 层的层层回调、匿名回调嵌套或回调地狱
- 是否把 JSON `String`、`Map`、`Bundle` 之类的弱类型数据当成跨层业务载体持续透传，而不是在边界转换成明确对象
- 权限、文件 URI、FileProvider、相册/相机、Android 版本兼容是否完整
- 网络、下载、RxJava、协程/线程、ObjectBox/Room 数据访问是否有竞态或泄漏
- 资源命名、Manifest provider/permission、ProGuard/R8 配置是否会影响宿主
- demo/sample 是否只验证用法，没有污染基础库

没有发现问题时，明确说明未发现 blocker，并列出未覆盖的验证风险。
