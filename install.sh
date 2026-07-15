#!/usr/bin/env bash
#
# Shared Android Skills install / upgrade script
#
# Usage:
#   bash install.sh <agent> [scope]
#
# agent:
#   claude      - Claude Code (~/.claude/skills or .claude/skills)
#   codex       - Codex CLI (.agents/skills copies plus an AGENTS.md reference block)
#   cursor      - Cursor (.cursor/rules/*.mdc)
#
# scope:
#   user        - global install for claude/codex
#   project     - project-local install for claude/codex/cursor

set -euo pipefail

AGENT="${1:-}"
SCOPE="${2:-user}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

err() { echo "error: $*" >&2; exit 1; }
info() { echo "-> $*"; }

[[ -n "$AGENT" ]] || err "missing agent. usage: $0 <claude|codex|cursor> [user|project]"

SKILLS_SRC="$SCRIPT_DIR/skills"
[[ -d "$SKILLS_SRC" ]] || err "skills/ not found beside install.sh. Run this script from a full android-skills checkout."
info "using local skills: $SKILLS_SRC"

build_skills_list() {
  local item
  for skill_dir in "$SKILLS_SRC"/aaaaa-xxf-*/; do
    [[ -d "$skill_dir" ]] || continue
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

  # 覆盖规则:
  # - 目标不存在:直接安装。
  # - 目标是旧软链:删除软链本身,不跟随到软链目标。
  # - 目标是旧目录或普通文件:删除后替换为新的真实目录。
  # 先拷贝到同级临时目录,拷贝成功后再替换目标,避免失败时破坏旧安装。
  rm -rf "$tmp"
  if ! cp -R "$src" "$tmp"; then
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$dest"
  mv "$tmp" "$dest"
}

install_claude() {
  local target
  case "$SCOPE" in
    user) target="$HOME/.claude/skills" ;;
    project) target="$PWD/.claude/skills" ;;
    *) err "scope must be 'user' or 'project'" ;;
  esac

  mkdir -p "$target"
  local count=0
  for skill_dir in "$SKILLS_SRC"/aaaaa-xxf-*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    copy_skill_dir "$skill_dir" "$target/$name"
    count=$((count + 1))
  done
  info "installed $count skills to $target"
}

install_codex() {
  local target
  case "$SCOPE" in
    user) target="$HOME/.agents/skills" ;;
    project) target="$PWD/.agents/skills" ;;
    *) err "scope must be 'user' or 'project' for codex" ;;
  esac

  local agents_md="$PWD/AGENTS.md"
  local marker_begin="<!-- BEGIN: xxf-shared-android-skills (managed by install.sh) -->"
  local marker_end="<!-- END: xxf-shared-android-skills -->"

  mkdir -p "$target"
  local count=0
  for skill_dir in "$SKILLS_SRC"/aaaaa-xxf-*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    copy_skill_dir "$skill_dir" "$target/$name"
    count=$((count + 1))
  done

  if [[ "$SCOPE" == "user" ]]; then
    info "installed $count skills to $target"
    return
  fi

  if [[ -f "$agents_md" ]] && grep -qF "$marker_begin" "$agents_md"; then
    info "refreshing existing xxf-shared-android-skills block in AGENTS.md"
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

  local skills_list
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
    echo "    .agents/skills/<skill-name>/SKILL.md"
    echo ""
    echo "For normal Android coding tasks, start with:"
    echo ""
    echo "    .agents/skills/aaaaa-xxf-delivery-loop/SKILL.md"
    echo ""
    echo "Use project-local module or business skills separately when the target repository provides them."
    echo ""
    echo "Default expectation: find the pattern, make the smallest correct systematic change, add or repair focused tests when needed, run the narrowest relevant verification, review non-trivial risk, and surface release risk when residual risk remains."
    echo ""
    echo "Available shared skills:"
    echo ""
    echo "$skills_list"
    echo "Update skills: update the android-skills checkout, then re-run install.sh."
    echo "$marker_end"
  } > "$agents_md.new"
  mv "$agents_md.new" "$agents_md"

  info "installed $count skills to $target"
  info "injected managed block into $agents_md"
}

install_cursor() {
  local target
  case "$SCOPE" in
    user) err "Cursor rules are project-scoped; use 'project'" ;;
    project) target="$PWD/.cursor/rules" ;;
    *) err "scope must be 'project' for Cursor" ;;
  esac

  mkdir -p "$target"
  local count=0
  for skill_dir in "$SKILLS_SRC"/aaaaa-xxf-*/; do
    [[ -d "$skill_dir" ]] || continue
    local name
    name="$(basename "$skill_dir")"
    cp "$skill_dir/SKILL.md" "$target/$name.mdc"
    count=$((count + 1))
  done
  info "installed $count rules to $target"
}

case "$AGENT" in
  claude) install_claude ;;
  codex) install_codex ;;
  cursor) install_cursor ;;
  *) err "unknown agent '$AGENT'. use: claude | codex | cursor" ;;
esac

info "done."
