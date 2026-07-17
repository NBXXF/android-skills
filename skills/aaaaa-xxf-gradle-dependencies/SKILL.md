---
name: aaaaa-xxf-gradle-dependencies
description: Android Gradle dependency, version-catalog, version freshness, and shared Android SDK configuration governance. Use when editing build.gradle(.kts), settings.gradle(.kts), libs.versions.toml, gradle.properties, plugin versions, dependency coordinates, Gradle/Android build plugin versions, compileSdk/minSdk/targetSdk values, or when hardcoded versions, duplicate declarations, stale versions, or legacy direct dependency strings must be detected and migrated.
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Gradle Dependencies

## Goal

Keep dependency coordinates, dependency versions, and plugin versions centralized in `libs.versions.toml`.
Keep catalog versions reasonably current, and document any version that intentionally cannot be upgraded.
Keep shared Android SDK configuration centralized in root `gradle.properties`.
Gradle build files should consume aliases, bundles, version refs, or root project properties instead of hardcoded version strings.

## Mandatory Rules

- Put library coordinates, plugin versions, and shared version numbers in `libs.versions.toml`.
- Put Android Gradle Plugin, Kotlin Gradle Plugin, KSP, Hilt, Dokka, protobuf, navigation Safe Args, Maven Publish helper plugins, and other build-tool plugin versions in `libs.versions.toml`.
- Reference them from Gradle with catalog aliases or version refs.
- Prefer the latest stable compatible dependency and plugin versions when adding or touching catalog entries.
- If a dependency or plugin cannot be upgraded to the latest stable compatible version, add a concise comment in `libs.versions.toml` explaining the blocker, for example an AGP/Kotlin compatibility limit, minSdk/API constraint, transitive regression, binary compatibility issue, or pending upstream fix.
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
4. Check whether touched dependency and plugin versions are still current before finalizing the catalog edit.
5. Keep one source of truth for each version. Do not duplicate the same version in multiple Gradle files.
6. Keep one source of truth for Android SDK configuration in root `gradle.properties`, and make every Android module read the same project properties.
7. When the repo is not fully migrated, fail loudly with file and line references so the old style is visible.

## Version Freshness Standard

- New catalog entries should use the latest stable compatible release, not an old version copied from examples or previous modules.
- Existing catalog entries touched during a change should be upgraded to the latest stable compatible release when the upgrade is within the task scope and does not introduce unrelated migration work.
- Do not use alpha, beta, RC, snapshot, or dynamic versions such as `+` unless the user explicitly requests them or the repository already has a documented preview-version policy.
- If latest stable cannot be used, keep the pinned version in `libs.versions.toml` and add a nearby comment that states the concrete reason and, when known, the condition for removing the pin.
- Comments must explain the constraint, not restate the version number.

Example:

```toml
[versions]
# Pinned until Kotlin 2.1 migration is complete; AGP 8.8+ requires the newer Kotlin toolchain in this repo.
agp = "8.7.3"

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
```

## Detection And Enforcement

Use the bundled scanner before or after dependency edits:

```bash
python3 scripts/scan_gradle_dependencies.py <repo-root>
```

The scanner must flag:

- direct dependency coordinates like `group:artifact:1.2.3`
- plugin version literals in `plugins {}` blocks
- Android Gradle Plugin, Kotlin Gradle Plugin, KSP, Hilt, Dokka, protobuf, Safe Args, or other build-tool plugin versions outside `libs.versions.toml`
- `ext` / `val` / `def` version constants in Gradle files
- hardcoded module `compileSdk`, `compileSdkVersion`, `minSdk`, `minSdkVersion`, `targetSdk`, or `targetSdkVersion` numbers
- other legacy version strings that bypass the catalog

## Migration Standard

- New dependency: add to `libs.versions.toml`, then consume via alias.
- Existing hardcoded dependency: move the coordinate and version into the catalog, then replace the build file usage.
- Build-tool plugin version: move the plugin id and version into `libs.versions.toml` `[plugins]`, back it with a `[versions]` entry when reused, then consume it via `alias(libs.plugins.xxx)`.
- Stale catalog version: update to the latest stable compatible version, or keep the pinned version with a specific `libs.versions.toml` comment explaining why it cannot move yet.
- Android SDK versions: add or normalize `COMPILE_SDK_VERSION`, `MIN_SDK_VERSION`, and `TARGET_SDK_VERSION` in root `gradle.properties`, then replace module literals with `project.<PROPERTY>.toInteger()` usage.
- Existing version constant: delete the constant after replacing its consumers with catalog references.
- If a build file still needs an exception during migration, keep the exception short-lived and call it out in the final note.

## Output Expectations

When this skill is used on a real repo, report:

- which files still violate the catalog rule
- which aliases or version refs should be added
- which touched dependencies or plugins were updated to latest stable compatible versions
- which catalog versions remain pinned and the comment explaining why
- whether Android SDK versions are centralized in root `gradle.properties`
- whether the repo is fully catalog-driven or still in migration
- any unresolved legacy usage that requires follow-up
