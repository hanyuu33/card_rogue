# -*- coding: utf-8 -*-
"""R752 i18n：工具译文三语（7009 万能牌 / 7010 快送鸭 / 7011 神秘牌）
并把 7005~7008 的「轻点即用」改成「轻点两下」（交互改成两段式确认）。"""
import io
import json

ROOT = "e:/work/card_rogue/"

NEW = {
    "en": {
        "7009": {"name": "Wildcard", "desc": "Tap it twice to use it, no dragging needed. Choose a card from your draw pile; an ephemeral copy of it joins your hand with its cost reduced to 0 (the copy vanishes at the end of the turn). The tool is then used up."},
        "7010": {"name": "Express Duck", "desc": "Tap it twice to use it, no dragging needed. Fills your tool bar with random shop tools. The tool is then used up."},
        "7011": {"name": "Mystery Card", "desc": "Tap it twice to use it, no dragging needed. Choose one of 3 random cards to join your hand; its cost is 0 for this turn. The tool is then used up."},
    },
    "ja": {
        "7009": {"name": "ワイルドカード", "desc": "2回タップすると使用できる（ドラッグ不要）。自分の山札からカードを1枚選び、その幻影コピーを手札に加える（コピーはターン終了時に消滅し、コストは0になる）。使用後は消費される。"},
        "7010": {"name": "急便アヒル", "desc": "2回タップすると使用できる（ドラッグ不要）。ランダムなショップ用ツールでツールバーを満たす。使用後は消費される。"},
        "7011": {"name": "ミステリーカード", "desc": "2回タップすると使用できる（ドラッグ不要）。ランダムな3枚のカードから1枚を選んで手札に加える。このターンの間、そのコストは0になる。使用後は消費される。"},
    },
    "es": {
        "7009": {"name": "Comodín", "desc": "Tócala dos veces para usarla, sin arrastrarla a una casilla del campo de batalla. Elige una carta de tu pila de robo: una copia efímera suya se une a tu mano con su coste reducido a 0 (la copia desaparece al final del turno). Después, la herramienta se consume."},
        "7010": {"name": "Pato Exprés", "desc": "Tócala dos veces para usarla, sin arrastrarla a una casilla del campo de batalla. Llena tu barra de herramientas con herramientas aleatorias de tienda. Después, la herramienta se consume."},
        "7011": {"name": "Carta Misteriosa", "desc": "Tócala dos veces para usarla, sin arrastrarla a una casilla del campo de batalla. Elige una de 3 cartas aleatorias para que se una a tu mano; su coste es 0 durante este turno. Después, la herramienta se consume."},
    },
}

TAP_FIX = {
    "en": [("Tap it to use it, no dragging needed.", "Tap it twice to use it, no dragging needed.")],
    "ja": [
        ("タップするだけで使用できる（ドラッグ不要）", "2回タップすると使用できる（ドラッグ不要）"),
        ("タップするだけで使える（戦場のマスにドラッグする必要はない）",
         "2回タップすると使用できる（ドラッグ不要）"),
    ],
    "es": [("Tócala para usarla, sin arrastrarla", "Tócala dos veces para usarla, sin arrastrarla")],
}

for lang in ("en", "ja", "es"):
    path = ROOT + "i18n/traps_%s.json" % lang
    raw = io.open(path, "r", encoding="utf-8", newline="").read()
    assert "\r\n" not in raw, path + " 出现 CRLF"
    src = raw
    # ① 「点一下」→「点两下」
    for old, new in TAP_FIX[lang]:
        n = src.count(old)
        assert n >= 1, "%s: %r 没命中" % (path, old)
        src = src.replace(old, new)
        print(path, "sentence x", n)
    # ② 追加三条（插在 7008 条目之后，保持 1 空格缩进 / 原有排版）
    data = json.loads(src)["traps"]
    last = data["7008"]
    anchor = ('  "7008": {\n   "name": %s,\n   "desc": %s\n  }\n }\n}'
              % (json.dumps(last["name"], ensure_ascii=False),
                 json.dumps(last["desc"], ensure_ascii=False)))
    assert src.count(anchor) == 1, path + ": 7008 锚点不唯一"
    add = ""
    for tid in ("7009", "7010", "7011"):
        row = NEW[lang][tid]
        add += (',\n  "%s": {\n   "name": %s,\n   "desc": %s\n  }'
                % (tid, json.dumps(row["name"], ensure_ascii=False),
                   json.dumps(row["desc"], ensure_ascii=False)))
    src = src.replace(anchor, anchor[:-len("\n }\n}")] + add + "\n }\n}")
    io.open(path, "w", encoding="utf-8", newline="").write(src)
    after = json.loads(io.open(path, encoding="utf-8").read())["traps"]
    print(path, "->", len(after), "条", list(after)[-3:])
print("OK")
