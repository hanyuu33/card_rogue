# -*- coding: utf-8 -*-
"""扫玩家可见但没走 GameI18n 取文口的裸中文字面量。

排除：注释、print/push_*/assert 等日志断言、GameI18n 调用行、test_* 文件。
输出按文件分组的命中清单，供逐条判定「要不要翻」。
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CJK = re.compile(r"[\u4e00-\u9fff]")
STR = re.compile(r'"([^"\\]*(?:\\.[^"\\]*)*)"')
SKIP = re.compile(r"\b(print|printerr|print_rich|push_warning|push_error|assert|prints)\s*\(")


def main():
    total = 0
    by_file = {}
    for gd in sorted((ROOT / "scripts").glob("*.gd")):
        if gd.name.startswith("test_"):
            continue
        hits = []
        for ln, line in enumerate(gd.read_text(encoding="utf-8").splitlines(), 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            if "GameI18n." in line or "L10n." in line:
                continue
            if SKIP.search(line):
                continue
            # 去掉行尾注释再判断
            code = line.split("#")[0]
            strs = [m.group(1) for m in STR.finditer(code)]
            zh = [x for x in strs if CJK.search(x)]
            if zh:
                hits.append((ln, zh, s[:110]))
        if hits:
            by_file[gd.name] = hits
            total += len(hits)
    print("裸中文命中行数合计:", total, " 涉及文件:", len(by_file))
    for name, hits in sorted(by_file.items(), key=lambda kv: -len(kv[1])):
        print("\n### %s (%d 行)" % (name, len(hits)))
        for ln, zh, src in hits[:14]:
            print("  %5d  %s" % (ln, " | ".join(x[:40] for x in zh)))
        if len(hits) > 14:
            print("   … 其余 %d 行" % (len(hits) - 14))


if __name__ == "__main__":
    main()
