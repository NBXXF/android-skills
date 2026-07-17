---
name: aaaaa-xxf-gradle-dependencies
description: Android Gradle dependency, version-catalog, and shared Android SDK configuration governance. Use when editing build.gradle(.kts), settings.gradle(.kts), libs.versions.toml, gradle.properties, plugin versions, dependency coordinates, compileSdk/minSdk/targetSdk values, or when hardcoded versions, duplicate declarations, or legacy direct dependency strings must be detected and migrated.
---

# Gradle Dependencies

## Goal

Keep dependency coordinates, dependency versions, and plugin versions centralized in `libs.versions.toml`.
Keep shared Android SDK configuration centralized in root `gradle.properties`.
Gradle build files should consume aliases, bundles, version refs, or root project properties instead of hardcoded version strings.

## Mandatory Rules

- Put library coordinates, plugin versions, and shared version numbers in `libs.versions.toml`.
- Reference them from Gradle with catalog aliases or version refs.
- Put shared Android compile configuration in root `gradle.properties`, including `COMPILE_SDK_VERSION`, `MIN_SDK_VERSION`, and `TARGET_SDK_VERSION`.
- Module `build.gradle` files must read Android SDK values from project properties, for example:

```groovy
compileSdkVersion project.COMPILE_SDK_VERSION.toInteger()
defaultConfig {
    minSdkVersion project.MIN_SDK_VERSION.toInteger()
    targetSdkVersion project.TARGET_SDK_VERSION.toInteger()
}
```

- Do not add new hardcoded dependency coordinates in `build.gradle` or `build.gradle.kts`.
- Do not add hardcoded `compileSdk`, `minSdk`, or `targetSdk` numbers in module build files.
- Do not add new dependency or plugin version literals in module build files, root build files, or ad hoc `ext` / `val` / `def` version constants.
- If a dependency is missing from the catalog, add it there first, then update build files to use the alias.
- If a repository still contains legacy hardcoded dependencies, surface them explicitly instead of silently keeping them.

## Required Workflow

1. Inspect the catalog first:
   - `gradle/libs.versions.toml`
   - root `gradle.properties`
   - `settings.gradle` or `settings.gradle.kts`
   - affected `build.gradle` / `build.gradle.kts` files
2. Prefer these catalog forms:
   - `libs.xxx`
   - `libs.bundles.xxx`
   - `libs.plugins.xxx`
   - `version.ref`
3. Migrate hardcoded entries before changing call sites.
4. Keep one source of truth for each version. Do not duplicate the same version in multiple Gradle files.
5. Keep one source of truth for Android SDK configuration in root `gradle.properties`, and make every Android module read the same project properties.
6. When the repo is not fully migrated, fail loudly with file and line references so the old style is visible.

## Detection And Enforcement

Use the bundled scanner before or after dependency edits:

```bash
python3 .agents/skills/aaaaa-xxf-gradle-dependencies/scripts/scan_gradle_dependencies.py <repo-root>
```

The scanner must flag:

- direct dependency coordinates like `group:artifact:1.2.3`
- plugin version literals in `plugins {}` blocks
- `ext` / `val` / `def` version constants in Gradle files
- hardcoded module `compileSdk`, `compileSdkVersion`, `minSdk`, `minSdkVersion`, `targetSdk`, or `targetSdkVersion` numbers
- other legacy version strings that bypass the catalog

## Migration Standard

- New dependency: add to `libs.versions.toml`, then consume via alias.
- Existing hardcoded dependency: move the coordinate and version into the catalog, then replace the build file usage.
- Android SDK versions: add or normalize `COMPILE_SDK_VERSION`, `MIN_SDK_VERSION`, and `TARGET_SDK_VERSION` in root `gradle.properties`, then replace module literals with `project.<PROPERTY>.toInteger()` usage.
- Existing version constant: delete the constant after replacing its consumers with catalog references.
- If a build file still needs an exception during migration, keep the exception short-lived and call it out in the final note.

## Output Expectations

When this skill is used on a real repo, report:

- which files still violate the catalog rule
- which aliases or version refs should be added
- whether Android SDK versions are centralized in root `gradle.properties`
- whether the repo is fully catalog-driven or still in migration
- any unresolved legacy usage that requires follow-up
