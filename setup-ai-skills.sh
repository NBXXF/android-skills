#!/usr/bin/env bash
#
# setup-ai-skills.sh
#
# 本脚本是项目无关的 android-skills bootstrap,可以复制到任意目标工程执行。
# 安装后需要重启 claude / codex 进程,`/skills` 能看到 aaaaa-xxf-* 开头的条目即生效。
#
# 硬约束:
# - 本脚本必须保持项目无关:拷贝到任意 Git 工程后都能自行拉取并安装 android-skills。
# - 所有缓存和中转目录只能位于当前目标工程的 agent/ 下:
#   * 远端拉取临时目录: 当前工程/agent/.android-skills-fetch.$$
#   * 持久缓存目录: 当前工程/agent/skills
#   * 最终安装目录: 当前工程/.agents/skills 和 当前工程/.claude/skills
# - 严禁使用用户机器固定路径或个人目录作为缓存/中转/兜底,包括但不限于:
#   * $HOME/Documents、$HOME/Downloads、/Users/<name>/Documents、/Users/<name>/Downloads
#   * 系统临时目录 /tmp、$TMPDIR、mktemp 默认目录
# - 内部安装流程不得依赖 npx / npm / Node.js,因为目标机器不一定安装这些工具。
# - 本脚本本质是替代 npx 的无 Node.js 安装入口; 后期修改也不要改成 `npx skills add ...`。
# - npx 只能作为独立 usecase 文档中的可选安装方式,不能成为内部脚本依赖。
# - 每次运行都必须重新解析来源并强制刷新,不能因为 agent/skills 已存在就跳过。
# - agent/skills 只是本次刷新后的持久缓存,严禁把旧 agent/skills 当成本次安装来源。
# - 没有本地显式来源时,只能用 git 拉取 ANDROID_SKILLS_REPO 到当前工程 agent/.android-skills-fetch.$$。
# - 拉取或读取本地来源后必须先整目录重建当前工程 agent/skills,再复制到 .agents/skills 和 .claude/skills。
# - 当前工程根目录必须从脚本所在位置解析,不要依赖执行命令时的 PWD。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_SKILLS_REPO="${ANDROID_SKILLS_REPO:-https://github.com/NBXXF/android-skills.git}"
ANDROID_SKILLS_REF="${ANDROID_SKILLS_REF:-}"

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
PROJECT_AGENT_DIR="$PROJECT_ROOT/agent"
STAGED_SKILLS_DIR="$PROJECT_AGENT_DIR/skills"

is_skills_root() {
    local dir="$1"
    [[ -f "$dir/aaaaa-xxf-delivery-loop/SKILL.md" ]]
}

fetch_remote_skills_src_dir() {
    local fetch_work_dir

    command -v git >/dev/null 2>&1 || {
        echo "error: git is required to fetch android-skills for this forced refresh." >&2
        exit 1
    }

    # 铁律:远端拉取也只能在当前目标工程 agent/ 内完成。
    # 不要改成 mktemp、/tmp、$TMPDIR、Documents、Downloads 或任何个人固定路径。
    # 这个目录只是一次性工作区,refresh_project_skills_cache 会在写入 agent/skills 后删除它。
    mkdir -p "$PROJECT_AGENT_DIR"
    fetch_work_dir="$PROJECT_AGENT_DIR/.android-skills-fetch.$$"
    rm -rf "$fetch_work_dir"
    echo "-> 拉取 android-skills: $ANDROID_SKILLS_REPO" >&2

    if [[ -n "$ANDROID_SKILLS_REF" ]]; then
        if ! git clone --depth 1 --branch "$ANDROID_SKILLS_REF" "$ANDROID_SKILLS_REPO" "$fetch_work_dir" >&2; then
            echo "error: failed to fetch android-skills from $ANDROID_SKILLS_REPO ref $ANDROID_SKILLS_REF" >&2
            exit 1
        fi
    else
        if ! git clone --depth 1 "$ANDROID_SKILLS_REPO" "$fetch_work_dir" >&2; then
            echo "error: failed to fetch android-skills from $ANDROID_SKILLS_REPO" >&2
            exit 1
        fi
    fi

    if ! is_skills_root "$fetch_work_dir/skills"; then
        echo "error: fetched repository does not contain expected skills: $ANDROID_SKILLS_REPO" >&2
        exit 1
    fi

    printf '%s\n' "$fetch_work_dir/skills"
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

    fetch_remote_skills_src_dir
}

SKILLS_SRC="$(resolve_skills_src_dir)"

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
    local old_skill_dir

    [[ -d "$source_dir" ]] || return 0

    echo "-> 强制同步项目 ${source_dir} 到 ${label}"
    mkdir -p "$target_dir"

    # 铁律:目标目录里的共享 android-skills 每次都要重建。
    # 只删除 aaaaa-xxf-* 以避免误伤目标工程自己的非共享 skill。
    for old_skill_dir in "$target_dir"/aaaaa-xxf-*; do
        [[ -e "$old_skill_dir" ]] || continue
        rm -rf "$old_skill_dir"
    done

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
    local fetch_work_dir
    local parent_dir
    local tmp_dir
    local count=0

    if [[ "$source_dir" == "$STAGED_SKILLS_DIR" ]]; then
        echo "error: agent/skills is a generated cache and cannot be used as the refresh source." >&2
        exit 1
    fi

    echo "-> 强制重建当前项目 skills 缓存: agent/skills"
    parent_dir="$(dirname "$STAGED_SKILLS_DIR")"
    tmp_dir="${STAGED_SKILLS_DIR}.tmp.$$"
    mkdir -p "$parent_dir"
    rm -rf "$tmp_dir"
    mkdir -p "$tmp_dir"

    # 铁律:agent/skills 每次整目录重建,不能增量覆盖,否则被删除的旧 skill 会残留。
    for skill_dir in "$source_dir"/*; do
        [[ -d "$skill_dir" ]] || continue
        [[ -f "$skill_dir/SKILL.md" ]] || continue
        local name
        name="$(basename "$skill_dir")"
        copy_skill_dir "$skill_dir" "$tmp_dir/$name"
        count=$((count + 1))
    done

    rm -rf "$STAGED_SKILLS_DIR"
    mv "$tmp_dir" "$STAGED_SKILLS_DIR"
    SKILLS_SRC="$STAGED_SKILLS_DIR"
    echo "   -> 重建了 $count 个 skill 到 ${STAGED_SKILLS_DIR}"

    # 铁律:远端 clone 目录只允许短暂存在于当前工程 agent/ 下。
    # agent/skills 才是唯一持久缓存,不要保留 .android-skills-fetch.*。
    if [[ "$source_dir" == "$PROJECT_AGENT_DIR/.android-skills-fetch."*/skills ]]; then
        fetch_work_dir="${source_dir%/skills}"
        rm -rf "$fetch_work_dir"
    fi
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
