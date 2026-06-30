# Android Skills

Shared Android engineering skills for coding agents.

This repository contains generic Android workflow and engineering-constraint skills. It intentionally does not describe any specific business app or Maven library API. Project-specific or library-specific skills should live in the corresponding project repository.

## Structure

```text
skills/
  xxf-aaa-delivery-loop/
  xxf-aaa-coding-style/
  xxf-aaa-coding-arch/
  xxf-aaa-multi-module-structure/
  xxf-aaa-test-strategy/
  ...
install.sh
```

## Install

Install the shared skills from a local checkout. Run project-scoped installs from the Android project root where the agent should discover the skills:

```bash
git clone https://github.com/NBXXF/android-skills.git /path/to/android-skills
cd /path/to/target-android-project

bash /path/to/android-skills/install.sh codex project
bash /path/to/android-skills/install.sh cursor project
```

Install user-scoped Codex or Claude skills from any working directory:

```bash
bash /path/to/android-skills/install.sh codex user
bash /path/to/android-skills/install.sh claude user
```

Install targets:

- Codex project install creates symlinks in `.agents/skills` and adds a small managed block to `AGENTS.md`.
- Codex user install creates symlinks in `$HOME/.agents/skills`.
- Claude install creates symlinks in `.claude/skills`.
- Cursor project install copies rules to `.cursor/rules`.

## Install With XXF Library Skills

This repository is the shared Android engineering rule set. XXF library-specific skills live in:

```text
https://github.com/NBXXF/xxf_android/tree/master/skills
```

For third-party Android projects that use XXF libraries, install both repositories. The install scripts use separate Codex markers and separate caches, so they can coexist in the same `AGENTS.md`.

```bash
git clone https://github.com/NBXXF/android-skills.git /path/to/android-skills
git clone https://github.com/NBXXF/xxf_android.git /path/to/xxf_android

cd /path/to/target-android-project
bash /path/to/android-skills/install.sh codex project
bash /path/to/xxf_android/skills/install.sh codex project
```

## Codex Usage

For normal Android coding work, read `xxf-aaa-delivery-loop` first. Then load the narrower skills it references, such as coding style, architecture, testing, review, risk, performance, or clarification.

Project repositories can still keep their own module skills. Use this repository for shared Android process rules, and use project-local skills for concrete module or library details.

## Notes

- Keep `SKILL.md` files concise and procedural.
- Do not put app-private details or concrete library API docs in this shared repository.
- Add only rules that should apply across Android projects.
