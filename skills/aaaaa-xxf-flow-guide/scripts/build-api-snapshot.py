#!/usr/bin/env python3
"""Extract public Kotlin function declarations from the two reference modules.

This is a source inventory, not a Kotlin compiler or ABI validator. Comments and
strings are masked before brace matching. Private/internal types, function bodies,
and protected/internal/private functions are excluded. Review semantic docs after
refreshing; --check detects drift without writing files.
"""
import argparse
import hashlib
import re
from pathlib import Path


def mask(text):
    pattern = r'"""[\s\S]*?"""|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|/\*[\s\S]*?\*/|//[^\n]*'
    return re.sub(pattern, lambda m: re.sub(r'[^\n]', ' ', m.group()), text)


def declarations(text):
    code = mask(text)
    depths = [0] * (len(code) + 1)
    pairs, stack = {}, []
    for i, char in enumerate(code):
        depths[i] = len(stack)
        if char == '{':
            stack.append(i)
        elif char == '}' and stack:
            pairs[stack.pop()] = i
    # Public types define the only non-top-level scopes we inventory.
    scopes = []
    type_pattern = r'(?m)^\s*(?:(?:public|private|internal|protected|abstract|open|data|sealed|enum|annotation|fun|value)\s+)*(?:class|interface|object)\s+(\w+)|(?m:^[ \t]*(?:private\s+)?companion\s+object(?:\s+(\w+))?)'
    for match in re.finditer(type_pattern, code):
        start = match.start()
        header_end = code.find('{', match.end())
        if header_end < 0:
            continue
        between = code[match.end():header_end]
        # A bodyless declaration must not claim the next declaration's body.
        if re.search(r'\n\s*(?:@|(?:fun|class|object|interface|private|internal|public)\b)', between):
            continue
        if header_end not in pairs:
            continue
        header = code[start:match.end()]
        visible = not re.search(r'\b(private|internal|protected)\b', header)
        scopes.append((header_end, pairs[header_end], match.group(1) or match.group(2) or 'Companion', visible))
    pattern = r'(?m)^[ \t]*(?:(?:public|private|internal|protected|inline|infix|operator|tailrec|suspend|override|final|abstract|open|external)\s+)*fun\s+(?!interface\b)'
    results = []
    for match in re.finditer(pattern, code):
        start = match.start()
        if re.search(r'\b(private|internal|protected)\b', match.group()):
            continue
        enclosing = [s for s in scopes if s[0] < start < s[1]]
        if any(not s[3] for s in enclosing):
            continue
        expected_depth = depths[max((s[0] for s in enclosing), default=0)] + (1 if enclosing else 0)
        if depths[start] != expected_depth:
            continue
        pos, parens, brackets = match.end(), 0, 0
        while pos < len(code):
            char = code[pos]
            if char == '(':
                parens += 1
            elif char == ')':
                parens -= 1
            elif char == '[':
                brackets += 1
            elif char == ']':
                brackets -= 1
            if parens == 0 and brackets == 0 and char in '{=\n':
                # Newline immediately after `fun` is not used in reference sources.
                break
            pos += 1
        signature = text[start:pos].strip()
        owner = '.'.join(s[2] for s in enclosing) or 'top-level'
        line = text.count('\n', 0, start) + 1
        results.append((owner, line, signature))
    return results


def render(roots):
    output = ['# 公开函数完整签名快照', '',
              '由 `scripts/build-api-snapshot.py` 从本地源码提取；保留 Kotlin 显式重载、receiver、泛型、参数名、默认值与 suspend 标记。',
              '不展开 `@JvmOverloads` 合成的 Java 重载；省略表达式函数的推断返回类型、实现体、构造器和属性。属性/类型协议见 [API 目录](api-catalog.md)。',
              '这是检索索引，不是语义教程；按文件查精确签名后，回到 [操作符选型与语义](operator-reference.md) 和 [场景手册](scenario-playbook.md)。', '',
              '范围：两个模块全部生产 `.kt` 文件中的公开顶层函数与公开类型成员函数；跳过 `internal/` 实现目录和不可见类型。',
              '源码行号只用于定位此快照；源码变动后应重建。SHA-256 覆盖各模块全部生产 Kotlin 文件的相对路径与内容。', '']
    total = 0
    for label, root in roots:
        digest = hashlib.sha256()
        files = sorted(root.rglob('*.kt'))
        for path in files:
            digest.update(str(path.relative_to(root)).encode())
            digest.update(path.read_bytes())
        output += [f'## {label}', '', f'生产 Kotlin 文件：{len(files)}；源码摘要：`{digest.hexdigest()}`。', '']
        for path in files:
            if 'internal' in path.relative_to(root).parts:
                continue
            content = path.read_text()
            items = declarations(content)
            if not items:
                continue
            package = re.search(r'^package (.+)$', content, re.M).group(1)
            output += [f'### {path.name}', '', f'路径：`{path.relative_to(root)}`；包：`{package}`。', '']
            for owner, line, signature in items:
                output += [f'`{owner}` · L{line}', '', '```kotlin', signature, '```', '']
                total += 1
    output.insert(9, f'共提取 **{total}** 个公开函数声明（按源码中的显式重载计数）。\n')
    return '\n'.join(output) + '\n', total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--core', required=True, type=Path, help='reactive-coroutines module root')
    parser.add_argument('--android', required=True, type=Path, help='reactive-coroutines-android module root')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'references/api-signatures.md')
    args = parser.parse_args()
    roots = [('KPower reactive-coroutines', args.core / 'src/jvmMain/kotlin'),
             ('xxf_android reactive-coroutines-android', args.android / 'src/main/java')]
    for _, root in roots:
        if not root.is_dir():
            parser.error(f'Source directory missing: {root}')
    content, count = render(roots)
    if args.check:
        if not args.output.exists() or args.output.read_text() != content:
            raise SystemExit('API snapshot drift; regenerate and review operator semantics.')
    else:
        args.output.write_text(content)
    print(f'{count} public declarations; snapshot {"verified" if args.check else "written"}.')


if __name__ == '__main__':
    main()
