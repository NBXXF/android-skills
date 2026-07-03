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
  aaaaa-xxf-test-strategy/
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

## Install With Library Skills

This repository is the shared Android engineering rule set. Library-specific skills should live in the corresponding library repository:

```text
https://github.com/<owner>/<library-repo>/tree/<branch>/skills
```

For Android projects that use additional library skills, install both repositories. The install scripts use separate Codex markers and separate caches, so they can coexist in the same `AGENTS.md`.

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
