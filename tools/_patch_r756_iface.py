# -*- coding: utf-8 -*-
"""R756 interface i18n：加 LEVEL_METROLOGY_WORKS（四份）。"""
import io
import json

ROOT = "e:/work/card_rogue/i18n/"
SRC_LINE = 1424

PLAIN = {
    "en": "Metrology Works",
    "ja": "計量工房",
    "es": "Taller de metrología",
}

for lang, text in PLAIN.items():
    p = ROOT + "interface_%s.json" % lang
    s = io.open(p, "r", encoding="utf-8", newline="").read()
    crlf = "\r\n" in s
    if crlf:
        s = s.replace("\r\n", "\n")
    if "LEVEL_METROLOGY_WORKS" in s:
        print(p, "已存在，跳过")
        continue
    anchor = '      "LEVEL_LASER_LINE": '
    assert s.count(anchor) == 1, p + " 锚点不唯一"
    line = '      "LEVEL_METROLOGY_WORKS": %s,\n' % json.dumps(text, ensure_ascii=False)
    # 插在 LEVEL_LASER_LINE 那一行之前
    i = s.index(anchor)
    s = s[:i] + line + s[i:]
    data = json.loads(s)
    assert data["scopes"]["battle"]["LEVEL_METROLOGY_WORKS"] == text, p
    if crlf:
        s = s.replace("\n", "\r\n")
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print(p, "ok")

# zh_canonical：带 source 行号的块结构
p = ROOT + "interface_zh_canonical.json"
s = io.open(p, "r", encoding="utf-8", newline="").read()
assert "\r\n" not in s
if "LEVEL_METROLOGY_WORKS" in s:
    print(p, "已存在，跳过")
else:
    anchor = '      "LEVEL_LASER_LINE": {\n'
    assert s.count(anchor) == 1
    block = ('      "LEVEL_METROLOGY_WORKS": {\n'
             '        "source": "scripts/game_levels.gd:%d",\n'
             '        "zh": "计量工坊"\n'
             '      },\n' % SRC_LINE)
    i = s.index(anchor)
    s = s[:i] + block + s[i:]
    s = s.replace('"updated": "2026-11-14"', '"updated": "2026-11-15"', 1)
    data = json.loads(s)
    assert data["scopes"]["battle"]["LEVEL_METROLOGY_WORKS"]["zh"] == "计量工坊"
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print(p, "ok")

print("done")
