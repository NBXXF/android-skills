# Gradle sync 拉取 skill 配置教程

这个 usecase 用于在 Android Studio / IntelliJ IDEA Gradle sync 时，自动 best-effort 执行 `setup-ai-skills.sh`，并额外提供一个可手动执行的 Gradle task。

## 目标

- IDE 执行 Gradle sync 时，自动执行一次 `setup-ai-skills.sh`。
- 提供 `xxfSetupAiSkills` task，方便命令行手动刷新。
- 如果项目根目录存在 `setup-ai-skills.sh`，优先执行根目录脚本。
- 如果项目根目录不存在 `setup-ai-skills.sh`，执行 `gradle/setup-ai-skills.sh` 备份脚本。
- 无论安装脚本成功、失败或超时，都不让 Gradle sync 失败。

## 文件说明

模板目录：

```text
usecase/gradle/template/gradle/
├── setup-ai-skills.sh
└── xxf_ensure-ai-skills.gradle
```

说明：

- `xxf_ensure-ai-skills.gradle` 是 Gradle script plugin，应从根项目 `build.gradle` 或 `build.gradle.kts` 引入。
- `setup-ai-skills.sh` 是 Gradle-local 备份脚本，根目录没有 `setup-ai-skills.sh` 时使用。
- 日志写入项目 `.gradle/xxf_ensure-ai-skills/setup-ai-skills.log`，不会进入 Git 提交。
- 同一时间只允许一个安装脚本运行，连续 sync 会通过 `.gradle/xxf_ensure-ai-skills/setup.lock` 避免并发执行。

## 接入方式

在目标 Android 项目根目录执行。`ANDROID_SKILLS_DIR` 改成 `android-skills` 仓库本地路径。团队项目可以只提交脚本和 Gradle hook；脚本每次都会强制重建 `agent/skills` 缓存，再同步到 `.agents/skills` 和 `.claude/skills`。既有 `agent/skills` 不会被当作来源。如果没有 `ANDROID_SKILLS_DIR`，脚本会用 `git` 拉取 `NBXXF/android-skills`，不依赖 npx，也不依赖某台机器上的固定 checkout 路径：

```bash
ANDROID_SKILLS_DIR=/path/to/android-skills
mkdir -p gradle
cp "$ANDROID_SKILLS_DIR/usecase/gradle/template/gradle/xxf_ensure-ai-skills.gradle" gradle/
cp "$ANDROID_SKILLS_DIR/usecase/gradle/template/gradle/setup-ai-skills.sh" gradle/
chmod +x gradle/setup-ai-skills.sh
```

Groovy DSL 根项目 `build.gradle` 增加：

```groovy
apply from: "$rootDir/gradle/xxf_ensure-ai-skills.gradle"
```

Kotlin DSL 根项目 `build.gradle.kts` 增加：

```kotlin
apply(from = "$rootDir/gradle/xxf_ensure-ai-skills.gradle")
```

建议放在根项目构建脚本靠前位置，确保 IDE sync 配置阶段能加载。

## 已有 Gradle 配置时怎么接入

如果根项目已经有多个 `apply from:` 或自定义插件，不要改动原有逻辑，只新增一行：

```groovy
apply from: "$rootDir/gradle/xxf_ensure-ai-skills.gradle"
```

如果项目不希望提交根目录 `setup-ai-skills.sh`，只提交 `gradle/setup-ai-skills.sh` 也可以；脚本会自动走 fallback。脚本会先强制重建 `agent/skills`，然后统一从 `agent/skills` 复制到 `.agents/skills` 和 `.claude/skills`。

## 执行策略

`xxf_ensure-ai-skills.gradle` 做两件事：

1. 注册 task：

```bash
./gradlew xxfSetupAiSkills
```

2. 在 IDE Gradle sync 的配置阶段自动执行一次。

自动执行的触发条件：

- `-Didea.sync.active=true`
- 或手动传入 `-Pxxf.aiSkills.force=true`

普通命令行 build/package 和 IDE 普通 build 默认不会自动执行安装脚本。

可以通过 Gradle property 关闭自动执行：

```properties
xxf.aiSkills.auto=false
```

可以调整超时时间，默认 120 秒：

```properties
xxf.aiSkills.timeoutSec=120
```

## 验证

手动验证 task：

```bash
./gradlew xxfSetupAiSkills
echo $?
tail -n 80 .gradle/xxf_ensure-ai-skills/setup-ai-skills.log
```

验证 IDE sync：

1. Android Studio / IDEA 点击 Sync Project with Gradle Files。
2. 查看日志：

```bash
tail -n 80 .gradle/xxf_ensure-ai-skills/setup-ai-skills.log
```

期望：

- Gradle sync 不会因为 `setup-ai-skills.sh` 失败而失败。
- 日志中能看到执行了根目录 `setup-ai-skills.sh` 或 `gradle/setup-ai-skills.sh`。

## 成本和风险

- Gradle task 本身不会被 IDE sync 自动执行；这里的自动执行依赖 Gradle 配置阶段代码，因此必须在根项目 `build.gradle` / `build.gradle.kts` 中 `apply` 脚本。
- IDE sync 会等待安装脚本结束或超时；网络慢时会增加 sync 时间。
- 安装脚本失败、超时、GitHub 不可达都只写日志，不影响 Gradle sync 结果。
- `setup-ai-skills.sh` 可能刷新 `AGENTS.md` 或 `.agents/.claude` 下的 skill 链接，提交前应确认这些生成变化是否符合预期。
