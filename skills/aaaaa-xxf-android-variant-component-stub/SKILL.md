---
name: aaaaa-xxf-android-variant-component-stub
description: Android 变体/马甲包共享组件与路由助手。用于“马甲包组件”“变体组件”“占位组件”“applicationId 占位”“Manifest 占坑”“马甲包路由”“多渠道共用组件”“白标/品牌包”“渠道包”“flavor/suffix 变体”“VariantComponentStub 接入/教程”“马甲包上架误判/触发词治理”等场景；引导读取 `references/variant-component-stub.md`、`references/store-compliance-differentiation.md` 和 `trigger.md`，按 EXTENDS/COPY 模式选择、公共库标注、宿主占位注册、路由常量清单、Application 批量注册、URI 跳转、排错与合规差异化给出分步方案。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android 变体/马甲包组件与路由

## 目的

这个 skill 用于回答和处理 Android 变体/马甲包(multi-brand)工程中共用业务组件的生成与路由问题，重点覆盖：

- `@VariantComponentStub` 注解接入(公共库与 app 源码组件)
- 路由常量清单(`const val` 集中声明)与注解引用
- Manifest `${applicationId}.Xxx` 占位注册(占坑)
- `mode = VariantComponentStubMode.EXTENDS`（默认）空壳继承与 `COPY` 实现拷贝
- Gradle 插件 `com.xxf.variant-component-stub` 按变体生成组件类
- flavor / `applicationIdSuffix` 马甲包矩阵
- 宿主自定义 Application 直引生成 RouterTable 批量注册 di-android 路由
- 业务按稳定 URI 跳转(`Router.instance.execute`),不感知 applicationId
- 组件约束校验、名称/URI 冲突、R8 混淆边界
- 索引版本、stub 生成数为 0 等故障排查
- 变体真实差异化、上架误判(重复内容/克隆)应对与触发词治理(合规方向)

## 使用方式

1. 用户在问“马甲包怎么做多渠道共用组件”“Manifest 怎么按 applicationId 占位”“变体组件怎么接”“马甲包路由怎么统一”，归到这个 skill。
2. 先读 `references/variant-component-stub.md`，它是完整接入参考。
3. 上架被误判重复内容/克隆、触发词/敏感词误伤、品牌差异化相关,读
   `references/store-compliance-differentiation.md`。
4. 再读 `trigger.md` 补充触发表达识别(按产品形态/构建体系/组件注解/路由/混淆发布/报错/场景分组)。
5. 用户要“教程”“步骤”时按教程式回答，顺序固定：选择 mode 并按文件标注公共库组件 → 宿主插件与 Manifest 占位 → 路由注册 → URI 跳转 → 验证构建。
6. 用户只改某一步(如“加一个马甲包渠道”“组件类名冲突”)时，直接给该步骤的最小改动。

## 回答要求

- 先区分角色：公共库(library)只接 KSP 注解，宿主(app)只接 Gradle 插件，两边职责不要混。
- `uri` 是注解必填参数且全 app 唯一，必须引用公共库 `const val` 常量，不允许裸字符串。
- Application 由宿主业务统一定义、不参与变体 stub 生成；路由批量注册写在这个自定义 Application 里。
- 依赖三件套(annotation/processor/gradle-plugin)必须同版本，版本不一致会报“索引版本不兼容”。
- 优先给最小可用示例，再补 flavor/suffix、R8、Java 路由表等高级配置。
- `mode` 按组件选择，可混用；未填写时为 EXTENDS。final 报错先区分是否确需继承，不能一律要求加 open。
- 涉及 final 组件、复制实现、无继承需求或 mode 参数时，读取参考文档的“mode 参数与模式选择”和“COPY 模式”。
- COPY 示例单独放文件，补齐枚举 import 和路由常量定义；不把多个被标注组件塞进同一个 COPY 文件。
- COPY 不保证可转换为原类，也不自动补无参构造、注入依赖或改写外部 Intent；正文同包引用需显式 import，库 API/依赖须对宿主可见。
- 按当前首次接入场景给用法，不主动展开索引格式版本或升级迁移。
- 组件报错先确认 mode，再按参考文档的模式对比、COPY 使用边界与公共名称约束排查。
- 验证两种生成链路：library 产物由宿主 generate 消费，app 源码由 KSP 生成；构建实际变体并检查 Manifest、路由 Class 和 release/R8。
- 上架/触发词类问题只给**合规差异化与关键词治理**方案(flavor 资源、按 flavor 模块组合、
  构建期敏感词扫描、文案改写、申诉路径);不提供审核期隐藏、过审后切换、触发词加密躲机审、
  换皮重复上架、多账号对抗关联等规避审核的做法,并说明其政策风险。
- 示例面向外部工程:统一用 Maven 坐标 `com.NBXXF.xxf_android:...` 与通用模块名,
  不引用本 skill 仓库的工程路径或任务。
