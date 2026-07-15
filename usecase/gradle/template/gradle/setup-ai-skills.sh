#!/usr/bin/env bash
#
# Fallback copy for Gradle sync when the repository root setup-ai-skills.sh is absent.
# It does not download skills by itself. Pass ANDROID_SKILLS_DIR to a local
# android-skills checkout, or keep setup-ai-skills.sh in the repository root.
#
# 硬约束:
# - 内部安装流程不得依赖 npx / npm / Node.js,因为目标机器不一定安装这些工具。
# - 本脚本本质是替代 npx 的无 Node.js 安装入口; 后期修改也不要改成 `npx skills add ...`。
# - npx 只能作为独立 usecase 文档中的可选安装方式,不能成为内部脚本依赖。
# - 本脚本只允许从本地 android-skills checkout 的 skills/ 目录直接拷贝文件。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
    :
else
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$REPO_ROOT"

resolve_android_skills_dir() {
    if [[ -n "${ANDROID_SKILLS_DIR:-}" ]]; then
        printf '%s\n' "$ANDROID_SKILLS_DIR"
        return
    fi

    if [[ -f "$REPO_ROOT/install.sh" && -d "$REPO_ROOT/skills" ]]; then
        printf '%s\n' "$REPO_ROOT"
        return
    fi

    echo "error: missing ANDROID_SKILLS_DIR." >&2
    echo "Pass a local android-skills checkout, for example:" >&2
    echo "  ANDROID_SKILLS_DIR=/path/to/android-skills ./gradlew xxfSetupAiSkills" >&2
    exit 1
}

ANDROID_SKILLS_DIR="$(resolve_android_skills_dir)"
INSTALL_SCRIPT="$ANDROID_SKILLS_DIR/install.sh"

[[ -f "$INSTALL_SCRIPT" ]] || {
    echo "error: install.sh not found: $INSTALL_SCRIPT" >&2
    exit 1
}
[[ -d "$ANDROID_SKILLS_DIR/skills" ]] || {
    echo "error: skills/ not found: $ANDROID_SKILLS_DIR/skills" >&2
    exit 1
}

echo "-> 安装 android-skills AI skills(Claude Code · project scope · copy mode)"
bash "$INSTALL_SCRIPT" claude project

echo ""
echo "-> 安装 android-skills AI skills(Codex CLI -> .agents/skills · project scope · copy mode)"
bash "$INSTALL_SCRIPT" codex project

echo ""
echo "-> 校验关键 skill 文件"
test -f .agents/skills/aaaaa-xxf-delivery-loop/SKILL.md
test -f .claude/skills/aaaaa-xxf-delivery-loop/SKILL.md

echo ""
echo "✅ AI skills 安装完成。"
echo "   - 重启 claude / codex 进程使其生效"
echo "   - \`/skills\` 里出现 aaaaa-xxf-* 条目即成功"
echo "   - 升级:更新 android-skills 仓库后重跑本脚本即可"
echo ""
