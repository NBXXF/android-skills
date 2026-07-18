---
name: aaaaa-xxf-gradle-dependencies
description: Android Gradle dependency, version-catalog, version freshness, shared Android SDK configuration, publishing configuration, credentials, and reusable Gradle property governance. Use when editing build.gradle(.kts), settings.gradle(.kts), libs.versions.toml, gradle.properties, plugin versions, dependency coordinates, Gradle/Android build plugin versions, compileSdk/minSdk/targetSdk values, Maven publishing/signing/repository credentials, or when hardcoded versions, duplicate declarations, stale versions, secrets, URLs, toggles, or legacy direct dependency strings must be detected and migrated.
---

> 备注：此 skill 来自 https://github.com/NBXXF/android-skills，请不要手动修改！新增或维护本工程内的 skill 时也必须保留此备注规则，方便其他业务引用方识别来源。

# Gradle Dependencies

## Goal

Keep dependency coordinates, dependency versions, and plugin versions centralized in `libs.versions.toml`.
Keep catalog versions reasonably current, and document any version that intentionally cannot be upgraded.
Keep shared Android SDK configuration, publishing metadata, repository endpoints, non-sensitive build toggles, and reusable build constants centralized in `gradle.properties`.
Keep real credentials out of committed Gradle files; read them from Gradle properties supplied by user-level `~/.gradle/gradle.properties`, CI secret injection, or an uncommitted local properties file.
Gradle build files should consume aliases, bundles, version refs, or project/provider properties instead of hardcoded version strings, URLs, credentials, and duplicated configuration literals.

## Mandatory Rules

- Put library coordinates, plugin versions, and shared version numbers in `libs.versions.toml`.
- Put Android Gradle Plugin, Kotlin Gradle Plugin, KSP, Hilt, Dokka, protobuf, navigation Safe Args, Maven Publish helper plugins, and other build-tool plugin versions in `libs.versions.toml`.
- Reference them from Gradle with catalog aliases or version refs.
- Manage plugin repositories and dependency repositories from `settings.gradle(.kts)` through `pluginManagement` and `dependencyResolutionManagement` when the repo already uses centralized repository management.
- Prefer BOMs, platforms, bundles, and constraints through the version catalog when they reduce duplicate version pins; do not duplicate a BOM-managed library version in module dependencies.
- Prefer the latest stable compatible dependency and plugin versions when adding or touching catalog entries.
- If a dependency or plugin cannot be upgraded to the latest stable compatible version, add a concise comment in `libs.versions.toml` explaining the blocker, for example an AGP/Kotlin compatibility limit, minSdk/API constraint, transitive regression, binary compatibility issue, or pending upstream fix.
- Put shared Android compile configuration in root `gradle.properties`, including `COMPILE_SDK_VERSION`, `MIN_SDK_VERSION`, and `TARGET_SDK_VERSION`.
- Put reusable non-secret Gradle configuration in root `gradle.properties` instead of repeating it in `build.gradle` files. Good candidates include Android SDK versions, Java/Kotlin JVM target, Maven group/artifact/version metadata, POM metadata, repository URLs, feature flags used by multiple modules, publishing switches, test runner defaults, resource prefix, and shared Android build feature toggles.
- Put secret or machine-specific values in Gradle properties resolved at build time, but do not commit real secrets. Examples: Maven/Nexus/GitHub Packages usernames and passwords, signing key id/password/key material, keystore passwords, API tokens, private repository credentials, and CI-only publishing credentials.
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
- Do not add dynamic versions (`+`, `latest.release`, `latest.integration`) or changing snapshot dependencies unless the user explicitly requests them and the risk is documented.
- Do not add hardcoded credentials, tokens, signing passwords, keystore passwords, private repository credentials, or publish account values in any Gradle file.
- Do not repeat Maven publishing coordinates, repository URLs, signing configuration, or common build toggles in multiple Gradle files when they can be read from project properties.
- If a dependency is missing from the catalog, add it there first, then update build files to use the alias.
- If a repository still contains legacy hardcoded dependencies, surface them explicitly instead of silently keeping them.

## Required Workflow

