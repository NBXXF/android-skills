# githooks 拉取 skill 配置教程

这个 usecase 用于在项目 Git hooks 中自动执行 `setup-ai-skills.sh`，保证 IDEA 提交、命令行提交、拉取、切分支、rebase/rewrite 后都会尽量刷新 AI skills。

## 目标

- 每次正常 Git 提交时都执行一次 `setup-ai-skills.sh`。
- 拉取、切分支、rebase/rewrite 后也执行一次，降低 hooks 或 skills 失效概率。
- 如果项目根目录存在 `setup-ai-skills.sh`，优先执行根目录脚本。
- 如果项目根目录不存在 `setup-ai-skills.sh`，执行 `.githooks/setup-ai-skills.sh` 备份脚本。
- 无论安装脚本成功还是失败，都不影响真实 Git 操作。

## 文件说明

模板目录：

```text
usecase/githooks/template/.githooks/
├── pre-commit
├── post-checkout
├── post-merge
├── post-rewrite
├── setup-ai-skills.sh
└── xxf_ensure-ai-skills
```

说明：

- `pre-commit`、`post-checkout`、`post-merge`、`post-rewrite` 是 Git 固定识别的 hook 文件名，不能加 `xxf_` 前缀。
- `xxf_ensure-ai-skills` 是自定义辅助脚本，已加 `xxf_` 前缀，避免和其他自定义脚本冲突。
- `setup-ai-skills.sh` 是 hook-local 备份脚本，按要求不加 `xxf_` 前缀。
- 日志写入项目本地 Git dir 下的 `ai-skills-hook.log`，普通仓库通常是 `.git/ai-skills-hook.log`，不会进入 Git 提交。
- 同一时间只允许一个安装脚本运行，连续触发 hook 时会通过 Git dir 下的 `xxf-ai-skills-hook.lock` 跳过并发执行。

## 接入方式

在目标 Android 项目根目录执行。`ANDROID_SKILLS_DIR` 改成 `android-skills` 仓库本地路径：

```bash
ANDROID_SKILLS_DIR=/path/to/android-skills
cp -R "$ANDROID_SKILLS_DIR/usecase/githooks/template/.githooks" .
chmod +x .githooks/pre-commit \
  .githooks/post-checkout \
  .githooks/post-merge \
  .githooks/post-rewrite \
  .githooks/setup-ai-skills.sh \
  .githooks/xxf_ensure-ai-skills
git config core.hooksPath .githooks
```

如果希望把 hooks 配置提交给团队，提交 `.githooks/` 目录即可。

注意：`core.hooksPath` 是本地 Git 配置，不会自动随仓库提交。新 clone 的机器仍需要执行：

```bash
git config core.hooksPath .githooks
```

## 项目已有 hooks 时怎么接入

如果项目已经有 `.githooks/pre-commit`、`.githooks/post-checkout`、`.githooks/post-merge`、`.githooks/post-rewrite`，不要直接覆盖这些文件。

只需要复制两个辅助脚本：

```bash
ANDROID_SKILLS_DIR=/path/to/android-skills
mkdir -p .githooks
cp "$ANDROID_SKILLS_DIR/usecase/githooks/template/.githooks/xxf_ensure-ai-skills" .githooks/
cp "$ANDROID_SKILLS_DIR/usecase/githooks/template/.githooks/setup-ai-skills.sh" .githooks/
chmod +x .githooks/xxf_ensure-ai-skills .githooks/setup-ai-skills.sh
git config core.hooksPath .githooks
```

然后在已有 shell hook 文件里加入下面这段。建议放在 `#!/usr/bin/env bash`、`#!/bin/sh` 或 `#!/usr/bin/env zsh` 后面，或放在 hook 原有逻辑的开头：

```bash
repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
"$repo_root/.githooks/xxf_ensure-ai-skills" "$(basename "$0")" || true
```

这段不会改变原 hook 的最终结果，因为它自己失败时会被 `|| true` 吞掉，`xxf_ensure-ai-skills` 内部也永远 `exit 0`。

如果已有 hook 不是 bash 但仍是 shell 脚本，也可以用更保守的写法：

```bash
git rev-parse --show-toplevel >/dev/null 2>&1 && \
  "$(git rev-parse --show-toplevel)/.githooks/xxf_ensure-ai-skills" "$(basename "$0")" || true
```

如果已有 hook 是 Python、Node、Ruby 等非 shell 脚本，不要直接插入上面的 shell 片段。应在原语言里调用：

```python
import os
import subprocess

repo_root = subprocess.run(
    ["git", "rev-parse", "--show-toplevel"],
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    text=True,
    check=False,
).stdout.strip()
if repo_root:
    subprocess.run(
        [os.path.join(repo_root, ".githooks", "xxf_ensure-ai-skills"), os.path.basename(__file__)],
        check=False,
    )
```

## 最快接入已有 hooks

在目标 Android 项目根目录执行下面命令。它会：

