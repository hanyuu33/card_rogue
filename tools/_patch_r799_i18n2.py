# -*- coding: utf-8 -*-
"""R799 续：cards_en / cards_ja / cards_es 补 9272 / 9273（这三个文件末尾带换行）。"""
import json

EN = {"name": "Chain Slash",
      "effect_text": "Costs X; playing it consumes all of your Cost. Deal 7 damage to one target, repeated X times; if the target dies partway, the remaining strikes are lost. Can be used even with no Cost (X is 0 in that case)."}
EN_B = {"name": "Artillery Ready",
        "effect_text": "Costs X; playing it consumes all of your Cost. Add X copies of Charged Bombardment to your Draw Pile, and deal 3 damage to all enemies, repeated X times. Can be used even with no Cost (X is 0 in that case)."}
JA = {"name": "連斬",
      "effect_text": "コストX。使用時に全コストを消費する。1体の対象に7ダメージを与える。これをX回繰り返す。途中で対象が倒れた場合、残りの回数は失われる。コストがなくても使用できる（その場合Xは0）。"}
JA_B = {"name": "砲撃準備",
        "effect_text": "コストX。使用時に全コストを消費する。「チャージ砲撃」をX枚山札に加え、すべての敵に3ダメージを与える。これをX回繰り返す。コストがなくても使用できる（その場合Xは0）。"}
ES = {"name": "Tajo en cadena",
      "effect_text": "Cuesta X; al jugarlo consume todo el Coste. Inflige 7 de daño a un objetivo, repetido X veces; si el objetivo muere a mitad, los golpes restantes se pierden. Puede usarse incluso sin Coste (en ese caso, X es 0)."}
ES_B = {"name": "Artillería lista",
        "effect_text": "Cuesta X; al jugarlo consume todo el Coste. Añade X copias de Bombardeo Cargado a la pila de robo e inflige 3 de daño a todos los enemigos, repetido X veces. Puede usarse incluso sin Coste (en ese caso, X es 0)."}


def block(key, obj):
    return "\n".join(['  "%s": {' % key,
                      '   "name": %s,' % json.dumps(obj["name"], ensure_ascii=False),
                      '   "effect_text": %s' % json.dumps(obj["effect_text"], ensure_ascii=False),
                      '  }'])


def patch(path, pairs):
    text = open(path, "rb").read().decode("utf-8")
    trail = "\n" if text.endswith("\n") else ""
    body_text = text[:-1] if trail else text
    assert body_text.endswith("}"), path
    idx = body_text.rfind("\n }\n}")
    assert idx > 0, path
    head, tail = body_text[:idx], body_text[idx:]
    out = head + ",\n" + ",\n".join(block(k, o) for k, o in pairs) + tail + trail
    d = json.loads(out)
    for k, o in pairs:
        assert d["cards"][k]["name"] == o["name"], (path, k)
    old = d.get("count")
    if isinstance(old, int):
        out = out.replace('"count": %d,' % old, '"count": %d,' % (old + 2), 1)
        d = json.loads(out)
    open(path, "wb").write(out.encode("utf-8"))
    b = open(path, "rb").read()
    print("%-26s cards=%d count=%s CRLF=%d LFonly=%d" % (
        path, len(d["cards"]), d.get("count"), b.count(b"\r\n"),
        b.count(b"\n") - b.count(b"\r\n")))


patch("i18n/cards_en.json", [("9272", EN), ("9273", EN_B)])
patch("i18n/cards_ja.json", [("9272", JA), ("9273", JA_B)])
patch("i18n/cards_es.json", [("9272", ES), ("9273", ES_B)])