1. Inspect the catalog first:
   - `gradle/libs.versions.toml`
   - root `gradle.properties`
   - `settings.gradle` or `settings.gradle.kts`
   - affected `build.gradle` / `build.gradle.kts` files
   - included build convention plugins under `build-logic`, `buildSrc`, or `gradle/` when they own dependency/plugin wiring
2. Prefer these catalog forms:
   - `libs.xxx`
   - `libs.bundles.xxx`
   - `libs.plugins.xxx`
   - `version.ref`
   - `platform(libs.xxx)` / `enforcedPlatform(libs.xxx)` for BOMs when appropriate
3. Migrate hardcoded entries before changing call sites.
4. Check whether touched dependency and plugin versions are still current before finalizing the catalog edit.
5. Keep one source of truth for each version. Do not duplicate the same version in multiple Gradle files.
6. Keep one source of truth for Android SDK configuration in root `gradle.properties`, and make every Android module read the same project properties.
7. Move reusable build constants and publish configuration into Gradle properties before wiring module build files.
8. For credentials, define property names in Gradle code and document expected keys, but require actual values from user-level Gradle properties, CI secrets, or ignored local files.
9. When the repo is not fully migrated, fail loudly with file and line references so the old style is visible.

## Gradle Property Governance

Use `libs.versions.toml` for dependency and plugin identity/version data. Use Gradle properties for build configuration that is not a dependency coordinate.

Prefer root `gradle.properties` for committed, shared, non-secret defaults:

```properties
COMPILE_SDK_VERSION=36
MIN_SDK_VERSION=23
TARGET_SDK_VERSION=36
JAVA_VERSION=17
KOTLIN_JVM_TARGET=17
PUBLISH_GROUP_ID=com.example
PUBLISH_VERSION=1.0.0
MAVEN_RELEASE_REPOSITORY_URL=https://repo.example.com/releases
MAVEN_SNAPSHOT_REPOSITORY_URL=https://repo.example.com/snapshots
```

Prefer user-level `~/.gradle/gradle.properties`, CI Gradle properties, or ignored local files for secrets:

```properties
MAVEN_USERNAME=...
MAVEN_PASSWORD=...
SIGNING_KEY_ID=...
SIGNING_PASSWORD=...
SIGNING_SECRET_KEY_RING_FILE=...
```

Read properties through Gradle provider APIs when possible so missing optional publishing values do not break normal local builds:

```kotlin
val mavenUsername = providers.gradleProperty("MAVEN_USERNAME")
val mavenPassword = providers.gradleProperty("MAVEN_PASSWORD")
```

In Groovy builds, use a small helper or `findProperty("KEY")` consistently:

```groovy
def mavenUsername = findProperty("MAVEN_USERNAME")
def mavenPassword = findProperty("MAVEN_PASSWORD")
```

Good extraction candidates from `build.gradle` / `build.gradle.kts`:

- **Dependency identity and versions**: dependency coordinates, plugin ids, plugin versions, BOM versions, annotation processor versions -> `libs.versions.toml`.
- **Android shared config**: `compileSdk`, `minSdk`, `targetSdk`, Java source/target compatibility, Kotlin `jvmTarget`, NDK/CMake versions when shared -> root `gradle.properties`.
- **Publishing metadata**: `group`, `version`, artifact id conventions, POM name/description/url, license, developer, SCM, release/snapshot repository URLs -> root `gradle.properties` when shared.
- **Credentials and signing**: repository username/password, tokens, signing key id/password/key material, keystore password/key alias -> Gradle properties supplied by user/CI, never hardcoded or committed with real values.
- **Repository endpoints**: internal Maven, Nexus, Artifactory, GitHub Packages, plugin repository URLs -> root `gradle.properties` if project-wide, with credentials externalized.
- **Common build toggles**: `android.useAndroidX`, nonTransitive R, build cache/configuration cache toggles, publishing enable flags, compose compiler reports flags, shared `BuildConfig` environment switches -> `gradle.properties` if they are cross-module policy.
- **Repeated Android defaults**: `testInstrumentationRunner`, resource prefix, consumer ProGuard file names, packaging excludes, lint baseline/fatal policy, namespace prefix conventions -> convention plugin or root property, depending on whether logic or plain data is needed.

