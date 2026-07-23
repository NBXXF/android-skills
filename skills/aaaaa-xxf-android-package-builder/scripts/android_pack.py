#!/usr/bin/env python3
"""Interactive and parameterized Android APK/AAB packaging helper."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


COMMON_BUILD_TYPE_ORDER = [
    "debug",
    "release",
    "staging",
    "qa",
    "benchmark",
    "profile",
]


@dataclass(frozen=True)
class VariantTask:
    artifact: str
    task_name: str
    variant_name: str
    build_type: str
    flavor_name: str


def lower_first(value: str) -> str:
    if not value:
        return value
    return value[0].lower() + value[1:]


def upper_first(value: str) -> str:
    if not value:
        return value
    return value[0].upper() + value[1:]


def normalize_module(module: str) -> str:
    module = module.strip()
    if not module:
        return ""
    if module == ":":
        return ""
    return module if module.startswith(":") else f":{module}"


def module_to_dir(root: Path, module: str) -> Path:
    module = normalize_module(module)
    if not module:
        return root
    return root.joinpath(*[part for part in module.split(":") if part])


def find_project_root(start: Path) -> Path:
    current = start.resolve()
    for path in [current, *current.parents]:
        if (path / "gradlew").is_file() and (
            (path / "settings.gradle").is_file()
            or (path / "settings.gradle.kts").is_file()
        ):
            return path
    raise SystemExit(
        "ERROR: 当前目录不在包含 gradlew 和 settings.gradle(.kts) 的 Android 工程内。"
    )


def run_checked(command: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            cwd=str(cwd),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SystemExit(f"ERROR: 命令不存在: {command[0]}") from exc


def gradle_tasks_output(root: Path, gradlew: str, module: str, gradle_args: list[str]) -> str:
    module = normalize_module(module)
    task = f"{module}:tasks" if module else "tasks"
    command = [
        gradlew,
        task,
        "--all",
        "--console=plain",
        "--no-daemon",
        *gradle_args,
    ]
    print(f"Inspecting Gradle tasks: {' '.join(command)}")
    result = run_checked(command, root)
    if result.returncode != 0:
        raise SystemExit(
            "ERROR: Gradle 任务列表读取失败，无法可靠识别可打包 variant。\n"
            + result.stdout
        )
    return result.stdout


def read_build_types_from_files(module_dir: Path) -> list[str]:
    candidates = [
        module_dir / "build.gradle",
        module_dir / "build.gradle.kts",
    ]
    names: list[str] = []
    for path in candidates:
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8", errors="replace")
        for block in re.finditer(r"buildTypes\s*\{(?P<body>.*?)^\s*\}", content, re.S | re.M):
            body = block.group("body")
            for match in re.finditer(r"^\s*([A-Za-z][A-Za-z0-9_]*)\s*(?:\{|=)", body, re.M):
                name = match.group(1)
                if name not in {"getByName", "create", "maybeCreate", "register"}:
                    names.append(name)
            for match in re.finditer(r"(?:create|getByName|maybeCreate)\([\"']([^\"']+)[\"']\)", body):
                names.append(match.group(1))
    return dedupe_preserve(names)


def dedupe_preserve(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        key = value.lower()
        if key in seen:
            continue
        seen.add(key)
        result.append(value)
    return result


def parse_task_names(output: str) -> dict[str, set[str]]:
    tasks: dict[str, set[str]] = {"apk": set(), "aab": set()}
    for raw_line in output.splitlines():
        line = raw_line.strip()
        match = re.match(r"^(assemble|bundle)([A-Z][A-Za-z0-9_]*)\b", line)
        if not match:
            continue
        prefix, variant = match.groups()
        if variant in {"AndroidTest", "Test", "UnitTest"}:
            continue
        artifact = "apk" if prefix == "assemble" else "aab"
        tasks[artifact].add(f"{prefix}{variant}")
    return tasks


def infer_build_types(task_names: dict[str, set[str]], configured: list[str]) -> list[str]:
    configured_lower = {item.lower(): item for item in configured}
    found: list[str] = configured[:]

    for default_name in ["debug", "release"]:
        cap = upper_first(default_name)
        if any(f"assemble{cap}" in names or f"bundle{cap}" in names for names in [*task_names.values()]):
            if default_name not in configured_lower:
                found.append(default_name)

    for artifact_tasks in task_names.values():
        for task_name in artifact_tasks:
            variant = re.sub(r"^(assemble|bundle)", "", task_name)
            for build_type in [*configured, *COMMON_BUILD_TYPE_ORDER]:
                if variant.endswith(upper_first(build_type)):
                    if build_type.lower() not in {item.lower() for item in found}:
                        found.append(build_type)

    def sort_key(name: str) -> tuple[int, str]:
        lower = name.lower()
        try:
            return (COMMON_BUILD_TYPE_ORDER.index(lower), lower)
        except ValueError:
            return (len(COMMON_BUILD_TYPE_ORDER), lower)

    return sorted(dedupe_preserve(found), key=sort_key)


def build_variant_tasks(task_names: dict[str, set[str]], build_types: list[str]) -> list[VariantTask]:
    result: list[VariantTask] = []
    build_types_sorted = sorted(build_types, key=len, reverse=True)
    for artifact, names in task_names.items():
        prefix = "assemble" if artifact == "apk" else "bundle"
        for task_name in sorted(names):
            variant_cap = task_name.removeprefix(prefix)
            matched_build_type = ""
            for build_type in build_types_sorted:
                build_type_cap = upper_first(build_type)
                if variant_cap == build_type_cap or variant_cap.endswith(build_type_cap):
                    matched_build_type = build_type
                    break
            if not matched_build_type:
                continue
            build_type_cap = upper_first(matched_build_type)
            flavor_cap = variant_cap[: -len(build_type_cap)] if variant_cap != build_type_cap else ""
            result.append(
                VariantTask(
                    artifact=artifact,
                    task_name=task_name,
                    variant_name=lower_first(variant_cap),
                    build_type=matched_build_type,
                    flavor_name=lower_first(flavor_cap),
                )
            )
    return result


def choose_number(title: str, options: list[str]) -> str:
    if not options:
        raise SystemExit(f"ERROR: 没有可选择的{title}。")
    print(title)
    for index, option in enumerate(options, start=1):
        print(f"{index}. {option}")
    while True:
        answer = input("请输入编号: ").strip()
        if answer.isdigit():
            index = int(answer)
            if 1 <= index <= len(options):
                return options[index - 1]
        print("输入无效，请重新输入列表中的编号。")


def require_interactive(args: argparse.Namespace) -> None:
    if sys.stdin.isatty():
        return
    missing = []
    if not args.variant and not args.build_type:
        missing.append("--build-type 或 --variant")
    if not args.artifact:
        missing.append("--artifact")
    if missing:
        raise SystemExit(
            "ERROR: 当前不是交互式终端，缺少参数: "
            + ", ".join(missing)
            + "。可先运行 --list 查看可用选项。"
        )


def resolve_by_name(name: str, options: list[str], label: str) -> str:
    wanted = name.lower()
    matches = [option for option in options if option.lower() == wanted]
    if len(matches) == 1:
        return matches[0]
    partial = [option for option in options if wanted in option.lower()]
    if len(partial) == 1:
        return partial[0]
    if not matches and not partial:
        raise SystemExit(f"ERROR: 找不到{label}: {name}。可用选项: {', '.join(options)}")
    raise SystemExit(f"ERROR: {label}不唯一: {name}。匹配项: {', '.join(partial)}")


def format_variant_line(task: VariantTask) -> str:
    flavor = task.flavor_name if task.flavor_name else "(no flavor)"
    return f"{task.variant_name}  buildType={task.build_type}  flavor={flavor}  artifact={task.artifact}"


def print_available(variant_tasks: list[VariantTask], build_types: list[str]) -> None:
    print("Build types:")
    for index, build_type in enumerate(build_types, start=1):
        print(f"{index}. {build_type}")

    flavors = dedupe_preserve(task.flavor_name for task in variant_tasks if task.flavor_name)
    if flavors:
        print("\nFlavors / channels:")
        for index, flavor in enumerate(flavors, start=1):
            print(f"{index}. {flavor}")
    else:
        print("\nFlavors / channels: none")

    print("\nArtifacts:")
    print("1. apk")
    print("2. aab")

    print("\nVariants:")
    for index, task in enumerate(sorted(variant_tasks, key=lambda item: (item.variant_name, item.artifact)), start=1):
        print(f"{index}. {format_variant_line(task)}  task={task.task_name}")


def select_task(args: argparse.Namespace, variant_tasks: list[VariantTask], build_types: list[str]) -> VariantTask:
    require_interactive(args)

    if args.variant and not sys.stdin.isatty():
        variant_pool = variant_tasks
        flavored_pool = [task for task in variant_tasks if task.flavor_name]
        if flavored_pool:
            variant_pool = flavored_pool
        if args.artifact:
            artifact = resolve_by_name(args.artifact, dedupe_preserve(task.artifact for task in variant_pool), "产物类型")
            variant_pool = [task for task in variant_pool if task.artifact == artifact]
        variants = dedupe_preserve(task.variant_name for task in variant_pool)
        variant = resolve_by_name(args.variant, variants, "variant")
        matches = [task for task in variant_pool if task.variant_name == variant]
        if len(matches) == 1:
            return matches[0]
        if not args.artifact and sys.stdin.isatty():
            artifact = choose_number(
                "请选择产物类型:",
                [item for item in ["apk", "aab"] if item in dedupe_preserve(task.artifact for task in matches)],
            )
            matches = [task for task in matches if task.artifact == artifact]
            if len(matches) == 1:
                return matches[0]
        lines = [format_variant_line(task) for task in matches]
        raise SystemExit("ERROR: variant 匹配不唯一: " + "; ".join(lines))

    if args.build_type:
        build_type = resolve_by_name(args.build_type, build_types, "buildType")
    else:
        available_build_types = dedupe_preserve(task.build_type for task in variant_tasks)
        build_type = choose_number("请选择打包类型,请回复数字", available_build_types)

    build_type_tasks = [task for task in variant_tasks if task.build_type.lower() == build_type.lower()]
    if not build_type_tasks:
        raise SystemExit(f"ERROR: 没有 buildType={build_type} 的打包任务。")

    requested_flavor = args.flavor or args.channel
    flavors = dedupe_preserve(task.flavor_name for task in build_type_tasks if task.flavor_name)
    no_flavor_tasks = [task for task in build_type_tasks if not task.flavor_name]

    if flavors:
        if requested_flavor:
            flavor = resolve_by_name(requested_flavor, flavors, "flavor/channel")
        elif sys.stdin.isatty():
            flavor = choose_number("请选择打包渠道,请回复数字", flavors)
        else:
            raise SystemExit("ERROR: 当前项目存在 flavor，缺少 --flavor/--channel。")
        matches = [task for task in build_type_tasks if task.flavor_name.lower() == flavor.lower()]
    elif requested_flavor:
        raise SystemExit("ERROR: 当前选择没有 flavor，但传入了 --flavor/--channel。")
    else:
        matches = no_flavor_tasks

    artifacts = dedupe_preserve(task.artifact for task in matches)
    if args.artifact:
        artifact = resolve_by_name(args.artifact, artifacts, "产物类型")
    elif sys.stdin.isatty():
        artifact = choose_number("请选择打包格式,请回复数字", [item for item in ["apk", "aab"] if item in artifacts])
    else:
        raise SystemExit("ERROR: 缺少 --artifact apk|aab。")
    matches = [task for task in matches if task.artifact == artifact]

    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise SystemExit("ERROR: 没有找到匹配的打包任务。可先运行 --list 查看可用组合。")

    chosen = choose_number("请选择 variant:", [format_variant_line(task) for task in matches])
    for task in matches:
        if format_variant_line(task) == chosen:
            return task
    raise SystemExit("ERROR: 选择失败。")


def find_recent_outputs(module_dir: Path, artifact: str, start_time: float) -> list[Path]:
    extension = ".apk" if artifact == "apk" else ".aab"
    output_root = module_dir / "build" / "outputs"
    if not output_root.exists():
        return []
    outputs = [
        path
        for path in output_root.rglob(f"*{extension}")
        if path.is_file() and path.stat().st_mtime >= start_time - 2
    ]
    return sorted(outputs, key=lambda path: path.stat().st_mtime, reverse=True)


def print_command_output(output: str) -> None:
    text = output.rstrip()
    if text:
        print(text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Detect Android Gradle build variants and build APK/AAB artifacts."
    )
    parser.add_argument("--build-type", help="Build type, such as debug or release.")
    parser.add_argument("--flavor", help="Flavor/channel name.")
    parser.add_argument("--channel", help="Alias of --flavor.")
    parser.add_argument("--artifact", choices=["apk", "aab"], help="Artifact type.")
    parser.add_argument("--variant", help="Full variant name, such as demoRelease.")
    parser.add_argument("--module", default=":app", help="Android app module, default: :app.")
    parser.add_argument("--gradlew", default="./gradlew", help="Gradle wrapper path, default: ./gradlew.")
    parser.add_argument("--gradle-arg", action="append", default=[], help="Extra Gradle arg; repeatable.")
    parser.add_argument("--list", action="store_true", help="List available choices and exit.")
    parser.add_argument("--dry-run", action="store_true", help="Print Gradle task without executing it.")
    parser.add_argument("extra_gradle_args", nargs=argparse.REMAINDER, help="Extra Gradle args after --.")
    return parser.parse_args(argv)


def collect_gradle_args(args: argparse.Namespace) -> list[str]:
    extra = list(args.gradle_arg)
    remainder = list(args.extra_gradle_args)
    if remainder and remainder[0] == "--":
        remainder = remainder[1:]
    return [*extra, *remainder]


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = find_project_root(Path.cwd())
    module = normalize_module(args.module)
    module_dir = module_to_dir(root, module)
    if not module_dir.exists():
        raise SystemExit(f"ERROR: module 目录不存在: {module_dir}")

    gradlew = args.gradlew
    if gradlew == "./gradlew":
        gradlew_path = root / "gradlew"
        if not gradlew_path.is_file():
            raise SystemExit("ERROR: 找不到 Gradle wrapper: ./gradlew")
        gradlew = str(gradlew_path)

    gradle_args = collect_gradle_args(args)
    output = gradle_tasks_output(root, gradlew, module, gradle_args)
    task_names = parse_task_names(output)
    if not task_names["apk"] and not task_names["aab"]:
        raise SystemExit("ERROR: 没有识别到 assemble*/bundle* 打包任务。")

    configured_build_types = read_build_types_from_files(module_dir)
    build_types = infer_build_types(task_names, configured_build_types)
    variant_tasks = build_variant_tasks(task_names, build_types)
    if not variant_tasks:
        raise SystemExit("ERROR: 没有识别到可用 variant。")

    if args.list:
        print_available(variant_tasks, build_types)
        return 0

    selected = select_task(args, variant_tasks, build_types)
    gradle_task = f"{module}:{selected.task_name}" if module else selected.task_name
    print(f"Selected: {format_variant_line(selected)}")
    print(f"Gradle task: {gradle_task}")

    if args.dry_run:
        print("Dry run enabled; build skipped.")
        return 0

    command = [gradlew, gradle_task, "--no-daemon", *gradle_args]
    print(f"Running: {' '.join(command)}")
    start_time = time.time()
    result = subprocess.run(
        command,
        cwd=str(root),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        print("Build failed. Full Gradle output:")
        print_command_output(result.stdout)
        return result.returncode

    outputs = find_recent_outputs(module_dir, selected.artifact, start_time)
    if outputs:
        print("Final artifact path(s):")
        for path in outputs:
            print(path.resolve())
    else:
        print("Build succeeded, but no recent artifact path was detected under build/outputs.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("\nCanceled.", file=sys.stderr)
        raise SystemExit(130)
