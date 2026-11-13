# -*- coding: utf-8 -*-
"""Safely bind canonical interface strings to GameI18n.ui.

Dry-run is the default. Only literals that match the canonical Chinese text at
its recorded source line are changed; ambiguous or canonical-overridden source
mismatches are reported as manual work.
"""
from __future__ import annotations

import argparse
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = ROOT / "i18n" / "interface_zh_canonical.json"
SOURCE_RE = re.compile(r"(.+):(\d+)(?:-(\d+))?")
CALL_RE = re.compile(r"\bGameI18n\s*\.\s*ui\s*\(")


@dataclass(frozen=True)
class Entry:
    index: int
    scope: str
    key: str
    source: str
    zh: str
    relative_path: str
    first_line: int
    last_line: int
    overridden: bool
    source_parts: tuple[str, ...]

    @property
    def qualified_key(self) -> str:
        return f"{self.scope}.{self.key}"


@dataclass(frozen=True)
class Literal:
    start: int
    end: int
    raw: str
    value: str | None


@dataclass(frozen=True)
class WiredCall:
    start: int
    scope: str
    key: str
    third_start: int | None
    literal_starts: tuple[int, ...]


@dataclass
class SourceFile:
    path: Path
    original_bytes: bytes
    text: str
    newline_style: str
    line_starts: list[int]
    literals: list[Literal]
    wired_calls: list[WiredCall]

    def region(self, entry: Entry) -> tuple[int, int]:
        start = self.line_starts[entry.first_line - 1]
        if entry.last_line < len(self.line_starts):
            end = self.line_starts[entry.last_line]
        else:
            end = len(self.text)
        return start, end

    def position(self, offset: int) -> str:
        line = 1
        for index, line_start in enumerate(self.line_starts):
            if line_start > offset:
                break
            line = index + 1
        column = offset - self.line_starts[line - 1] + 1
        return f"{line}:{column}"


@dataclass
class Result:
    entry: Entry
    status: str
    reason: str
    literal: Literal | None = None


@dataclass
class FilePlan:
    source: SourceFile
    results: list[Result] = field(default_factory=list)
    updated_bytes: bytes | None = None


def newline_style(data: bytes) -> str:
    crlf = data.count(b"\r\n")
    lf = data.count(b"\n") - crlf
    cr = len(re.findall(rb"\r(?!\n)", data))
    styles = []
    if crlf:
        styles.append("CRLF")
    if lf:
        styles.append("LF")
    if cr:
        styles.append("CR")
    return "+".join(styles) if styles else "none"


def decode_literal(raw: str) -> str | None:
    """Decode normal GDScript double-quoted escapes without altering raw text."""
    try:
        value = json.loads(raw)
        return value if isinstance(value, str) else None
    except (json.JSONDecodeError, UnicodeDecodeError):
        pass

    inner = raw[1:-1]
    output = []
    escapes = {
        "a": "\a", "b": "\b", "t": "\t", "n": "\n", "v": "\v",
        "f": "\f", "r": "\r", "e": "\x1b", '"': '"', "'": "'",
        "\\": "\\", "/": "/",
    }
    index = 0
    while index < len(inner):
        char = inner[index]
        if char != "\\":
            output.append(char)
            index += 1
            continue
        index += 1
        if index >= len(inner):
            return None
        escape = inner[index]
        index += 1
        if escape in escapes:
            output.append(escapes[escape])
            continue
        if escape in ("u", "U"):
            digits = 4 if escape == "u" else 8
            code = inner[index:index + digits]
            if len(code) != digits or not re.fullmatch(r"[0-9A-Fa-f]+", code):
                return None
            output.append(chr(int(code, 16)))
            index += digits
            continue
        return None
    value = "".join(output)
    try:
        value.encode("utf-8")
    except UnicodeEncodeError:
        return None
    return value


