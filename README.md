# Android Skills

Shared Android engineering skills for coding agents.

This repository contains generic Android workflow and engineering-constraint skills. It intentionally does not describe any specific business app or Maven library API. Project-specific or library-specific skills should live in the corresponding project repository.

## Structure

```text
skills/
  xxf-aaa-delivery-loop/
  xxf-aaa-coding-style/
  xxf-aaa-coding-arch/
  xxf-aaa-test-strategy/
  ...
install.sh
```

## Install

Install the shared skills from a local checkout:

```bash
bash install.sh codex project
bash install.sh claude user
bash install.sh cursor project
```

Install from GitHub by overriding the repository URL if needed:

```bash
XXF_ANDROID_SKILLS_REPO=https://github.com/NBXXF/android-skills.git bash install.sh codex project
```

## Install With XXF Library Skills

This repository is the shared Android engineering rule set. XXF library-specific skills live in:

```text
https://github.com/NBXXF/xxf_android/tree/master/skills
```

For third-party Android projects that use XXF libraries, install both repositories. The install scripts use separate Codex markers and separate caches, so they can coexist in the same `AGENTS.md`.

```bash
git clone https://github.com/NBXXF/android-skills.git
cd android-skills
bash install.sh codex project

cd ..
git clone https://github.com/NBXXF/xxf_android.git
cd xxf_android/skills
bash install.sh codex project
```

## Codex Usage

For normal Android coding work, read `xxf-aaa-delivery-loop` first. Then load the narrower skills it references, such as coding style, architecture, testing, review, risk, performance, or clarification.

Project repositories can still keep their own module skills. Use this repository for shared Android process rules, and use project-local skills for concrete module or library details.

## Notes

- Keep `SKILL.md` files concise and procedural.
- Do not put app-private details or concrete library API docs in this shared repository.
- Add only rules that should apply across Android projects.
