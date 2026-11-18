# -*- coding: utf-8 -*-
"""R799：i18n 四语补 9272 连斩 / 9273 炮火就位。按原风格插行（不 json.dumps 整篇）。"""
import json

ZH = {
    "name": "连斩",
    "effect_text": "X 费，打出时消耗全部费用。对一个目标造成 7 点伤害，重复 X 次；目标中途倒下则剩余次数作废。没有费用时也能使用（此时 X 为 0）。",
}
ZH_B = {
    "name": "炮火就位",
    "effect_text": "X 费，打出时消耗全部费用。将 X 张「聚能炮击」加入抽牌库，对所有敌人造成 3 点伤害，重复 X 次。没有费用时也能使用（此时 X 为 0）。",
}
EN = {
    "name": "Chain Slash",
    "effect_text": "Costs X; playing it consumes all of your Cost. Deal 7 damage to one target, repeated X times; if the target dies partway, the remaining strikes are lost. Can be used even with no Cost (X is 0 in that case).",
}
EN_B = {
    "name": "Artillery Ready",
    "effect_text": "Costs X; playing it consumes all of your Cost. Add X copies of Charged Bombardment to your Draw Pile, and deal 3 damage to all enemies, repeated X times. Can be used even with no Cost (X is 0 in that case).",
}
JA = {
    "name": "連斬",
    "effect_text": "コストX。使用時に全コストを消費する。1体の対象に7ダメージを与える。これをX回繰り返す。途中で対象が倒れた場合、残りの回数は失われる。コストがなくても使用できる（その場合Xは0）。",
}
JA_B = {
    "name": "砲撃準備",
    "effect_text": "コストX。使用時に全コストを消費する。「チャージ砲撃」をX枚山札に加え、すべての敵に3ダメージを与える。これをX回繰り返す。コストがなくても使用できる（その場合Xは0）。",
}
ES = {
    "name": "Tajo en cadena",
    "effect_text": "Cuesta X; al jugarlo consume todo el Coste. Inflige 7 de daño a un objetivo, repetido X veces; si el objetivo muere a mitad, los golpes restantes se pierden. Puede usarse incluso sin Coste (en ese caso, X es 0).",
}
ES_B = {
    "name": "Artillería lista",
    "effect_text": "Cuesta X; al jugarlo consume todo el Coste. Añade X copias de Bombardeo Cargado a la pila de robo e inflige 3 de daño a todos los enemigos, repetido X veces. Puede usarse incluso sin Coste (en ese caso, X es 0).",
}


def block(key, obj, extra=""):
    lines = ['  "%s": {' % key,
             '   "name": %s,' % json.dumps(obj["name"], ensure_ascii=False),
             '   "effect_text": %s%s' % (json.dumps(obj["effect_text"], ensure_ascii=False), extra),
             '  }']
    return "\n".join(lines)


def patch(path, pairs, bump_count=True):
    text = open(path, "rb").read().decode("utf-8")
    assert text.endswith("}"), path
    idx = text.rfind("\n }\n}")
    assert idx > 0, path
    head, tail = text[:idx], text[idx:]
    body = ",\n".join(block(k, o, e) for k, o, e in pairs)
    out = head + ",\n" + body + tail
    d = json.loads(out)
    for k, o, _e in pairs:
        assert d["cards"][k]["name"] == o["name"], (path, k)
    if bump_count and isinstance(d.get("count"), int):
        old = d["count"]
        # 保留原有「差 1」的相对关系，只 +2（该字段无人读取，仅作版本标注）
        out = out.replace('"count": %d,' % old, '"count": %d,' % (old + 2), 1)
        d = json.loads(out)
        print("  count %d -> %d" % (old, d["count"]))
    open(path, "wb").write(out.encode("utf-8"))
    b = open(path, "rb").read()
    print("%-28s cards=%d CRLF=%d LFonly=%d" % (path, len(d["cards"]),
          b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))


patch("i18n/zh_canonical.json",
      [("9272", ZH, ',\n   "changed": false'), ("9273", ZH_B, ',\n   "changed": false')],
      bump_count=False)
patch("i18n/cards_en.json", [("9272", EN, ""), ("9273", EN_B, "")])
patch("i18n/cards_ja.json", [("9272", JA, ""), ("9273", JA_B, "")])
patch("i18n/cards_es.json", [("9272", ES, ""), ("9273", ES_B, "")])
