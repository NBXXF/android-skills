---
name: aaaaa-xxf-android-package-builder
description: Android 工程打包助手。用于用户说“打包”“打渠道包”“打 apk”“打 aab”“打 release 包”“打 debug 包”“构建安装包”“生成 AAB”“assemble/bundle 某个渠道”等请求；在 Android 项目里自动识别 Gradle buildType、渠道 flavor/variant 和 apk/aab 产物类型，通过交互编号选择或命令行参数执行打包。若项目存在渠道包，必须先列出渠道并让用户显式选择，不能把裸 `release` / `debug` 当成默认渠道包执行。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Android 打包助手

## 目的

使用这个 skill 在 Android 工程里选择并执行 APK/AAB 打包。优先使用内置脚本从 Gradle 任务里识别真实可用的 build type、flavor variant 和产物类型，避免硬编码渠道或构建类型。只要项目存在渠道包，就必须按步骤逐项询问，不允许一次性要求用户回填三个信息，也不允许自动落到全部渠道的聚合打包或无渠道默认包。

## 必用脚本

脚本路径：

```bash
python3 ./scripts/android_pack.py
```

以上命令都以 skill 自身目录为当前工作目录执行，不要把 `.agents` 或 `.claude` 写死进路径。

常用方式：

```bash
# 交互按顺序选择 buildType、渠道和 apk/aab
python3 ./scripts/android_pack.py

# 查看当前项目可用选项
python3 ./scripts/android_pack.py --list

# 参数化打包
python3 ./scripts/android_pack.py --build-type release --flavor demoChannel --artifact apk
python3 ./scripts/android_pack.py --build-type release --channel demoChannel --artifact aab

# 直接指定 Gradle variant
python3 ./scripts/android_pack.py --variant demoChannelRelease --artifact apk

# 只打印将执行的 Gradle task，不真正打包
python3 ./scripts/android_pack.py --build-type debug --artifact apk --dry-run
```

## 执行流程

1. 确认当前目录在 Android 仓库内，并且存在 Gradle wrapper。
2. 运行脚本；如果用户没有指定 buildType、flavor/channel 或 apk/aab，必须按 `buildType -> 渠道 -> 产物类型` 的顺序逐步交互选择，每次只问一步，不要一次性反问三个信息。
3. 如果项目没有 flavor，脚本会跳过渠道选择，只选择 buildType 和 apk/aab。
4. 如果项目有 flavor，脚本必须先列出所有可用 buildType，让用户先选 buildType，不能先问渠道名。
5. 选完 buildType 后，再列出该 buildType 下所有可用渠道，让用户按编号选择。
6. 不要把裸 `release`、`debug` 或其他无渠道 variant 当成渠道包默认执行。
7. 最后再列出 `apk` / `aab`，让用户选择产物类型。
8. 脚本最终执行对应 Gradle task，例如 `:app:assembleDemoChannelRelease` 或 `:app:bundleDemoChannelRelease`。
9. 打包完成后，把脚本输出的 task、产物路径和失败原因转述给用户。

## 交互模板

必须按下面的结构逐步问，不要合并成一段自由文本：

1. `请选择打包类型,请回复数字`
   `1. debug`
   `2. release`
2. `请选择打包渠道,请回复数字`
   `1. xxx`
   `2. xxx`
3. `请选择打包格式,请回复数字`
   `1. apk`
   `2. aab`

## 参数规则

- `--build-type`：选择 `debug`、`release` 或项目自定义 build type；大小写不敏感。
- `--flavor` / `--channel`：选择渠道 flavor；大小写不敏感。多 flavor dimension 项目会列出组合后的 Gradle flavor 名。
- `--artifact`：只能是 `apk` 或 `aab`。
- `--variant`：直接指定完整 variant 名，如 `freeRelease`；仅用于非交互自动化场景，或者你明确传了完整渠道 variant 时使用。项目存在渠道包时，不能用裸 `release` / `debug` 代替渠道选择，也不能跳过顺序选择流程。
- `--module`：指定 Android app module，默认 `:app`。
- `--gradle-arg`：重复追加额外 Gradle 参数；参数本身以 `-` 开头时使用 `--gradle-arg=--offline`。
- `--`：也可以把额外 Gradle 参数放在 `--` 后面，如 `--dry-run -- --offline -Pfoo=bar`。
- `--list`：只展示可用选项，不执行打包。
- `--dry-run`：展示将执行的 Gradle task，不执行打包。

## 安全规则

- 不要手工拼接不存在的渠道 task；先让脚本识别并校验。
- 不要在缺少签名、凭证或 Gradle 配置失败时伪造成功结果。
- 不要回滚用户已有未提交改动。
- 打 release 或 aab 失败时优先报告 Gradle 原始失败 task 和关键错误。
- 如果用户明确要求某个渠道但脚本无法唯一匹配，列出可用渠道并让用户重新选择。
