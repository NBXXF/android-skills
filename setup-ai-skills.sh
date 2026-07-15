#!/usr/bin/env bash
#
# setup-ai-skills.sh
#
# 每台新机器 clone 本仓后跑一次。安装后需要重启 claude / codex 进程,
# `/skills` 能看到 aaaaa-xxf-* 开头的条目即生效。
#
# 硬约束:
# - 内部安装流程不得依赖 npx / npm / Node.js,因为目标机器不一定安装这些工具。
# - 本脚本本质是替代 npx 的无 Node.js 安装入口; 后期修改也不要改成 `npx skills add ...`。
# - npx 只能作为独立 usecase 文档中的可选安装方式,不能成为内部脚本依赖。
# - 本脚本只允许从本地 android-skills checkout 的 skills/ 目录直接拷贝文件。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_project_root() {
    local dir="$SCRIPT_DIR"
    local depth=0

    # 目标项目根目录解析规则:
    # - 先检查脚本所在目录本身。
    # - 再最多向上查找 3 级父目录里的 .git。
    # - 找到 .git 就安装到该 Git 根目录; 找不到才回退到脚本所在目录。
    # 后续维护不要收窄这个范围,业务项目可能把本脚本放在子目录中。
    while [[ $depth -le 3 ]]; do
        if [[ -e "$dir/.git" ]]; then
            printf '%s\n' "$dir"
            return
        fi
        dir="$(cd "$dir/.." && pwd)"
        depth=$((depth + 1))
    done

    printf '%s\n' "$SCRIPT_DIR"
}

PROJECT_ROOT="$(resolve_project_root)"
cd "$PROJECT_ROOT"

resolve_android_skills_dir() {
    if [[ -n "${ANDROID_SKILLS_DIR:-}" ]]; then
        printf '%s\n' "$ANDROID_SKILLS_DIR"
        return
    fi

    if [[ -f "$PROJECT_ROOT/install.sh" && -d "$PROJECT_ROOT/skills" ]]; then
        printf '%s\n' "$PROJECT_ROOT"
        return
    fi

    # 个人开发机默认 checkout 位置。保持在 npx/cache 之前作为本地无 Node.js 兜底。
    # 如果团队机器路径不同,用 ANDROID_SKILLS_DIR 显式覆盖。
    local default_dir="$HOME/Documents/developer/agent/android-skills"
    if [[ -f "$default_dir/install.sh" && -d "$default_dir/skills" ]]; then
        printf '%s\n' "$default_dir"
        return
    fi

    echo "error: missing ANDROID_SKILLS_DIR." >&2
    echo "Run from an android-skills checkout, place it at:" >&2
    echo "  $HOME/Documents/developer/agent/android-skills" >&2
    echo "or pass:" >&2
    echo "  ANDROID_SKILLS_DIR=/path/to/android-skills ./setup-ai-skills.sh" >&2
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

copy_skill_dir() {
    local src="$1"
    local dest="$2"
    local parent
    local tmp="${dest}.tmp.$$"

    parent="$(dirname "$dest")"
    mkdir -p "$parent"

    rm -rf "$tmp"
    mkdir -p "$tmp"
    if ! cp -R "$src/." "$tmp/"; then
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$dest"
    mv "$tmp" "$dest"
}

resolve_codex_skills_dir() {
    if [[ -d ".agents" ]]; then
        printf '%s\n' ".agents/skills"
        return
    fi

    if [[ -d ".codex" ]]; then
        printf '%s\n' ".codex/skills"
        return
    fi

    printf '%s\n' ".agents/skills"
}

sync_skill_dirs() {
    local source_dir="$1"
    local target_dir="$2"
    local label="$3"
    local count=0

    [[ -d "$source_dir" ]] || return 0

    echo "-> 同步项目 ${source_dir} 到 ${label}"
    mkdir -p "$target_dir"

    for skill_dir in "$source_dir"/*; do
        [[ -d "$skill_dir" ]] || continue
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        local name
        name="$(basename "$skill_dir")"
        copy_skill_dir "$skill_dir" "$target_dir/$name"
        count=$((count + 1))
    done

    echo "   -> 同步了 $count 个 skill 到 ${target_dir}"
}

update_agents_md_codex_skills_dir() {
    local codex_skills_dir="$1"
    local agents_md="AGENTS.md"

    [[ "$codex_skills_dir" != ".agents/skills" ]] || return 0
    [[ -f "$agents_md" ]] || return 0

    perl -0pi -e "s#\\.agents/skills#${codex_skills_dir}#g" "$agents_md"
}

install_codex_project_skills() {
    local codex_skills_dir="$1"
    local had_agents_dir=0

    if [[ -d ".agents" ]]; then
        had_agents_dir=1
    fi

    bash "$INSTALL_SCRIPT" codex project

    if [[ "$codex_skills_dir" != ".agents/skills" ]]; then
        sync_skill_dirs ".agents/skills" "$codex_skills_dir" "$codex_skills_dir"
        if [[ "$had_agents_dir" -eq 0 ]]; then
            rm -rf ".agents"
        fi
        update_agents_md_codex_skills_dir "$codex_skills_dir"
    fi
}

CODEX_SKILLS_DIR="$(resolve_codex_skills_dir)"

echo "-> 安装 android-skills AI skills(Codex CLI -> ${CODEX_SKILLS_DIR} · project scope · copy mode)"
install_codex_project_skills "$CODEX_SKILLS_DIR"

echo ""
echo "-> 安装 android-skills AI skills(Claude Code -> .claude/skills · project scope · copy mode)"
bash "$INSTALL_SCRIPT" claude project

sync_skill_dirs "$CODEX_SKILLS_DIR" ".claude/skills" ".claude/skills"

echo ""
echo "-> 校验关键 skill 文件"
test -f "$CODEX_SKILLS_DIR/aaaaa-xxf-delivery-loop/SKILL.md"
test -f .claude/skills/aaaaa-xxf-delivery-loop/SKILL.md

echo ""
echo "✅ AI skills 安装完成。"
echo "   - 重启 claude / codex 进程使其生效"
echo "   - \`/skills\` 里出现 aaaaa-xxf-* 条目即成功"
echo "   - 升级:更新 android-skills 仓库后重跑本脚本即可"
echo ""
