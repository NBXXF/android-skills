#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEPENDENCY_CALL_RE = re.compile(
    r'^\s*(api|implementation|compileOnly|runtimeOnly|kapt|ksp|'
    r'testImplementation|androidTestImplementation|debugImplementation|releaseImplementation)'
    r'\s*(?:\(|\s)\s*["\']([^"\']+:[^"\']+:[^"\']+)["\']'
)
PLUGIN_VERSION_RE = re.compile(r'^\s*id\s*\(\s*["\'][^"\']+["\']\s*\)\s*version\s*["\']([^"\']+)["\']')
VERSION_CONST_RE = re.compile(
    r'^\s*(?:val|var|def)\s+([A-Za-z0-9_]*version[A-Za-z0-9_]*)\s*=\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
EXT_VERSION_RE = re.compile(
    r'^\s*(?:ext\.|extra\[["\'][^"\']*version[^"\']*["\']\]\s*=)\s*["\']([^"\']+)["\']',
    re.IGNORECASE,
)
ANDROID_SDK_LITERAL_RE = re.compile(
    r'^\s*(compileSdk|compileSdkVersion|minSdk|minSdkVersion|targetSdk|targetSdkVersion)'
    r'\s*(?:=|\s)\s*(\d+)\b'
)
CLASS_PATH_RE = re.compile(r'^\s*classpath\s*(?:\(|\s)\s*["\']([^"\']+:[^"\']+:[^"\']+)["\']')
LITERAL_COORD_RE = re.compile(r'["\']([^"\']+:[^"\']+:[^"\']+)["\']')

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
        match = DEPENDENCY_CALL_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded dependency coordinate '{match.group(2)}'"))
            continue
        match = CLASS_PATH_RE.search(line)
        if match:
            findings.append((lineno, f"hardcoded classpath coordinate '{match.group(1)}'"))
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
            "Move Android SDK versions into root gradle.properties, then replace build-file literals."
        )
        return 1

    print("No hardcoded Gradle dependency or version violations found.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
