---
name: aaaaa-xxf-gradle-dependencies
description: Android Gradle dependency and version-catalog governance. Use when editing build.gradle(.kts), settings.gradle(.kts), libs.versions.toml, plugin versions, dependency coordinates, or when hardcoded versions, duplicate declarations, or legacy direct dependency strings must be detected and migrated.
---

# Gradle Dependencies

## Goal

Keep dependency coordinates, versions, and plugin versions centralized in `libs.versions.toml`.
Gradle build files should consume aliases, bundles, and version refs, not hardcoded version strings.

## Mandatory Rules

- Put library coordinates, plugin versions, and shared version numbers in `libs.versions.toml`.
- Reference them from Gradle with catalog aliases or version refs.
- Do not add new hardcoded dependency coordinates in `build.gradle` or `build.gradle.kts`.
- Do not add new version literals in module build files, root build files, or ad hoc `ext` / `val` / `def` version constants.
- If a dependency is missing from the catalog, add it there first, then update build files to use the alias.
- If a repository still contains legacy hardcoded dependencies, surface them explicitly instead of silently keeping them.

## Required Workflow

1. Inspect the catalog first:
   - `gradle/libs.versions.toml`
   - `settings.gradle` or `settings.gradle.kts`
   - affected `build.gradle` / `build.gradle.kts` files
2. Prefer these catalog forms:
   - `libs.xxx`
   - `libs.bundles.xxx`
   - `libs.plugins.xxx`
   - `version.ref`
3. Migrate hardcoded entries before changing call sites.
4. Keep one source of truth for each version. Do not duplicate the same version in multiple Gradle files.
5. When the repo is not fully migrated, fail loudly with file and line references so the old style is visible.

## Detection And Enforcement

Use the bundled scanner before or after dependency edits:

```bash
python3 .agents/skills/aaaaa-xxf-gradle-dependencies/scripts/scan_gradle_dependencies.py <repo-root>
```

The scanner must flag:

- direct dependency coordinates like `group:artifact:1.2.3`
- plugin version literals in `plugins {}` blocks
- `ext` / `val` / `def` version constants in Gradle files
- other legacy version strings that bypass the catalog

## Migration Standard

- New dependency: add to `libs.versions.toml`, then consume via alias.
- Existing hardcoded dependency: move the coordinate and version into the catalog, then replace the build file usage.
- Existing version constant: delete the constant after replacing its consumers with catalog references.
- If a build file still needs an exception during migration, keep the exception short-lived and call it out in the final note.

## Output Expectations

When this skill is used on a real repo, report:

- which files still violate the catalog rule
- which aliases or version refs should be added
- whether the repo is fully catalog-driven or still in migration
- any unresolved legacy usage that requires follow-up
