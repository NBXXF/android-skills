# Kotlin 惯用法改写对照表

> 写新代码与重构时对照使用：左边是 AI 常见的"乱"写法，右边是惯用写法。每条给最小可读改写，不追求技巧。涉及性能口径（重组、稳定性、序列化）时以 `aaaaa-xxf-android-performance-gate`、`aaaaa-xxf-flow-guide` 为准。

## 1. Java 风格残留 → 惯用 Kotlin

```kotlin
// ✗ 手写 getter/setter
class User {
    private var name: String = ""
    fun getName() = name
    fun setName(n: String) { name = n }
}
// ✓ 属性即 API
class User(var name: String = "")

// ✗ 匿名内部类
button.setOnClickListener(object : View.OnClickListener {
    override fun onClick(v: View?) { submit() }
})
// ✓ lambda（可空参数也省掉）
button.setOnClickListener { submit() }

// ✗ Java 式单例
class SessionStore {
    companion object {
        private var instance: SessionStore? = null
        @JvmStatic fun get(): SessionStore =
            instance ?: SessionStore().also { instance = it }
    }
}
// ✓ object 声明（需可替换/测试时再谈 DI，不写 getInstance 样板）
object SessionStore { ... }

// ✗ index 循环遍历集合
for (i in 0 until items.size) { println(items[i]) }
// ✓ 直接迭代或操作符
items.forEach { println(it) }

// ✗ 手写 builder 模式（Java 补默认参数的产物）
val req = Request.Builder().setUrl(url).setMethod("GET").setTimeout(30).build()
// ✓ 默认参数 + 命名参数
data class Request(val url: String, val method: String = "GET", val timeoutSec: Int = 30)
Request(url = url)

// ✗ 显式类型标注到处写
val names: List<String> = listOf<String>()
// ✓ 类型推断（公共 API 签名保留显式类型，它文档化了契约）

// ✗ new 式工厂噪音 / 无意义伴生包装
// ✓ 顶层函数直接做工厂：fun newUser(...) = User(...)
```

## 2. 空安全

```kotlin
// ✗ !!（把编译器检查换成运行时崩溃）
val city = user!!.address!!.city
// ✓ 安全调用链 + 语义兜底
// 注意边界：`?: "unknown"` 是"缺失时合法的业务默认值"（OK）；
// 若 null 意味着"上游出错了"，改走显式失败分支（见下），不许兜底掩盖
val city = user?.address?.city ?: "unknown"

// ✗ 嵌套 let
user?.let { u -> u.address?.let { a -> a.city?.let { c -> show(c) } } }
// ✓ 安全调用链，末端一次 let
user?.address?.city?.let(::show)

// ✗ 判空后手动 throw
val v = map[key]
if (v == null) { throw IllegalStateException("missing") }
use(v)
// ✓ require/check 一行表达（require=入参，check=状态）
val v = checkNotNull(map[key]) { "missing" }

// ✗ 平台类型（Java 返回值）直接往深处传
val name = javaApi.userName   // String! 传染
// ✓ 接收处立即定型：显式可空标注 + 一次处理
val name: String? = javaApi.userName

// ✗ ?: 兜底掩盖错误（脏数据被静默替换）
val age = text.toIntOrNull() ?: 0
// ✓ 失败进显式分支（可失败建模，见 §7）
val age = text.toIntOrNull() ?: return showError(...)

// ✗ 一路 ? 到底（nullable 当状态机用）
// ✓ 能保证非空用非空类型 + require；延迟初始化用 by lazy / lateinit 并注明时机
```

## 3. 集合与序列

```kotlin
// ✗ 手写过滤+收集
val actives = mutableListOf<User>()
for (u in users) if (u.isActive) actives.add(u)
// ✓ 标准库（链式 ≤3 层，更深拆中间变量）
val actives = users.filter { it.isActive }

// ✗ 手写映射建 Map
val byId = HashMap<String, User>()
for (u in users) byId[u.id] = u
// ✓ associateBy / groupBy / partition
val byId: Map<String, User> = users.associateBy { it.id }
val byDept: Map<Dept, List<User>> = users.groupBy { it.dept }
val (active, inactive) = users.partition { it.isActive }

// ✗ 手写聚合
var total = 0.0
for (o in orders) total += o.amount
// ✓ sumOf / maxByOrNull / count ...
val total = orders.sumOf { it.amount }

// ✗ 需要下标和值时 index 循环
// ✓ forEachIndexed / withIndex / indices

// ✗ 可变集合到处传
fun process(items: MutableList<String>) { ... }
// ✓ 只读类型做参数，需要副本再 toList()
fun process(items: List<String>) { ... }

// ✗ 小集合无脑 asSequence（增加一层惰性包装，可读性下降）
// ✓ sequence 只用于：大集合 + 多步变换 + 可提前终止（take/firstOrNull）

// ✗ 在循环里反复 list.contains（O(n²)）
// ✓ 先 toSet()/associateBy() 再查（O(1)）
```