def scan_source(text: str) -> tuple[list[Literal], list[WiredCall]]:
    """Return normal double-quoted literals and typed GameI18n.ui calls.

    Comments, single-quoted strings, raw strings and triple-quoted strings are
    masked for call detection. Only normal, non-raw double-quoted literals are
    replacement candidates.
    """
    mask = list(text)
    literals: list[Literal] = []
    length = len(text)

    def blank(start: int, end: int) -> None:
        for position in range(start, end):
            if text[position] not in "\r\n":
                mask[position] = " "

    index = 0
    while index < length:
        char = text[index]
        if char == "#":
            start = index
            while index < length and text[index] not in "\r\n":
                index += 1
            blank(start, index)
            continue
        if char not in ('"', "'"):
            index += 1
            continue

        quote = char
        start = index
        if quote == '"' and text.startswith('"""', index):
            index += 3
            while index < length:
                if text.startswith('"""', index):
                    index += 3
                    break
                if text[index] == "\\" and index + 1 < length:
                    index += 2
                else:
                    index += 1
            blank(start, index)
            continue

        index += 1
        closed = False
        while index < length:
            char = text[index]
            if char == "\\":
                if index + 1 < length:
                    index += 2
                else:
                    index += 1
                continue
            if char == quote:
                index += 1
                closed = True
                break
            if char in "\r\n":
                break
            index += 1
        blank(start, index)
        if not closed or quote != '"':
            continue

        raw_prefix = (
            start > 0 and text[start - 1] in "rR"
            and (start == 1 or not (text[start - 2].isalnum() or text[start - 2] == "_"))
        )
        if raw_prefix:
            continue
        raw = text[start:index]
        literals.append(Literal(start, index, raw, decode_literal(raw)))

    code = "".join(mask)
    by_start = {literal.start: literal for literal in literals}

    def skip_space(position: int) -> int:
        while position < length and text[position].isspace():
            position += 1
        return position

    wired_calls = []
    for match in CALL_RE.finditer(code):
        literal_starts = []
        position = skip_space(match.end())
        scope_literal = by_start.get(position)
        if scope_literal is None:
            continue
        literal_starts.append(scope_literal.start)
        position = skip_space(scope_literal.end)
        if position >= length or text[position] != ",":
            continue
        position = skip_space(position + 1)
        key_literal = by_start.get(position)
        if key_literal is None:
            continue
        literal_starts.append(key_literal.start)
        position = skip_space(key_literal.end)
        third_start = None
        if position < length and text[position] == ",":
            position = skip_space(position + 1)
            third_literal = by_start.get(position)
            if third_literal is not None:
                third_start = third_literal.start
                literal_starts.append(third_literal.start)
        wired_calls.append(WiredCall(
            match.start(), scope_literal.value or "", key_literal.value or "",
            third_start, tuple(literal_starts),
        ))
    return literals, wired_calls


def parse_entries(data: dict) -> tuple[list[Entry], list[Result]]:
    entries = []
    failures = []
    overrides = data.get("canonical_overrides", {})
    index = 0
    for scope, items in data["scopes"].items():
        for key, item in items.items():
            source = str(item.get("source", ""))
            zh = item.get("zh")
            match = SOURCE_RE.fullmatch(source)
            if match is None or not isinstance(zh, str):
                failures.append(Result(
                    Entry(index, scope, key, source, zh if isinstance(zh, str) else "",
                          "", 0, 0, f"{scope}.{key}" in overrides, ()),
                    "manual", "invalid source location or non-string zh",
                ))
                index += 1
                continue
            relative_path = match.group(1).replace("\\", "/")
            first_line = int(match.group(2))
            last_line = int(match.group(3) or first_line)
            if first_line < 1 or last_line < first_line:
                failures.append(Result(
                    Entry(index, scope, key, source, zh, relative_path,
                          first_line, last_line, f"{scope}.{key}" in overrides, ()),
                    "manual", "invalid source line range",
                ))
            else:
                entries.append(Entry(
                    index, scope, key, source, zh, relative_path, first_line, last_line,
                    f"{scope}.{key}" in overrides, tuple(item.get("source_parts", ())),
                ))
            index += 1
    return entries, failures


