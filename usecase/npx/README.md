# npx skills 安装 android-skills

这个 usecase 记录如何通过 `npx skills` 从 `NBXXF/android-skills` 安装、更新、验证和卸载 AI skills。

`npx skills` 属于 skills.sh / Open Agent Skills 生态工具。它会根据当前项目和目标 agent，把 `SKILL.md` 同步到对应 agent 可识别的 skill 目录。实际落盘目录会随 CLI 版本和 agent 支持情况变化，最终以 `npx -y skills list --json` 输出为准。

## 快速安装

在目标项目根目录执行：

```bash
npx -y skills add NBXXF/android-skills --all
```

`--all` 是快捷参数，等价于：

```bash
--skill '*' --agent '*' -y
```

含义：

- `--skill '*'`：安装仓库里发现的所有 skill。
- `--agent '*'`：安装到 CLI 支持的所有 agent。
- `-y`：跳过确认提示，适合脚本和 CI 初始化。

当前验证过的 agent 过滤名：

```text
codex
claude-code
github-copilot
```

## 安装范围

默认在当前项目安装：

```bash
npx -y skills add NBXXF/android-skills --all
```

全局安装到用户级目录：

```bash
npx -y skills add NBXXF/android-skills --all -g
```

只安装到 Codex：

```bash
npx -y skills add NBXXF/android-skills --skill '*' --agent codex -y
```

只安装到 Claude Code：

```bash
npx -y skills add NBXXF/android-skills --skill '*' --agent claude-code -y
```

只安装到 GitHub Copilot：

```bash
npx -y skills add NBXXF/android-skills --skill '*' --agent github-copilot -y
```

安装到多个指定 agent：

```bash
npx -y skills add NBXXF/android-skills --skill '*' --agent codex claude-code -y
```

## 指定 skill

列出仓库里可安装的 skill，不执行安装：

```bash
npx -y skills add NBXXF/android-skills --list
```

只安装交付总控 skill：

```bash
npx -y skills add NBXXF/android-skills --skill aaaaa-xxf-delivery-loop --agent '*' -y
```

安装多个指定 skill：

```bash
npx -y skills add NBXXF/android-skills \
  --skill aaaaa-xxf-delivery-loop aaaaa-xxf-coding-style aaaaa-xxf-test-strategy \
  --agent '*' \
  -y
```

## 软链和拷贝

默认行为通常是软链或 CLI 管理的同步方式，便于后续更新。

如果希望直接拷贝文件，而不是依赖软链：

```bash
npx -y skills add NBXXF/android-skills --all --copy
```

使用 `--copy` 后，后续更新仍建议用 `skills update`，不要手工改生成目录里的 skill 内容。

## 深度扫描

如果仓库根目录也存在 `SKILL.md`，但仍希望扫描更深层目录里的所有 skill：

```bash
npx -y skills add NBXXF/android-skills --all --full-depth
```

`android-skills` 当前主要通过 `skills/<skill-name>/SKILL.md` 组织，一般不需要额外加 `--full-depth`。如果未来仓库结构变化，再打开这个参数。

## 验证

查看当前项目已安装的 skills：

```bash
npx -y skills list
```

输出 JSON，便于脚本检查：

```bash
npx -y skills list --json
```

只看 Codex：

```bash
npx -y skills list -a codex --json
```

只看 Claude Code：

```bash
npx -y skills list -a claude-code --json
```

只看全局安装：

```bash
npx -y skills list -g --json
```

最小文件检查：

```bash
test -f .agents/skills/aaaaa-xxf-delivery-loop/SKILL.md
```

Claude Code 兼容检查：

```bash
test -f .claude/skills/aaaaa-xxf-delivery-loop/SKILL.md
```

如果 CLI 安装成功但当前 AI 会话没有识别到新 skill，重启 Codex / Claude Code 进程后再检查。

## 更新

更新当前项目里的 skills：

```bash
npx -y skills update -p -y
```

更新全局 skills：

```bash
npx -y skills update -g -y
```

更新指定 skill：

```bash
npx -y skills update aaaaa-xxf-delivery-loop -p -y
```

## 卸载

交互式卸载：

```bash
npx -y skills remove
```

卸载当前项目所有 android-skills：

```bash
npx -y skills remove --all
```

只从 Codex 目标卸载：

```bash
npx -y skills remove --skill '*' --agent codex -y
```

只从 Claude Code 目标卸载：

```bash
npx -y skills remove --skill '*' --agent claude-code -y
```

卸载全局安装：

```bash
npx -y skills remove --all -g
```

## 常用参数速查

```text
add <package>             安装 skill 仓库
--all                     等价于 --skill '*' --agent '*' -y
-g, --global              安装到用户级，而不是当前项目
-a, --agent <agents>      指定 agent，例如 codex、claude-code、github-copilot、'*'
-s, --skill <skills>      指定 skill 名称，'*' 表示全部
-l, --list                只列出可安装 skill，不安装
-y, --yes                 跳过确认
--copy                    拷贝文件而不是软链/同步引用
--full-depth              即使根目录有 SKILL.md，也继续扫描深层目录
list --json               JSON 输出，适合脚本检查
update -p/-g -y           更新项目级/全局 skill
remove --all              卸载全部已安装 skill
```

## 和 setup-ai-skills.sh 的关系

`npx skills add NBXXF/android-skills --all --copy` 可以作为外部可选安装入口，适合已经安装 Node.js/npm 的机器。

项目内部的 `setup-ai-skills.sh` 不依赖 npx / npm / Node.js。后续维护不要把内部脚本改成 `npx skills add ...`，因为目标机器不一定有 npx。

内部脚本应继续从本地 `android-skills` checkout 的 `skills/` 目录直接拷贝：

```bash
ANDROID_SKILLS_DIR=/path/to/android-skills ./setup-ai-skills.sh
test -f .agents/skills/aaaaa-xxf-delivery-loop/SKILL.md
test -f .claude/skills/aaaaa-xxf-delivery-loop/SKILL.md
```

npx usecase 只记录另一种可选安装方式，不作为内部脚本实现依赖。
