# Android 变体/马甲包组件与路由触发词

这个文件用于补充变体/马甲包组件 skill 的触发表达,按插件能力域分组堆全,
命中任意一组即可进入本 skill。

## 一、产品与业务形态

- 马甲包、马甲、马甲矩阵、马甲包怎么做
- 换包、白标、white-label、OEM、贴牌、贴牌包
- 多品牌、品牌包、品牌矩阵、一码多牌
- 渠道包、多渠道、渠道分包、海外包、国内包
- 同源应用、一套代码多个 app、一套代码多渠道、复用代码发多个应用
- 共享业务组件、共用组件、公共库组件复用
- 变体、variant、按变体、变体差异、变体矩阵

## 二、构建体系与产物

- productFlavors、flavor、flavorDimensions、dimension、渠道维度
- applicationId、applicationIdSuffix、包名后缀、debug 后缀
- namespace、包名、包名冲突
- manifestPlaceholders、Manifest 占位符、${applicationId}、Manifest merger、清单合并
- 占位注册、占坑、占坑注册、Manifest 占坑
- 构建期代码生成、编译期生成、generate source、生成源码
- KSP、ksp、symbol processing、annotation processor、注解处理器
- 增量构建、up-to-date、build cache、FROM-CACHE、任务缓存
- scan task、generate task、编译类路径、compileClasspath
- 索引、组件索引、索引类、AAR 索引、classes.jar、随库发布
- android-classes-jar、artifact view、变体感知、Variant Sources API
- 升级迁移、索引版本、版本不兼容、同版本三件套

## 三、组件注解与空壳生成

- VariantComponentStub、@VariantComponentStub、VCS
- variant-component-stub、com.xxf.variant-component-stub
- 空壳类、壳类、stub、生成子类、继承生成、派生入口
- 占位组件、占位类、占位 Activity、占位 Service
- uri、路由键、name 改名、name 消歧、跨库同名
- open class、可继承、顶层类、public 组件
- 无参构造、默认参数构造、构造可见性、protected 构造、internal 构造
- 抽象成员、sealed、类型参数、final 报错
- 保留名、R 类冲突、BuildConfig 冲突
- 自冲突、源类与生成类同名、同包同名
- applicationId 包、按包名生成、生成到 applicationId 包下
- ContentProvider authorities、按变体 authorities

## 四、路由体系

- RouterTable、路由表、变体路由表、生成路由表
- 路由注册、批量注册、registerHandler、RoutingActivityHandler
- startKoin、Koin、Koin module、di-android、KPower
- Router.instance、execute、RoutingResult、路由失败、路由未找到
- 路由常量、const val、编译期常量、常量清单、路由清单
- uri 冲突、uri 重复、uri 唯一
- deeplink、scheme、按品牌 scheme、uri scheme
- 路由跳转、按 uri 跳转、变体无关跳转
- 路由表输出、routerConfig、className、.kt/.java 输出
- 空路由表、空表生成
- 路由聚合、app 模式、库模式、跨源查重

## 五、混淆与发布

- R8、ProGuard、混淆、minify、shrinkResources
- keep 规则、consumer rules、是否需要 keep
- 映射文件、mapping、预混淆 AAR、AAR 消费
- 签名、keystore、按品牌签名
- 发布坐标、Maven、mavenLocal、SNAPSHOT、发布版本
- publish、发布插件、processor 发布

## 六、常见报错与排错场景

- 索引版本不兼容、请使用同版本 annotation/processor 重新构建
- 组件生成数为 0、库组件不生成、stub 不生成、路由表为空
- KSP 被跳过、processor 没跑、注解不生效
- uri 重复报错、stub 类名重复报错、保留名报错
- 构造校验失败、抽象成员未实现、类不可继承
- 父类依赖不可见、AppCompatActivity 找不到
- unitTest 行为、测试源集
- Manifest 占位不生效、生成的类 Manifest 找不到
- R8 后路由失效、release 混淆后跳转失败

## 七、典型任务场景

- 新增一个马甲渠道怎么做
- 马甲包怎么共用一套 Activity/Service
- 公共库组件怎么标注、怎么被宿主发现
- app 自己的组件怎么按变体生成
- 主入口 Activity 怎么按渠道换包名
- 每个品牌给不同功能集怎么做
- 广告/统计按渠道初始化,组件层怎么配合
- 马甲包路由怎么统一、跳转怎么写不感知渠道
- debug 包带后缀时占位类怎么生成
- 库发 AAR 后宿主怎么消费组件索引
- 三件套怎么升级、旧索引库怎么办
- 上架被误判重复内容/克隆怎么办(转 store-compliance-differentiation.md)
- 触发词/敏感词误伤怎么治理(转 store-compliance-differentiation.md)

## 不应该触发

- 普通 Intent 跳转、deeplink 协议设计(与变体无关时)
- 不涉及多渠道/变体的单包工程组件化
- ProGuard/R8 通用混淆问题(仅当与生成 stub/路由表共存时触发)
- 纯违反政策的"过审包/隐藏功能/审核期伪装"诉求:本 skill 只给合规差异化与
  触发词治理方案,不提供规避审核的做法
