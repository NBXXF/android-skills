#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEPENDENCY_CALL_RE = re.compile(
    r'^\s*([A-Za-z0-9_]*(?:api|implementation|compileOnly|runtimeOnly|annotationProcessor|kapt|ksp|'
    r'testImplementation|androidTestImplementation|debugImplementation|releaseImplementation))'
    r'\s*(?:\(|\s)\s*["\']([^"\']+:[^"\']+:[^"\']+)["\']'
)
ADD_DEPENDENCY_RE = re.compile(
    r'^\s*add\s*\(\s*["\'][^"\']+["\']\s*,\s*["\']([^"\']+:[^"\']+:[^"\']+)["\']'
)
PLUGIN_VERSION_RE = re.compile(
    r'\bid\s*(?:\(\s*)?["\'][^"\']+["\']\s*\)?\s*version\s*["\']([^"\']+)["\']'
)
ALIAS_PLUGIN_VERSION_RE = re.compile(
    r'\balias\s*\(\s*libs\.plugins\.[^)]+\)\s*version\s*["\']([^"\']+)["\']'
)
VERSION_CONST_RE = re.compile(
    r'^\s*(?:val|var|def)\s+([A-Za-z0-9_]*version[A-Za-z0-9_]*)\s*=\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
EXT_VERSION_RE = re.compile(
    r'^\s*(?:ext\.|extra\[["\'][^"\']*version[^"\']*["\']\]\s*=)\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
ANDROID_SDK_LITERAL_RE = re.compile(
    r'\b(compileSdk|compileSdkVersion|minSdk|minSdkVersion|targetSdk|targetSdkVersion)'
    r'\s*(?:=|\s)\s*(\d+)\b'
)
CLASS_PATH_RE = re.compile(r'^\s*classpath\s*(?:\(|\s)\s*["\']([^"\']+:[^"\']+:[^"\']+)["\']')
LITERAL_COORD_RE = re.compile(r'["\']([^"\']+:[^"\']+:[^"\']+)["\']')
DYNAMIC_VERSION_RE = re.compile(
    r'["\']([^"\']+:[^"\']+:(?:\+|latest\.release|latest\.integration|[^"\']*-SNAPSHOT))["\']',
    re.IGNORECASE,
)
SENSITIVE_LITERAL_RE = re.compile(
    r'^\s*(?:val|var|def)?\s*'
    r'([A-Za-z0-9_.\-\[\]"\']*(?:password|passwd|pwd|username|userName|token|secret|'
    r'credential|signing|keyAlias|keyPassword|storePassword)[A-Za-z0-9_.\-\[\]"\']*)'
    r'\s*(?:=|:)\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
GRADLE_CREDENTIAL_METHOD_RE = re.compile(
    r'^\s*(username|password)\s*(?:=|\s)\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
REPOSITORY_URL_RE = re.compile(
    r'^\s*(?:setUrl\s*\(|url\s*(?:=|\s)\s*(?:uri\s*\()?|uri\s*\()\s*["\'](https?://[^"\']+)["\']',
    re.IGNORECASE,
)
PUBLISHING_METADATA_RE = re.compile(
    r'^\s*(group|version|artifactId|artifact|scmUrl|POM_[A-Za-z0-9_]+|pom[A-Za-z0-9_]*)'
    r'\s*(?:=|\s)\s*["\']([^"\']+)["\']'
)
REPOSITORY_HINT_RE = re.compile(
    r'(maven|nexus|sonatype|artifactory|github\.com/.+/packages|pkg\.github\.com|'
    r'packages|snapshot|release|repo)',
    re.IGNORECASE,
)

SKIP_DIRS = {
    ".git",
    ".gradle",
    ".idea",
    "build",
    "out",
    "node_modules",
    "target",
}

GRADLE_FILE_NAMES = {
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
    "init.gradle",
    "init.gradle.kts",
}


def iter_gradle_files(root: Path):
    for path in root.rglob("*"):
        if path.is_dir():
            continue
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.name in GRADLE_FILE_NAMES or path.name == "libs.versions.toml":
            yield path


def check_file(path: Path):
    findings = []
    if path.name == "libs.versions.toml":
        return findings

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()

    for lineno, line in enumerate(lines, start=1):
        if path.suffix == ".toml":
            continue
        match = DYNAMIC_VERSION_RE.search(line)
        if match:
            findings.append((lineno, f"dynamic or snapshot dependency version '{match.group(1)}'"))
            continue
        match = DEPENDENCY_CALL_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded dependency coordinate '{match.group(2)}'"))
            continue
        match = ADD_DEPENDENCY_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded dependency coordinate '{match.group(1)}'"))
            continue
        match = CLASS_PATH_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded classpath coordinate '{match.group(1)}'"))
            continue
        match = ALIAS_PLUGIN_VERSION_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded alias plugin version override '{match.group(1)}'"))
            continue
        match = PLUGIN_VERSION_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded plugin version '{match.group(1)}'"))
            continue
        match = VERSION_CONST_RE.search(line)
        if match:
            findings.append((lineno, f"version constant '{match.group(1)}' = '{match.group(2)}'"))
            continue
        match = EXT_VERSION_RE.search(line)
        if match:
            findings.append((lineno, f"ext version literal '{match.group(1)}'"))
            continue
        match = ANDROID_SDK_LITERAL_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded Android SDK value '{match.group(1)} {match.group(2)}'"))
            continue
        match = SENSITIVE_LITERAL_RE.search(line)
        if match and match.group(2).strip():
            findings.append((lineno, f"hardcoded sensitive Gradle property '{match.group(1)}'"))
            continue
        match = GRADLE_CREDENTIAL_METHOD_RE.search(line)
        if match and match.group(2).strip():
            findings.append((lineno, f"hardcoded repository credential '{match.group(1)}'"))
            continue
        match = REPOSITORY_URL_RE.search(line)
        if match and REPOSITORY_HINT_RE.search(match.group(1)):
            findings.append((lineno, f"hardcoded publishing/repository URL '{match.group(1)}'"))
            continue
        match = PUBLISHING_METADATA_RE.search(line)
        if match and not any(
            token in line
            for token in ("findProperty", "gradleProperty", "project.", "providers.", "property(")
        ):
            findings.append((lineno, f"hardcoded publishing/build metadata '{match.group(1)}' = '{match.group(2)}'"))
            continue
        if "version" in line.lower() and "libs." not in line and "version.ref" not in line and "libs.versions" not in line:
            for coord in LITERAL_COORD_RE.findall(line):
                if coord.count(":") == 2:
                    findings.append((lineno, f"literal coordinate '{coord}'"))
                    break
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scan Gradle files for hardcoded dependency coordinates and version literals."
    )
    parser.add_argument(
        "root",
        nargs="?",
        default=".",
        help="repository root to scan",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    all_findings = []
    for path in iter_gradle_files(root):
        findings = check_file(path)
        if findings:
            for lineno, message in findings:
                all_findings.append(f"{path.relative_to(root)}:{lineno}: {message}")

    if all_findings:
        print("Gradle dependency policy violations found:")
        for item in all_findings:
            print(f"- {item}")
        print()
        print(
            "Move dependency coordinates and dependency/plugin versions into libs.versions.toml. "
            "Move Android SDK versions, reusable publishing metadata, repository URLs, and non-secret "
            "build constants into root gradle.properties. Resolve credentials and signing secrets from "
            "user-level Gradle properties or CI secrets, then replace build-file literals."
        )
        return 1

    print("No hardcoded Gradle dependency, version, credential, or shared configuration violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
