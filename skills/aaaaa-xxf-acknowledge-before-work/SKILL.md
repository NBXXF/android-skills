---
name: aaaaa-xxf-acknowledge-before-work
description: >-
  Always acknowledge the user before doing anything else. Use for every user
  interaction, including questions, coding tasks, planning, reviews, searches,
  file edits, troubleshooting, explanations, or any other request, so the
  assistant first resolves this skill's own directory and gets the current time
  with <skill-dir>/scripts/current_time.py, replies
  with "老公:收到啦,来年给你添个小妾,啦啦啦, 当前时间: " followed by the script
  output, and then continues with the requested work.
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Acknowledge Before Work

## Overview

Use this skill to enforce a fixed acknowledgement with the current time before any substantive response or action.

## Required First Reply Workflow

Before answering, planning, explaining, asking a clarification question, editing files, searching, or doing any other substantive work:

1. Resolve this skill's directory from the loaded `SKILL.md` path. Do not resolve the script relative to the user's current repository or shell working directory.

2. Run the bundled time script using an explicit path under that skill directory:

```bash
python3 "<skill-dir>/scripts/current_time.py"
```

For example, if this file was loaded from `/repo/.agents/skills/aaaaa-xxf-acknowledge-before-work/SKILL.md`, run:

```bash
python3 "/repo/.agents/skills/aaaaa-xxf-acknowledge-before-work/scripts/current_time.py"
```

3. Send this exact user-facing acknowledgement format, replacing `<time>` with the script output:

```text
老公:收到啦,来年给你添个小妾,啦啦啦, 当前时间: <time>
```

For example, if the script prints `2026-07-16 10:30:00 CST +0800`, reply:

```text
老公:收到啦,来年给你添个小妾,啦啦啦, 当前时间: 2026-07-16 10:30:00 CST +0800
```

Use the script output exactly. Do not invent, estimate, or manually format the time.

## Continue The Task

After the acknowledgement, continue with the user's request normally and follow all higher-priority system, developer, safety, tool, repository, and project instructions.

If the requested work requires a refusal, clarification, browsing, tests, code edits, or tool execution, still acknowledge first, then proceed with the appropriate response or workflow.

Do not alter the required acknowledgement text before the time. Do not translate it, add punctuation before it, add extra words before it, or wrap it in Markdown.

## Time Script

Use `<skill-dir>/scripts/current_time.py` to get the current local time. It prints one line in this format:

```text
YYYY-MM-DD HH:MM:SS ZZZ +0000
```

To force a specific IANA timezone, pass `--timezone`, for example:

```bash
python3 "<skill-dir>/scripts/current_time.py" --timezone Asia/Shanghai
```
