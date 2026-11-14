# -*- coding: utf-8 -*-
"""R690 数据层补丁：水元素改抓漩涡 / 漩涡 0 费 / 生命循环 2 费。

用法：python tools/_patch_r690_data.py [--write]
"""
import sys

WRITE = "--write" in sys.argv

DL = "\r\n"


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    crlf = raw.count("\r\n")
    lf = raw.count("\n")
    assert crlf == lf or crlf == 0, "%s 行尾混杂（CRLF %d / LF %d）" % (path, crlf, lf)
    return raw, ("\r\n" if crlf else "\n")


def save(path, txt):
    open(path, "wb").write(txt.encode("utf-8"))
    b = open(path, "rb").read()
    print("  %s → CRLF %d / LF %d" % (path, b.count(b"\r\n"), b.count(b"\n")))


def rep(txt, old, new, tag, cnt=1):
    c = txt.count(old)
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    return txt.replace(old, new)


# ── cards.json ────────────────────────────────────────────────────────────
cards, eol = load("cards.json")
L = eol

OLD_9068 = L.join([
    "    {",
    '      "id": 9068,',
    '      "name": "水元素",',
    '      "kind": "盟友",',
    '      "cost": 6,',
    '      "power": 5,',
    '      "health": 15,',
    '      "attack_range": 1,',
    '      "move_speed": 1,',
    '      "rarity": 2,',
    '      "group": "player",',
    '      "class": "森林精魄",',
    '      "traits": [',
    '        "水元素"',
    "      ],",
    '      "effect_text": "自己场上每有一张效果卡，这张卡费用 -1。使用时，从卡组将一张效果卡加入手卡，费用减少 2。",',
    '      "target_mode": "none",',
    '      "value": 2,',
    '      "color": "白",',
    '      "image": "",',
    '      "upper_effect": {"trigger": "use", "effects": []},',
    '      "lower_effect": {"effects": [{"type": "add_effect_from_deck", "value": 1, "discount": 2}]}',
    "    }",
])

NEW_9068 = L.join([
    "    {",
    '      "id": 9068,',
    '      "name": "水元素",',
    '      "kind": "盟友",',
    '      "cost": 6,',
    '      "power": 5,',
    '      "health": 15,',
    '      "attack_range": 1,',
    '      "move_speed": 1,',
    '      "rarity": 2,',
    '      "group": "player",',
    '      "class": "森林精魄",',
    '      "traits": [',
    '        "水元素"',
    "      ],",
    '      "effect_text": "自己场上每有一张效果卡，这张卡费用 -1。使用时，将一张「漩涡」加入手卡。",',
    '      "target_mode": "none",',
    '      "value": 0,',
    '      "color": "白",',
    '      "image": "",',
    '      "upper_effect": {"trigger": "use", "effects": []},',
    '      "lower_effect": {"effects": [{"type": "add_card", "card_id": 9186, "value": 1}]}',
    "    }",
])

cards = rep(cards, OLD_9068, NEW_9068, "9068 块")

cards = rep(cards, L.join([
    '      "id": 9186,',
    '      "name": "漩涡",',
    '      "kind": "场地",',
    '      "cost": 3,',
]), L.join([
    '      "id": 9186,',
    '      "name": "漩涡",',
    '      "kind": "场地",',
    '      "cost": 0,',
]), "9186 费用")

cards = rep(cards, L.join([
    '      "id": 9150,',
    '      "name": "生命循环",',
    '      "kind": "效果",',
    '      "cost": 1,',
]), L.join([
    '      "id": 9150,',
    '      "name": "生命循环",',
    '      "kind": "效果",',
    '      "cost": 2,',
]), "9150 费用")

# ── i18n/zh_canonical.json ────────────────────────────────────────────────
canon, ceol = load("i18n/zh_canonical.json")
canon = rep(canon,
            '"effect_text": "自己场上每有一张效果卡，这张卡费用 -1。使用时，从抽牌库将一张效果卡加入手牌，费用减少 2。"',
            '"effect_text": "自己场上每有一张效果卡，这张卡费用 -1。使用时，将一张「漩涡」加入手卡。"',
            "canon 9068")

if WRITE:
    save("cards.json", cards)
    save("i18n/zh_canonical.json", canon)
    import json
    d = json.loads(cards)
    by = {c["id"]: c for c in d["cards"]}
    print("  校验 9068：", by[9068]["cost"], by[9068]["effect_text"], by[9068]["lower_effect"])
    print("  校验 9186 费：", by[9186]["cost"], " 9150 费：", by[9150]["cost"])
    print("  卡数：", len(d["cards"]))
else:
    print("干跑通过（未写入）")
