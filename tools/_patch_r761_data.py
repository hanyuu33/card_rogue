# -*- coding: utf-8 -*-
"""R761 补丁 2/9：数据真源 —— cards.json 两张吟游诗人卡 + relics.json 「诗」。

cards.json = CRLF（别的脚本按字节改也会保留），relics.json = LF。
"""
import io

CARDS = r"E:\work\card_rogue\cards.json"
RELICS = r"E:\work\card_rogue\relics.json"


def load(p):
    with io.open(p, "rb") as f:
        return f.read()


def save(p, b):
    with io.open(p, "wb") as f:
        f.write(b)


# ---------------------------------------------------------------- cards.json
b = load(CARDS)
NL = "\r\n"

NEW_CARDS = (
    '    },' + NL
    + '    {' + NL
    + '      "id": 9263,' + NL
    + '      "name": "杜鹃",' + NL
    + '      "kind": "盟友",' + NL
    + '      "cost": 3,' + NL
    + '      "power": 3,' + NL
    + '      "health": 8,' + NL
    + '      "attack_range": 1,' + NL
    + '      "move_speed": 1,' + NL
    + '      "rarity": 3,' + NL
    + '      "group": "player",' + NL
    + '      "class": "吟游诗人",' + NL
    + '      "traits": [],' + NL
    + '      "affixes": [],' + NL
    + '      "effect_text": "",' + NL
    + '      "target_mode": "none",' + NL
    + '      "color": "水风",' + NL
    + '      "image": ""' + NL
    + '    },' + NL
    + '    {' + NL
    + '      "id": 9264,' + NL
    + '      "name": "招募",' + NL
    + '      "kind": "技能",' + NL
    + '      "cost": 0,' + NL
    + '      "power": 0,' + NL
    + '      "health": 0,' + NL
    + '      "attack_range": 0,' + NL
    + '      "move_speed": 0,' + NL
    + '      "rarity": 3,' + NL
    + '      "group": "player",' + NL
    + '      "class": "吟游诗人",' + NL
    + '      "traits": [],' + NL
    + '      "affixes": [],' + NL
    + '      "effect_text": "从三个其他职业的盟友中选一张，加入手卡。",' + NL
    + '      "target_mode": "none",' + NL
    + '      "value": 1,' + NL
    + '      "color": "水风",' + NL
    + '      "image": ""' + NL
    + '    }' + NL
)

tail = '    }' + NL + '  ]' + NL + '}' + NL
o = tail.encode("utf-8")
if b'"id": 9263,' in b:
    print("cards.json 已含 9263 → 跳过")
else:
    assert b.count(o) == 1, "cards.json 尾部锚点命中 %d 次" % b.count(o)
    b = b.replace(o, NEW_CARDS.encode("utf-8") + ('  ]' + NL + '}' + NL).encode("utf-8"))
    save(CARDS, b)

# ---------------------------------------------------------------- relics.json
r = load(RELICS)
anchor = b'      "desc": "\xe6\xaf\x8f\xe6\xac\xa1\xe6\x88\x98\xe6\x96\x97\xe5\xbc\x80\xe5\xa7\x8b\xe6\x97\xb6\xef\xbc\x8c\xe4\xbb\x8e\xe6\x8a\xbd\xe7\x89\x8c\xe5\xba\x93\xe9\x9a\x8f\xe6\x9c\xba\xe6\x89\x93\xe5\x87\xba\xe4\xb8\x80\xe5\xbc\xa0\xe6\x95\x88\xe6\x9e\x9c\xe5\x8d\xa1'
assert r.count(anchor) == 1, "relics.json 6067 描述锚点命中 %d 次" % r.count(anchor)

# 直接按 6067 的整块结构定位：找它的 id 行，再找该对象结尾的 "    }"（后跟 "  ]"）
i = r.find(b'"id": 6067')
assert i > 0
j = r.find(b'\n    }\n', i)
assert j > 0
insert = (
    ',\n'
    '    {\n'
    '      "id": 6069,\n'
    '      "name": "\u8bd7",\n'
    '      "kind": "\u6218\u6597",\n'
    '      "source": "\u89d2\u8272",\n'
    '      "tier": "\u4e00\u822c",\n'
    '      "desc": "\u6bcf\u56de\u5408\u7b2c\u4e00\u6b21\u4f7f\u7528\u5176\u4ed6\u804c\u4e1a\u7684\u76df\u53cb\u65f6\uff0c'
    '\u56de\u590d 1 \u70b9\u8d39\u7528\u3002\u5176\u4ed6\u804c\u4e1a\u7684\u76df\u53cb +2 \u529b\u91cf\uff08\u6301\u7eed\u751f\u6548\uff0c'
    '\u4e0d\u53e0\u52a0\uff09\u3002"\n'
    '    }'
)
r = r[:j + len(b'\n    }')] + insert.encode("utf-8") + r[j + len(b'\n    }'):]
save(RELICS, r)

print("cards.json / relics.json OK")
