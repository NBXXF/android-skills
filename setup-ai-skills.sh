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
# - 本脚本只允许先刷新当前项目 agent/skills,再复制到 .agents/skills 和 .claude/skills。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

resolve_project_root() {
    local dir="$SCRIPT_DIR"
    local depth=0
    local git_root

    # 目标项目根目录解析规则:
    # - 优先用 git 根据脚本所在目录解析真实工作区根目录,不依赖当前 shell 的 PWD。
    # - git 不可用或脚本不在 Git 工作区时,再最多向上查找 3 级父目录里的 .git。
    # - 找到 .git 就安装到该 Git 根目录; 找不到才回退到脚本所在目录。
    # 后续维护不要改成使用 PWD,Gradle/Git hook 可能从任意目录触发本脚本。
    if command -v git >/dev/null 2>&1; then
        git_root="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
        if [[ -n "$git_root" ]]; then
            printf '%s\n' "$git_root"
            return
        fi
    fi

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

is_skills_root() {
    local dir="$1"
    [[ -f "$dir/aaaaa-xxf-delivery-loop/SKILL.md" ]]
}

resolve_skills_src_dir() {
    if [[ -n "${ANDROID_SKILLS_DIR:-}" ]]; then
        if [[ -d "$ANDROID_SKILLS_DIR/skills" ]] && is_skills_root "$ANDROID_SKILLS_DIR/skills"; then
            printf '%s\n' "$ANDROID_SKILLS_DIR/skills"
            return
        fi
        if is_skills_root "$ANDROID_SKILLS_DIR"; then
            printf '%s\n' "$ANDROID_SKILLS_DIR"
            return
        fi
        echo "error: ANDROID_SKILLS_DIR does not contain skills: $ANDROID_SKILLS_DIR" >&2
        exit 1
    fi

    if [[ -d "$PROJECT_ROOT/skills" ]] && is_skills_root "$PROJECT_ROOT/skills"; then
        printf '%s\n' "$PROJECT_ROOT/skills"
        return
    fi

    if [[ -d "$SCRIPT_DIR/skills" ]] && is_skills_root "$SCRIPT_DIR/skills"; then
        printf '%s\n' "$SCRIPT_DIR/skills"
        return
    fi

    echo "error: missing android skills source." >&2
    echo "Put copied skills in this project cache first:" >&2
    echo "  mkdir -p agent" >&2
    echo "  cp -R /path/to/android-skills/skills agent/skills" >&2
    echo "or pass a local checkout explicitly:" >&2
    echo "  ANDROID_SKILLS_DIR=/path/to/android-skills ./setup-ai-skills.sh" >&2
    exit 1
}

STAGED_SKILLS_DIR="$PROJECT_ROOT/agent/skills"
SKILLS_SRC=""

mkdir -p "$STAGED_SKILLS_DIR"

if [[ -d "$STAGED_SKILLS_DIR" ]] && is_skills_root "$STAGED_SKILLS_DIR"; then
    SKILLS_SRC="$STAGED_SKILLS_DIR"
else
    SKILLS_SRC="$(resolve_skills_src_dir)"
fi

[[ -d "$SKILLS_SRC" ]] || {
    echo "error: skills source not found: $SKILLS_SRC" >&2
    exit 1
}
echo "-> 使用本地 skills 源: $SKILLS_SRC"

build_skills_list() {
    local item
    for skill_dir in "$SKILLS_SRC"/aaaaa-xxf-*/; do
        [[ -d "$skill_dir" ]] || continue
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        item="$(basename "$skill_dir")"
        printf -- "- %s\n" "$item"
    done
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

refresh_project_skills_cache() {
    local source_dir="$1"

    if [[ "$source_dir" == "$STAGED_SKILLS_DIR" ]]; then
        return 0
    fi

    echo "-> 刷新当前项目 skills 缓存: agent/skills"
    sync_skill_dirs "$source_dir" "$STAGED_SKILLS_DIR" "agent/skills"
    SKILLS_SRC="$STAGED_SKILLS_DIR"
}

write_agents_md_block() {
    local codex_skills_dir="$1"
    local agents_md="AGENTS.md"
    local marker_begin="<!-- BEGIN: xxf-shared-android-skills (managed by install.sh) -->"
    local marker_end="<!-- END: xxf-shared-android-skills -->"
    local skills_list

    if [[ -f "$agents_md" ]] && grep -qF "$marker_begin" "$agents_md"; then
        python3 - "$agents_md" "$marker_begin" "$marker_end" <<'PY'
import pathlib
import re
import sys

path, begin, end = sys.argv[1:]
text = pathlib.Path(path).read_text()
pattern = re.compile(r'\n*' + re.escape(begin) + r'.*?' + re.escape(end) + r'\n?', re.DOTALL)
pathlib.Path(path).write_text(pattern.sub('', text))
PY
    fi

    skills_list="$(build_skills_list)"

    {
        if [[ -f "$agents_md" ]]; then
            local existing
            existing="$(cat "$agents_md")"
            if [[ -n "$existing" ]]; then
                printf '%s\n\n' "$existing"
            fi
        fi
        echo "$marker_begin"
        echo "## Shared Android Skills"
        echo ""
        echo "Codex discovers these project skills from:"
        echo ""
        echo "    ${codex_skills_dir}/<skill-name>/SKILL.md"
        echo ""
        echo "For normal Android coding tasks, start with:"
        echo ""
        echo "    ${codex_skills_dir}/aaaaa-xxf-delivery-loop/SKILL.md"
        echo ""
        echo "Use project-local module or business skills separately when the target repository provides them."
        echo ""
        echo "Default expectation: find the pattern, make the smallest correct systematic change, add or repair focused tests when needed, run the narrowest relevant verification, review non-trivial risk, and surface release risk when residual risk remains."
        echo ""
        echo "Available shared skills:"
        echo ""
        echo "$skills_list"
        echo "Update skills: update the project agent/skills cache or android-skills checkout, then re-run setup-ai-skills.sh."
        echo "$marker_end"
    } > "$agents_md.new"
    mv "$agents_md.new" "$agents_md"
}

install_codex_project_skills() {
    local codex_skills_dir="$1"

    sync_skill_dirs "$SKILLS_SRC" "$codex_skills_dir" "$codex_skills_dir"
    write_agents_md_block "$codex_skills_dir"
}

CODEX_SKILLS_DIR="$(resolve_codex_skills_dir)"
refresh_project_skills_cache "$SKILLS_SRC"

echo "-> 安装 android-skills AI skills(Codex CLI -> ${CODEX_SKILLS_DIR} · project scope · copy mode)"
install_codex_project_skills "$CODEX_SKILLS_DIR"

echo ""
echo "-> 安装 android-skills AI skills(Claude Code -> .claude/skills · project scope · copy mode)"
sync_skill_dirs "$SKILLS_SRC" ".claude/skills" ".claude/skills"

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