## 4. scope 函数决策

| 函数 | 用途 | 反例 |
|---|---|---|
| `let` | nullable 转换/非空才执行：`x?.let { }` | 嵌套 let、非空对象上也包 let |
| `apply` | 对象初始化配置，返回对象本身：`Intent().apply { }` | apply 里做业务逻辑/返回别的 |
| `also` | 链上插入副作用（日志/埋点），不断链 | 用 also 改写主流程数据 |
| `run` | 限定作用域算一个值 | 多个 run 嵌套 |
| `with` | 对同一对象多次调用（非扩展场景） | 可空对象上用 with |

```kotlin
// ✗ 非空对象硬包 let（噪音）
val name = user.let { it.name }
// ✓ 直接访问
val name = user.name

// ✗ apply 里塞业务
user.apply { save() }
// ✓ 职责分明
user.apply { validate() }.also { save(it) }   // 或就分开写
```

## 5. 函数与表达式

```kotlin
// ✗ 单表达式包函数体
fun isAdult(age: Int): Boolean { return age >= 18 }
// ✓ 表达式体
fun isAdult(age: Int): Boolean = age >= 18

// ✗ if/return true/false
fun isValid(s: String): Boolean { return if (s.isNotEmpty()) true else false }
// ✓ 直接返回
fun isValid(s: String): Boolean = s.isNotEmpty()

// ✗ 箭头型嵌套
fun handle(resp: Resp) {
    if (resp != null) {
        if (resp.isSuccess) {
            if (resp.data != null) { render(resp.data) }
            else { showEmpty() }
        } else { showError() }
    }
}
// ✓ guard clause 拉平 + 早返回
fun handle(resp: Resp?) {
    val data = resp?.takeIf { it.isSuccess }?.data ?: return showEmpty()
    render(data)
}

// ✗ 复杂条件裸奔（A && !B || C 谁也读不懂）
if (user.isActive && !user.isBanned && user.age > 18 && user.hasVerifiedEmail) { ... }
// ✓ 提取命名谓词（条件有了名字，还可在测试里直接用）
val canRegister: Boolean get() = isActive && !isBanned && age > 18 && hasVerifiedEmail
if (user.canRegister) { ... }

// ✗ 字符串拼接 + MessageFormat
"Hello, " + user.name + " (" + user.id + ")"
// ✓ 模板
"Hello, ${user.name} (${user.id})"
```

## 6. 数据建模与委托

```kotlin
// ✗ 可变数据类（data class 的 equals/copy 全白给，还引入共享可变状态）
data class Cart(var items: List<Item>, var total: Double)
// ✓ 不可变 + copy 派生
data class Cart(val items: List<Item>) {
    val total: Double get() = items.sumOf { it.price }
}
fun Cart.addItem(i: Item) = copy(items = items + i)

// ✗ 手写缓存/延迟字段
private var cached: Config? = null
fun config(): Config {
    if (cached == null) cached = load()
    return cached!!
}
// ✓ by lazy（线程安全语义明确）
private val config: Config by lazy { load() }

// ✗ 手动转发接口实现
class LoggingRepo(private val repo: Repo) : Repo {
    override fun get(id: String) = repo.get(id)
    override fun put(item: Item) = repo.put(item)   // 20 个方法 19 个纯转发
}
// ✓ 接口委托，只覆写需要的
class LoggingRepo(private val repo: Repo) : Repo by repo {
    override fun put(item: Item) { log(item); repo.put(item) }
}

// ✗ 魔法数字
delay(5000)
// ✓ 命名常量（companion const 或顶层 private const）
delay(RETRY_DELAY_MS)
```

## 7. 错误处理建模