- 创建 `.githooks`。
- 复制 `xxf_ensure-ai-skills` 和备份 `setup-ai-skills.sh`。
- 如果某个 hook 文件不存在，就从模板复制。
- 如果某个 hook 文件已存在、还没有接入 `xxf_ensure-ai-skills`，且是 shell 脚本，就在文件开头插入调用片段。
- 如果某个 hook 文件已存在但不是 shell 脚本，会跳过并提示手动接入，避免破坏原脚本。
- 不会覆盖已有 hook 文件内容。

```bash
ANDROID_SKILLS_DIR=/path/to/android-skills
mkdir -p .githooks
cp "$ANDROID_SKILLS_DIR/usecase/githooks/template/.githooks/xxf_ensure-ai-skills" .githooks/
cp "$ANDROID_SKILLS_DIR/usecase/githooks/template/.githooks/setup-ai-skills.sh" .githooks/
chmod +x .githooks/xxf_ensure-ai-skills .githooks/setup-ai-skills.sh

for hook in pre-commit post-checkout post-merge post-rewrite; do
  target=".githooks/$hook"
  template="$ANDROID_SKILLS_DIR/usecase/githooks/template/.githooks/$hook"

  if [[ ! -f "$target" ]]; then
    cp "$template" "$target"
    chmod +x "$target"
    continue
  fi

  if grep -q 'xxf_ensure-ai-skills' "$target"; then
    chmod +x "$target"
    continue
  fi

  first_line="$(sed -n '1p' "$target")"
  case "$first_line" in
    ''|\
    '#!'*/sh|'#!'*/sh\ *|\
    '#!'*/bash|'#!'*/bash\ *|\
    '#!'*/zsh|'#!'*/zsh\ *|\
    '#!'*'env sh'|'#!'*'env sh '*|\
    '#!'*'env bash'|'#!'*'env bash '*|\
    '#!'*'env zsh'|'#!'*'env zsh '*)
      ;;
    *)
      echo "skip $target: non-shell hook, add xxf_ensure-ai-skills manually"
      chmod +x "$target"
      continue
      ;;
  esac

  tmp="$(mktemp)"
  awk '
    NR == 1 && /^#!/ {
      print
      print ""
      print "repo_root=\"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\""
      print "\"$repo_root/.githooks/xxf_ensure-ai-skills\" \"$(basename \"$0\")\" || true"
      next
    }
    NR == 1 {
      print "repo_root=\"$(git rev-parse --show-toplevel 2>/dev/null || pwd)\""
      print "\"$repo_root/.githooks/xxf_ensure-ai-skills\" \"$(basename \"$0\")\" || true"
      print ""
    }
    { print }
  ' "$target" > "$tmp"
  mv "$tmp" "$target"
  chmod +x "$target"
done

git config core.hooksPath .githooks
```

执行后检查：

```bash
grep -R 'xxf_ensure-ai-skills' .githooks/pre-commit .githooks/post-checkout .githooks/post-merge .githooks/post-rewrite
bash -n .githooks/pre-commit .githooks/post-checkout .githooks/post-merge .githooks/post-rewrite .githooks/xxf_ensure-ai-skills .githooks/setup-ai-skills.sh
```

## 执行策略

每次 hook 触发时：

1. 定位 Git 仓库根目录。
2. 如果根目录存在 `setup-ai-skills.sh`，执行它。
3. 否则如果 `.githooks/setup-ai-skills.sh` 存在，执行备份脚本。
4. 两者都不存在时跳过。
5. 安装脚本输出和失败原因写入 Git dir 下的 `ai-skills-hook.log`。
6. 设置 `GIT_TERMINAL_PROMPT=0` 执行安装脚本，避免 Git 凭证交互卡住 hook。
7. hook 永远 `exit 0`，不会阻断 commit、merge、checkout 或 rewrite。

## IDEA 注意事项

IDEA 提交通常会触发 `pre-commit`，但需要满足：

- 本地已配置 `git config core.hooksPath .githooks`。
- IDEA 未关闭 Git hooks。
- 提交没有使用 `--no-verify`。

## 成本和风险

- 当前策略是强制每次触发都执行安装脚本，不再根据 skill 是否存在提前跳过。
- 如果网络慢或 GitHub 不可达，提交会等待安装脚本失败或超时后继续。
- 如果上一次安装仍在执行，新的 hook 触发会直接跳过，不会并发跑多个安装进程。
- 执行失败不会阻断真实提交，但需要从 Git dir 下的 `ai-skills-hook.log` 排查。
- `setup-ai-skills.sh` 可能刷新 `AGENTS.md` 或 `.agents/.claude` 下的 skill 链接，提交前应确认这些生成变化是否符合预期。

## 验证

接入后可手动验证：

```bash
.githooks/pre-commit
echo $?
git_dir="$(git rev-parse --git-dir)"
tail -n 80 "$git_dir/ai-skills-hook.log"
```

期望：

- 返回值为 `0`。
- 日志中能看到执行了根目录 `setup-ai-skills.sh` 或 `.githooks/setup-ai-skills.sh`。