def load_source(relative_path: str) -> SourceFile:
    path = (ROOT / relative_path).resolve()
    try:
        path.relative_to(ROOT)
    except ValueError as error:
        raise ValueError("source path escapes project root") from error
    original = path.read_bytes()
    text = original.decode("utf-8")
    line_starts = [0]
    line_starts.extend(match.end() for match in re.finditer("\n", text))
    literals, wired_calls = scan_source(text)
    return SourceFile(
        path, original, text, newline_style(original), line_starts, literals, wired_calls,
    )


def constant_literal_starts(source: SourceFile) -> set[int]:
    """Conservatively protect every literal inside a const initializer.

    GDScript const tables cannot contain GameI18n.ui runtime calls. Bracket
    balancing is done on code with strings/comments masked, so multiline const
    dictionaries and arrays are covered without guessing from indentation.
    """
    chars = list(source.text)

    def blank(start: int, end: int) -> None:
        for position in range(start, end):
            if chars[position] not in "\r\n":
                chars[position] = " "

    for literal in source.literals:
        blank(literal.start, literal.end)
    for match in re.finditer(r'""".*?(?:"""|\Z)', source.text, re.S):
        blank(match.start(), match.end())
    for match in re.finditer(r"#(?:[^\r\n]*)", source.text):
        blank(match.start(), match.end())
    code = "".join(chars)

    ranges: list[tuple[int, int]] = []
    for match in re.finditer(r"(?m)^[\t ]*const\b", code):
        start = match.start()
        line_end_match = re.search(r"\n", code[start:])
        line_end = start + line_end_match.start() if line_end_match else len(code)
        depth = 0
        end = line_end
        position = start
        while position < len(code):
            char = code[position]
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth = max(0, depth - 1)
            if char == "\n":
                stripped = code[start:position].rstrip()
                if depth <= 0 and not stripped.endswith("\\"):
                    end = position
                    break
            position += 1
        else:
            end = len(code)
        ranges.append((start, end))
    return {
        literal.start
        for literal in source.literals
        if any(start <= literal.start <= end for start, end in ranges)
    }


def plan_file(relative_path: str, entries: list[Entry]) -> FilePlan | list[Result]:
    if relative_path == "scripts/l10n.gd":
        return [Result(entry, "manual",
                       "l10n.gd uses GameI18n.skeleton; const TEXT must stay constant")
                for entry in entries]
    try:
        source = load_source(relative_path)
    except (OSError, UnicodeError, ValueError) as error:
        return [Result(entry, "manual", f"cannot read source safely: {error}")
                for entry in entries]

    plan = FilePlan(source)
    const_literals = constant_literal_starts(source)
    protected_literals = {
        literal_start
        for call in source.wired_calls
        for literal_start in call.literal_starts
    }
    for entry in entries:
        if entry.last_line >= len(source.line_starts) + 1:
            plan.results.append(Result(entry, "manual", "source line range is beyond end of file"))
            continue
        region_start, region_end = source.region(entry)
        exact_calls = [
            call for call in source.wired_calls
            if call.scope == entry.scope and call.key == entry.key
            and (region_start <= call.start < region_end
                 or (call.third_start is not None
                     and region_start <= call.third_start < region_end))
        ]
        if len(exact_calls) == 1:
            plan.results.append(Result(
                entry, "already", "exact GameI18n.ui call already present at source location",
            ))
            continue
        if len(exact_calls) > 1:
            plan.results.append(Result(
                entry, "manual", "multiple exact GameI18n.ui calls found; refusing to choose",
            ))
            continue
        if entry.source_parts:
            plan.results.append(Result(
                entry, "manual", "source_parts marks a split/composite expression; manual binding required",
            ))
            continue

        all_matches = [
            literal for literal in source.literals
            if region_start <= literal.start and literal.end <= region_end
            and literal.value == entry.zh
        ]
        matches = [literal for literal in all_matches
                   if literal.start not in protected_literals
                   and literal.start not in const_literals]
        if len(matches) == 1:
            literal = matches[0]
            plan.results.append(Result(
                entry, "applied", f"unique literal at {source.position(literal.start)}; fallback preserved",
                literal,
            ))
        elif len(matches) > 1:
            plan.results.append(Result(
                entry, "manual", f"{len(matches)} identical literals in source range; refusing to choose",
            ))
        elif any(literal.start in const_literals for literal in all_matches):
            plan.results.append(Result(
                entry, "manual", "literal is inside a const initializer; translate at its runtime accessor",
            ))
        elif all_matches:
            plan.results.append(Result(
                entry, "manual", "matching literal belongs to another GameI18n.ui call",
            ))
        elif entry.overridden:
            plan.results.append(Result(
                entry, "manual", "canonical override does not exactly match source; manual source update required",
            ))
        else:
            plan.results.append(Result(
                entry, "manual", "no non-comment double-quoted literal exactly matches zh at source location",
            ))

    claims = defaultdict(list)
    for result in plan.results:
        if result.status == "applied" and result.literal is not None:
            claims[(result.literal.start, result.literal.end)].append(result)
    for claimed in claims.values():
        if len(claimed) > 1:
            for result in claimed:
                result.status = "manual"
                result.reason = "multiple keys claim the same literal; refusing to choose"
                result.literal = None

    replacements = [result for result in plan.results
                    if result.status == "applied" and result.literal is not None]
    updated = source.text
    for result in sorted(replacements, key=lambda item: item.literal.start, reverse=True):
        literal = result.literal
        assert literal is not None
        entry = result.entry
        wrapper = (
            f"GameI18n.ui({json.dumps(entry.scope, ensure_ascii=False)}, "
            f"{json.dumps(entry.key, ensure_ascii=False)}, {literal.raw})"
        )
        updated = updated[:literal.start] + wrapper + updated[literal.end:]
    if replacements:
        plan.updated_bytes = updated.encode("utf-8")
    return plan


