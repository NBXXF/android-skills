---
name: aaaaa-xxf-android-performance-gate
description: Android 项目性能风险门禁。用于 UI 渲染、Compose UI 性能（重组、稳定性、Lazy 列表、动画、自定义 Layout/modifier）、RecyclerView、图片、启动、主线程、下载/网络热路径、数据库和大文件处理改动。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android 性能门禁

## 自动触发

- Compose UI：`@Composable` 页面/组件、Lazy 列表/网格/瀑布流、动画与手势、自定义 Layout/绘制、自定义 modifier、状态管理与 Flow 收集，以及卡顿、掉帧、滚动不稳、启动慢、重组过多类问题。
- UI 布局、View、自定义绘制、RecyclerView/Adapter、动画。
- 图片加载、预览、相册、相机、二维码、MLKit。
- 下载、M3U8、网络请求、数据库、文件 IO。
- Application 初始化、全局单例、主线程调度。

## 检查点

- Compose 改动按三轴诊断（参数稳定性/State 读取阶段/跨阶段回写）逐类过检，命中任一类必须读 `references/compose-ui-performance.md` 再下结论。
- 主线程是否做网络、数据库、大文件、解码、压缩、扫描。
- 列表是否重复创建对象、重复绑定图片、缺少局部刷新。
- 图片/媒体是否有尺寸、缓存、生命周期和取消策略。
- 下载/网络是否有取消、重试、限流和资源释放。
- 可选 SDK 是否因强依赖增加宿主包体或初始化成本。

## 需要按需读取的 references

- 触及或审查任何 Compose UI（页面、Lazy 列表、动画、自定义 Layout/modifier、状态与 Flow）时，读取 `references/compose-ui-performance.md`：度量纪律（release+R8+真机）、三轴诊断、延迟读取与回写、Strong Skipping 下的稳定性口径、Lazy/副作用/布局/动画图形/自定义 modifier 规则、审计执行口径与版本速查。

## 结论

输出 `Pass/Warn/Block`。Warn/Block 必须说明需要的补充验证，例如 demo 滚动验证、弱网验证、内存观察、启动链路检查或真机设备能力验证；Compose 改动还需说明测量口径（release+R8+真机与否）与重组计数/帧指标证据，无法测量时列为残余风险。
