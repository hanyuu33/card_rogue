# -*- coding: utf-8 -*-
"""R794b：给 glossary.json 补两条（难度名「昂贵」+ 新增效果文本）。

为什么不跑 `build_glossary.py`：它开头先校验 `relics.json` 里的道具是否都登记过，
而并行线往工作区塞了兔脚 / 兵 / 刺墙 / 墙砖 / 工具箱 / 应急装甲 / 板甲 / 猴爪 / 诗 / 钻头
十件没译文的道具 → 校验直接 assert 挂掉，与本轮无关。所以这里只做**文本插入**，
格式与缩进保持原样（不动 JSON 其他部分）。
"""
import io, json

P = "E:/work/card_rogue/i18n/glossary.json"
s = io.open(P, "rb").read().decode("utf-8")

pairs = [
    (
        '    "上锁": {\n'
        '      "en": "Locked",\n'
        '      "ja": "施錠"\n'
        '    }\n'
        '  },\n'
        '  "difficulty_notes": {\n',
        '    "上锁": {\n'
        '      "en": "Locked",\n'
        '      "ja": "施錠"\n'
        '    },\n'
        '    "昂贵": {\n'
        '      "en": "Pricey",\n'
        '      "ja": "高値"\n'
        '    }\n'
        '  },\n'
        '  "difficulty_notes": {\n',
        "difficulties 昂贵",
    ),
    (
        '    "第三层上锁，获取三个信物以解锁第三层": {\n'
        '      "en": "Layer 3 Locked: collect three Key Relics to unlock it",\n'
        '      "ja": "第3層が施錠：3つのキーレリックを集めると解除"\n'
        '    }\n'
        '  },\n',
        '    "第三层上锁，获取三个信物以解锁第三层": {\n'
        '      "en": "Layer 3 Locked: collect three Key Relics to unlock it",\n'
        '      "ja": "第3層が施錠：3つのキーレリックを集めると解除"\n'
        '    },\n'
        '    "商店商品售价 +40%（信物除外）": {\n'
        '      "en": "Shop prices +40% (Key Relics excluded)",\n'
        '      "ja": "ショップ価格 +40%（キーレリックを除く）"\n'
        '    }\n'
        '  },\n',
        "difficulty_notes 新条目",
    ),
]

for old, new, tag in pairs:
    n = s.count(old)
    assert n == 1, "%s 命中 %d 次" % (tag, n)
    s = s.replace(old, new, 1)

io.open(P, "wb").write(s.encode("utf-8"))

# 复核：JSON 仍可解析，且两块都出现了新键
d = json.loads(io.open(P, encoding="utf-8").read())
assert d["difficulties"]["昂贵"]["en"] == "Pricey"
assert "商店商品售价 +40%（信物除外）" in d["difficulty_notes"]
print("ok：difficulties %d 条 / difficulty_notes %d 条" % (
    len(d["difficulties"]), len(d["difficulty_notes"])))
