#!/usr/bin/env bash
#
# setup-ai-skills.sh
#
# 每台新机器 clone 本仓后跑一次(idempotent,重跑会升级到最新 android-skills)。
# 装完需要重启 claude / codex 进程,`/skills` 能看到 aaaaa-xxf-* 开头的条目即生效。

set -euo pipefail

cd "$(dirname "$0")"

INSTALL_URL="https://raw.githubusercontent.com/NBXXF/android-skills/main/install.sh"
# 和 android-skills install.sh 同约定的 cache 路径,保持一致。
CACHE_DIR="${XXF_ANDROID_SKILLS_CACHE:-$HOME/.cache/xxf-shared-android-skills}"

echo "-> 安装 android-skills AI skills(Claude Code · project scope)"
bash <(curl -fsSL "$INSTALL_URL") claude project

echo ""
echo "-> 安装 android-skills AI skills(Codex CLI -> .agents/skills · project scope)"
bash <(curl -fsSL "$INSTALL_URL") codex project

# 如果项目已经有同名本地 skill 目录,android-skills install.sh 的 ln -sfn 会在目录内
# 生成 `<skill>/<skill>` 嵌套软链。这里清掉嵌套项,保留项目本地 skill 优先级。
for skill_dir in "$CACHE_DIR"/skills/aaaaa-xxf-*/; do
    [[ -d "$skill_dir" ]] || continue
    name=$(basename "$skill_dir")
    nested=".agents/skills/$name/$name"
    if [[ -L "$nested" ]]; then
        rm -f "$nested"
    fi
done

mirror_skills() {
    local target_dir="$1"
    local label="$2"
    local count=0

    echo ""
    echo "-> 镜像 aaaaa-xxf-* 软链到 ${target_dir}"
    mkdir -p "$target_dir"

    for skill_dir in "$CACHE_DIR"/skills/aaaaa-xxf-*/; do
        [[ -d "$skill_dir" ]] || continue
        name=$(basename "$skill_dir")
        ln -sfn "$skill_dir" "${target_dir}/$name"
        count=$((count + 1))
    done

    echo "   -> 建了 $count 条 ${label}/aaaaa-xxf-* 软链"
}

# 官方 install.sh 的 claude 模式写 .claude/skills/,codex 模式写 .agents/skills/ 和 AGENTS.md 管理块。
# 这里只额外确保 .claude/skills/ 存在,满足 Claude Code 识别。
mirror_skills ".claude/skills" ".claude/skills"

echo ""
echo "✅ AI skills 安装完成。"
echo "   - 重启 claude / codex 进程使其生效"
echo "   - \`/skills\` 里出现 aaaaa-xxf-* 条目即成功"
echo "   - 升级:重跑本脚本即可(底层 git pull)"
echo ""
