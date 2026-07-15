# Android Skills

Shared Android engineering skills for coding agents.

This repository contains generic Android workflow and engineering-constraint skills. It intentionally does not describe any specific business app or Maven library API. Project-specific or library-specific skills should live in the corresponding project repository.

## Structure

```text
skills/
  aaaaa-xxf-delivery-loop/
  aaaaa-xxf-coding-style/
  aaaaa-xxf-coding-arch/
  aaaaa-xxf-multi-module-structure/
  aaaaa-xxf-maven-library-release-guard/
  aaaaa-xxf-test-strategy/
  ...
install.sh
```

## Install

There are three supported installation paths. Prefer the local shell scripts for team/project automation because they do not depend on Node.js, npm, or npx.

### 1. Local `install.sh`

Use this when you already have a local `android-skills` checkout and want to install into a project or user-level agent directory. The script copies files directly from `skills/`; it does not download to a user cache and does not create symlinks.

Run project-scoped installs from the Android project root where the agent should discover the skills:

```bash
git clone https://github.com/NBXXF/android-skills.git /path/to/android-skills
cd /path/to/target-android-project

bash /path/to/android-skills/install.sh codex project
bash /path/to/android-skills/install.sh claude project
bash /path/to/android-skills/install.sh cursor project
```

Install user-scoped Codex or Claude skills from any working directory:

```bash
bash /path/to/android-skills/install.sh codex user
bash /path/to/android-skills/install.sh claude user
```

Install targets:

- Codex project install copies skill directories into `.agents/skills` and adds a small managed block to `AGENTS.md`.
- Codex user install copies skill directories into `$HOME/.agents/skills`.
- Claude install copies skill directories into `.claude/skills`.
- Cursor project install copies rules to `.cursor/rules`.

### 2. Project `setup-ai-skills.sh`

Use this as the project bootstrap entrypoint. It installs both Claude Code and Codex project skills, then checks that the key `aaaaa-xxf-delivery-loop` skill exists.

If `setup-ai-skills.sh` is inside the `android-skills` checkout, run it directly:

```bash
cd /path/to/android-skills
./setup-ai-skills.sh
```

If `setup-ai-skills.sh` is copied into a target Android project, pass the local checkout path:

```bash
cd /path/to/target-android-project
ANDROID_SKILLS_DIR=/path/to/android-skills ./setup-ai-skills.sh
```

This script is intentionally a no-Node.js replacement for `npx skills add`. Do not change internal `setup-ai-skills.sh` implementations to call `npx`, `npm`, or Node.js.

### 3. Optional `npx skills`

Use this only on machines that already have Node.js/npm. It is convenient for manual installs, but it is not an internal dependency of this repository's setup scripts.

```bash
cd /path/to/target-android-project
npx -y skills add NBXXF/android-skills --all --copy
```

More examples are documented in `usecase/npx/README.md`.

## Install With Library Skills

This repository is the shared Android engineering rule set. Library-specific skills should live in the corresponding library repository:

```text
https://github.com/<owner>/<library-repo>/tree/<branch>/skills
```

For Android projects that use additional library skills, install both repositories. Install scripts should use separate Codex markers, so they can coexist in the same `AGENTS.md`.

```bash
git clone https://github.com/NBXXF/android-skills.git /path/to/android-skills
git clone https://github.com/<owner>/<library-repo>.git /path/to/library-repo

cd /path/to/target-android-project
bash /path/to/android-skills/install.sh codex project
bash /path/to/library-repo/skills/install.sh codex project
```

## Codex Usage

For normal Android coding work, read `aaaaa-xxf-delivery-loop` first. Then load the narrower skills it references, such as coding style, architecture, testing, review, risk, performance, or clarification.

Project repositories can still keep their own module skills. Use this repository for shared Android process rules, and use project-local skills for concrete module or library details.

## Notes

- Keep `SKILL.md` files concise and procedural.
- Do not put app-private details or concrete library API docs in this shared repository.
- Add only rules that should apply across Android projects.