```kotlin
// ✗ 异常做控制流（预期内分支走异常）
try { val user = findUser(id); render(user) }
catch (e: NotFound) { showEmpty() }
// ✓ 预期内用 nullable/结果类型，异常留给真正的异常
val user = findUserOrNull(id) ?: return showEmpty()
render(user)

// ✗ try-catch 包一大坨（吞掉范围外异常，错误定位困难）
try { parse(); validate(); save(); notify() } catch (e: Exception) { log(e) }
// ✓ 缩小范围 + runCatching 表达失败
val parsed = runCatching { parse(raw) }
    .getOrElse { return handleParseError(it) }

// ✗ 状态用多个布尔并行表示（非法组合可表示：isLoading=true 且 isSucceed=true）
val isLoading: Boolean; val isSucceed: Boolean; val error: Throwable?
// ✓ sealed 状态机（非法状态不可表示，when 穷尽）
sealed interface UiState<out T> {
    data object Loading : UiState<Nothing>
    data class Success<T>(val data: T) : UiState<T>
    data class Failed(val cause: Throwable) : UiState<Nothing>
}

// ✗ 入参校验散落在函数体各处
// ✓ require（入参）/check（状态）前置，失败信息带上下文
fun transfer(from: Account, amount: Money) {
    require(amount.value > 0) { "amount must be positive: $amount" }
    check(from.balance >= amount) { "insufficient: ${from.balance} < $amount" }
}
```

## 8. 协程与 Flow 精炼

> 操作符选型、链路设计、线程调度细节归 `aaaaa-xxf-flow-guide`；本节只管"写法冗余"。

```kotlin
// ✗ 冗余 withContext（目标线程与当前一致）
suspend fun save(item: Item) = withContext(Dispatchers.IO) { dao.save(item) }
// ✓ suspend 函数主线程安全交给最内层实现，中间层不加调度包装

// ✗ suspend 里手动回调包装（Continuation 样板）
// ✓ suspendCoroutine 只写一次在适配层，业务直接 await 风格调用

// ✗ 串行 await 两个独立请求
val a = fetchA(); val b = fetchB()
// ✓ coroutineScope + async 并行
coroutineScope {
    val a = async { fetchA() }; val b = async { fetchB() }
    use(a.await(), b.await())
}

// ✗ GlobalScope.launch（脱离结构化并发，泄漏+不可取消）
// ✓ 生命周期作用域（viewModelScope/lifecycleScope）或注入的 scope

// ✗ 重复的 launch { try { } catch { } } 包装
// ✓ Flow 操作符链统一处理（catch/onCompletion），见 flow-guide
```

## 9. Compose 可读性

> 重组性能、稳定性、Lazy 调优归 `aaaaa-xxf-android-performance-gate`；本节只管代码可读性。

```kotlin
// ✗ 重复 modifier 链
Text("A", modifier = Modifier.padding(16.dp).fillMaxWidth())
Text("B", modifier = Modifier.padding(16.dp).fillMaxWidth())
// ✓ 提取复用（还保证了未来一致）
val itemModifier = Modifier.padding(16.dp).fillMaxWidth()

// ✗ 无谓的容器嵌套
Column { Row { Box { Text("hi") } } }
// ✓ 删掉只装一个孩子的容器；对齐用 Modifier（align/Arrangement）

// ✗ 参数爆炸的 Composable（12 个参数一行调用读不动）
@Composable fun Card(title: String, subtitle: String, ..., showBadge: Boolean, ...)
// ✓ 语义分组参数对象 + 默认值
data class CardUiModel(val title: String, val subtitle: String = "", ...)
@Composable fun Card(model: CardUiModel, modifier: Modifier = Modifier)

// ✗ 条件渲染塞满 && 和多重 if
if (showHeader) { if (items.isNotEmpty()) { LazyColumn { ... } } }
// ✓ when/if 表达式 + guard 拉平；空态/加载态/内容态显式分支
when {
    items.isEmpty() -> EmptyPlaceholder()
    else -> ContentList(items)
}

// ✗ preview 函数与组件实现挤在一个文件几十个
// ✓ preview 集中放 xxxPreview.kt，实现文件只留组件本体
```

## 10. 判断"这版更好"的检验

改写后逐条问：

1. 行为是否逐输入等价（输出、异常、副作用、时序）？不确定就不改。
2. 新读者要持有的概念数是否变少了？
3. 是否仍符合本文件/本模块既有风格？
4. 有没有把复杂度只是挪了个位置？
5. diff 是否只含本次必要改动？