def write_if_unchanged(plan: FilePlan) -> None:
    """Re-read in the write handle so a parallel edit aborts this whole file."""
    assert plan.updated_bytes is not None
    with plan.source.path.open("r+b") as handle:
        current = handle.read()
        if current != plan.source.original_bytes:
            raise RuntimeError("source bytes changed since dry-run/read; file left untouched")
        handle.seek(0)
        handle.write(plan.updated_bytes)
        handle.truncate()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--apply", action="store_true", help="write only uniquely located replacements")
    mode.add_argument("--dry-run", action="store_true", help="report only (default)")
    args = parser.parse_args()

    data = json.loads(CANONICAL.read_text(encoding="utf-8"))
    entries, results = parse_entries(data)
    grouped = defaultdict(list)
    for entry in entries:
        grouped[entry.relative_path].append(entry)

    plans = []
    for relative_path, file_entries in grouped.items():
        planned = plan_file(relative_path, file_entries)
        if isinstance(planned, list):
            results.extend(planned)
        else:
            plans.append(planned)
            results.extend(planned.results)

    if args.apply:
        for plan in plans:
            if plan.updated_bytes is None:
                continue
            pending = [result for result in plan.results if result.status == "applied"]
            try:
                write_if_unchanged(plan)
            except (OSError, RuntimeError) as error:
                for result in pending:
                    result.status = "manual"
                    result.reason = f"not written: {error}"
            else:
                for result in pending:
                    result.reason = "written after full-file byte recheck; " + result.reason
                print(f"WRITE {plan.source.path.relative_to(ROOT).as_posix()} "
                      f"bytes={len(plan.source.original_bytes)}->{len(plan.updated_bytes)} "
                      f"newline={plan.source.newline_style}")
    else:
        for result in results:
            if result.status == "applied":
                result.reason = "dry-run: would wrap " + result.reason

    results.sort(key=lambda result: result.entry.index)
    for result in results:
        print(f"[{result.status}] {result.entry.qualified_key} {result.entry.source} — "
              f"{result.reason}")
    counts = Counter(result.status for result in results)
    mode_name = "apply" if args.apply else "dry-run"
    print(f"SUMMARY mode={mode_name} applied={counts['applied']} "
          f"already={counts['already']} manual={counts['manual']} total={len(results)}")
    if not args.apply:
        print("DRY-RUN only: no source files were written; 'applied' counts unique candidates.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
