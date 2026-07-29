---
name: aaaaa-xxf-skill-manage
description: 管理本仓库本地 skill 的源目录与双镜像同步。用于新增、修改、删除、重命名 `skills/`、`.agents/skills/` 和 `.claude/skills/` 下的本地 skill，确保真实本地目录、非软链接、非远端同步产物始终一致。
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Skill 双镜像管理

## 目标

- `skills/` 是本仓库本地 skill 的源目录。
- `.agents/skills/` 和 `.claude/skills/` 是同一批 skill 的镜像目录。
- 本 skill 只处理真实目录，不处理远端同步产物和需要保留的软链接。

## 判定顺序

1. 先确认目标是否属于本仓库本地 skill。
2. 再检查三处路径里是否有软链接。
3. 如果三处都是真实目录，按 `skills/` 为准同步到两个镜像。
4. 如果有任一处是软链接，保留现有链接策略，不把它强行改成实体目录。
5. 如果来源是上游安装产物或远端同步结果，先回到上游来源处理，不直接改镜像目录。

## 修改规则

- 新增 skill：先在 `skills/<name>/` 创建完整内容，再把同样内容复制到 `.agents/skills/<name>/` 和 `.claude/skills/<name>/`。
- 修改 skill：先改 `skills/<name>/`，再把同样补丁同步到两个镜像目录。
- 重命名 skill：新旧名称都要在三处同时处理，旧目录必须全部删除，不能留下孤儿目录。
- 删除 skill：三处目录一起删，不能只删源目录或只删某个镜像。
- 附属文件也要同步，包括 `agents/openai.yaml`、`triggers.md`、`references/`、`scripts/`、`assets/` 等。
- 如果某次变更只碰到了镜像目录，必须在同一轮把 `skills/` 源目录补齐到完全一致。

## 禁止事项

- 不要依赖安装脚本“之后会修好”来接受当前漂移状态。
- 不要只改一侧的 `SKILL.md` 或 `agents/openai.yaml`。
- 不要把软链接展开成实体目录，除非用户明确要求迁移。
- 不要把远端同步产物当成本地可自由编辑的源文件。
- 不要保留只存在于单侧镜像的附属文件。

## 推荐流程

1. 定位目标 skill，确认它在三处目录中的存在状态。
2. 判断它是本地实体目录、软链接还是远端同步产物。
3. 如果是本地实体目录，直接以 `skills/` 为准修改，再同步两个镜像目录。
4. 如果是软链接，先保留链接，再决定是否需要修改链接目标。
5. 如果是远端同步产物，回到上游生成源修正，不在镜像目录做临时补丁。

## 快速检查

- `skills/<name>`、`.agents/skills/<name>`、`.claude/skills/<name>` 的 `SKILL.md` frontmatter 和正文一致。
- `agents/openai.yaml` 在三处目录内容一致。
- 任何附属文件的文件名、内容和数量一致。
- `test -L` 结果符合预期，软链接没有被误替换。
- `diff -ru skills/<name> .agents/skills/<name>` 和 `diff -ru skills/<name> .claude/skills/<name>` 都没有差异。
