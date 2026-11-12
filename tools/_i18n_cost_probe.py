# -*- coding: utf-8 -*-
"""i18n 成本探针（R608 前置，只读）：粗估三语本地化的待翻译文本量。

不做语法级解析 —— 只按双引号切分取「奇数段」近似字符串字面量，
对 GDScript 足够（本项目不用多行字符串拼接可见文案）。
"""
import glob
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
Q = chr(34)


def has_cjk(s: str) -> bool:
    for c in s:
        o = ord(c)
        if 0x4E00 <= o <= 0x9FFF or 0x3040 <= o <= 0x30FF:
            return True
    return False


def literal_segments(line: str):
    """按双引号切分，返回奇数索引段（近似字符串字面量）。"""
    parts = line.split(Q)
    return parts[1::2]


def scan_gd():
    total = 0
    per_file = {}
    lines_with = 0
    for p in glob.glob(os.path.join(ROOT, "scripts", "*.gd")):
        n = 0
        try:
            with open(p, encoding="utf-8") as f:
                for line in f:
                    hit = False
                    for seg in literal_segments(line):
                        if has_cjk(seg):
                            n += 1
                            hit = True
                    if hit:
                        lines_with += 1
        except UnicodeDecodeError:
            continue
        if n:
            per_file[os.path.basename(p)] = n
            total += n
    return total, per_file, lines_with


def count_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:  # noqa: BLE001
        return -1, str(e)

    def walk(o):
        if isinstance(o, str):
            return 1 if has_cjk(o) else 0
        if isinstance(o, dict):
            return sum(walk(v) for v in o.values())
        if isinstance(o, list):
            return sum(walk(v) for v in o)
        return 0

    return walk(data), ""


def main():
    total, per_file, lines_with = scan_gd()
    print("=== scripts/*.gd ===")
    print("含 CJK 的字符串字面量段:", total)
    print("含 CJK 的代码行:", lines_with)
    for k, v in sorted(per_file.items(), key=lambda x: -x[1])[:12]:
        print("   %-28s %d" % (k, v))

    print("=== 数据层 ===")
    for name in ("cards.json", "stories.json", "relics.json"):
        p = os.path.join(ROOT, name)
        if not os.path.exists(p):
            print("%-14s (缺)" % name)
            continue
        n, err = count_json(p)
        print("%-14s 中文串 %s %s" % (name, n, err))

    # 卡片字段粒度（逻辑枚举 vs 展示文本）
    p = os.path.join(ROOT, "cards.json")
    with open(p, encoding="utf-8") as f:
        d = json.load(f)
    cards = d if isinstance(d, list) else d.get("cards", [])
    fields = ["name", "kind", "class", "effect_text", "color"]
    print("=== cards.json 字段粒度（%d 张） ===" % len(cards))
    for fl in fields:
        n = sum(1 for c in cards if isinstance(c.get(fl), str) and c.get(fl).strip() and has_cjk(c.get(fl)))
        uniq = len({c.get(fl) for c in cards if isinstance(c.get(fl), str) and c.get(fl).strip() and has_cjk(c.get(fl))})
        print("   %-12s 非空 %3d  唯一值 %3d" % (fl, n, uniq))


if __name__ == "__main__":
    main()
