#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""顺手补齐 R794b 的术语欠账：难度 12「昂贵」及其备注。

`validate_glossary.py` 从 `run_state.gd` 的 DIFFICULTY_NAMES / DIFFICULTY_TEXTS 抽中文串
逐条比 glossary 的 key，R794b 加了第 13 档（index 12）却没补这里 —— 校验器一直是红的
（R799 记录过 difficulties 那条；difficulty_notes 这条同源）。补上即可，不改任何游戏逻辑。
"""
P = "i18n/glossary.json"
d = open(P, "rb").read().decode("utf-8")

# ① difficulties 末尾
old1 = ('    "上锁": {\n'
        '      "en": "Locked",\n'
        '      "ja": "施錠"\n'
        '    }\n'
        '  },\n'
        '  "difficulty_notes": {')
new1 = ('    "上锁": {\n'
        '      "en": "Locked",\n'
        '      "ja": "施錠"\n'
        '    },\n'
        '    "昂贵": {\n'
        '      "en": "Expensive",\n'
        '      "ja": "高価"\n'
        '    }\n'
        '  },\n'
        '  "difficulty_notes": {')

# ② difficulty_notes 末尾
old2 = ('      "ja": "第3層が施錠：3つのキーレリックを集めると解除"\n'
        '    }\n'
        '  },\n'
        '  "rooms": {')
new2 = ('      "ja": "第3層が施錠：3つのキーレリックを集めると解除"\n'
        '    },\n'
        '    "商店商品售价 +40%（信物除外）": {\n'
        '      "en": "Shop prices +40% (Key Relics excluded)",\n'
        '      "ja": "商店の商品価格 +40%（キーレリックは除く）"\n'
        '    }\n'
        '  },\n'
        '  "rooms": {')

for old, new in ((old1, new1), (old2, new2)):
    assert d.count(old) == 1, "count=%d" % d.count(old)
    d = d.replace(old, new)

open(P, "wb").write(d.encode("utf-8"))

import json
chk = json.load(open(P, encoding="utf-8"))
assert "昂贵" in chk["difficulties"], "difficulties 没写进去"
assert "商店商品售价 +40%（信物除外）" in chk["difficulty_notes"], "notes 没写进去"
b = open(P, "rb").read()
assert b.count(b"\r\n") == 0, "该文件应为纯 LF"
print("glossary ok: difficulties %d 条 / notes %d 条"
      % (len(chk["difficulties"]), len(chk["difficulty_notes"])))