Do not move module-specific values into global properties just because they are literals. Keep values local when they are genuinely module identity or behavior, for example `namespace`, app `applicationId`, manifest placeholders unique to one app, or a dependency used by one module only.

## Version Freshness Standard

- New catalog entries should use the latest stable compatible release, not an old version copied from examples or previous modules.
- Existing catalog entries touched during a change should be upgraded to the latest stable compatible release when the upgrade is within the task scope and does not introduce unrelated migration work.
- Do not use alpha, beta, RC, snapshot, or dynamic versions such as `+` unless the user explicitly requests them or the repository already has a documented preview-version policy.
- Treat AGP, Kotlin, KSP, Compose compiler, Hilt, Room, Navigation, and Gradle wrapper as a compatibility set; do not bump one item across a known compatibility boundary without checking the paired toolchain.
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
- dynamic dependency versions like `group:artifact:+`, `latest.release`, and `latest.integration`
- plugin version literals in `plugins {}` blocks
- Android Gradle Plugin, Kotlin Gradle Plugin, KSP, Hilt, Dokka, protobuf, Safe Args, or other build-tool plugin versions outside `libs.versions.toml`
- `ext` / `val` / `def` version constants in Gradle files
- hardcoded module `compileSdk`, `compileSdkVersion`, `minSdk`, `minSdkVersion`, `targetSdk`, or `targetSdkVersion` numbers
- hardcoded credentials, tokens, signing secrets, keystore passwords, or publish account values
- hardcoded Maven/Nexus/Artifactory/GitHub Packages publishing repository URLs
- repeated publishing coordinates or publish metadata that should be read from Gradle properties
- other legacy version strings that bypass the catalog

The scanner is a fast gate, not a full Gradle model. If it reports a false positive, explain the specific exception in the final note; if a Gradle file uses unusual dynamic construction, inspect it manually.

## Migration Standard

- New dependency: add to `libs.versions.toml`, then consume via alias.
- Existing hardcoded dependency: move the coordinate and version into the catalog, then replace the build file usage.
- Build-tool plugin version: move the plugin id and version into `libs.versions.toml` `[plugins]`, back it with a `[versions]` entry when reused, then consume it via `alias(libs.plugins.xxx)`.
- Stale catalog version: update to the latest stable compatible version, or keep the pinned version with a specific `libs.versions.toml` comment explaining why it cannot move yet.
- Android SDK versions: add or normalize `COMPILE_SDK_VERSION`, `MIN_SDK_VERSION`, and `TARGET_SDK_VERSION` in root `gradle.properties`, then replace module literals with `project.<PROPERTY>.toInteger()` usage.
- Shared build constants: add a clearly named uppercase property in root `gradle.properties`, then replace repeated build-file literals with `findProperty(...)`, `project.<PROPERTY>`, or `providers.gradleProperty(...)` according to the Gradle DSL in use.
- Publishing and repository configuration: centralize non-secret metadata and URLs in root `gradle.properties`; resolve credentials from Gradle properties supplied by user/CI; make publish tasks fail with a clear missing-property message only when publishing is requested.
- Secrets: remove hardcoded values immediately, rotate them if they were committed, and do not move real secret values into committed root `gradle.properties`.
- Existing version constant: delete the constant after replacing its consumers with catalog references.
- BOM/platform migration: add the BOM to `[libraries]`, consume it with `platform(libs.xxx)` or `enforcedPlatform(libs.xxx)`, and remove redundant versions from BOM-managed module aliases.
- Convention plugin migration: if `buildSrc` or `build-logic` owns dependency aliases, keep catalog access there and prevent module build files from reintroducing hardcoded coordinates.
- If a build file still needs an exception during migration, keep the exception short-lived and call it out in the final note.

## Output Expectations

When this skill is used on a real repo, report:

- which files still violate the catalog rule
- which aliases or version refs should be added
- which touched dependencies or plugins were updated to latest stable compatible versions
- which catalog versions remain pinned and the comment explaining why
- whether Android SDK versions are centralized in root `gradle.properties`
- whether reusable non-secret build configuration is centralized in root `gradle.properties`
- whether publish credentials/signing secrets are externalized through Gradle properties without committed secret values
- whether the repo is fully catalog-driven or still in migration
- any unresolved legacy usage that requires follow-up
