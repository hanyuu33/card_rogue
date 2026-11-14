# -*- coding: utf-8 -*-
"""R692 三语同步：删「次元」尾句与来源句；改 9063 / 9002 / 9022；新增 9250 / 9251。

用法：python tools/_patch_r692_i18n.py [--write]
"""
import json
import sys

ROOT = "E:/work/card_rogue/"
WRITE = "--write" in sys.argv

# ── ①② 统一删除的「次元」尾句（长串在前，短串在后）────────────────
STRIP = {
    "ja": [
        "キーワード「次元」：離場時に消滅し、捨て札置き場には入らない。",
        "キーワード「次元」：使用後に消滅し、捨て札置き場には入らない。",
        "次元：使用後に消滅し、捨て札置き場には入らず、この戦闘中は再び現れない。",
        "次元：使用後に消滅し、捨て札置き場には入らない。",
        "次元：離場時に消滅し、捨て札置き場には入らない。",
    ],
    "en": [
        ' Keyword "Dimensional": Banished on leaving the field; does not go to the Discard Pile.',
        ' Keyword "Dimensional": Banished after being played; does not go to the Discard Pile.',
        " Dimensional: Banished after being played; does not go to the Discard Pile"
        " and does not appear again this battle.",
        " Dimensional: Banished after being played; does not go to the Discard Pile.",
        " Dimensional: Banished on leaving the field; does not go to the Discard Pile.",
    ],
    "es": [
        " Palabra clave «dimensional»: se destierra al salir del campo; no va a la pila de descarte.",
        " Palabra clave «dimensional»: se destierra después de jugarla; no va a la pila de descarte.",
        " Dimensional: se destierra después de jugarla; no va a la pila de descarte"
        " y no vuelve a aparecer en esta batalla.",
        " Dimensional: se destierra al salir del campo; no va a la pila de descarte.",
        " Dimensional: se destierra después de jugarla; no va a la pila de descarte.",
    ],
}

# 破绽 9154：只留「本场对战不再出现」那半句
KEEP_TAIL = {
    "ja": ("次元：使用後に消滅し、捨て札置き場には入らず、この戦闘中は再び現れない。",
           "この戦闘中は再び現れない。"),
    "en": (" Dimensional: Banished after being played; does not go to the Discard Pile"
           " and does not appear again this battle.",
           " It does not appear again this battle."),
    "es": (" Dimensional: se destierra después de jugarla; no va a la pila de descarte"
           " y no vuelve a aparecer en esta batalla.",
           " No vuelve a aparecer en esta batalla."),
}

# ── ③ 来源句（由 XXX 召唤 / 烧出 / 孵出）────────────────────────────
SOURCE = {
    "ja": [
        "「ゴーレム召喚術」によって召喚される。",       # 9080
        "「アヒルの卵」から孵る。",                     # 9177
        "アヒル魔術師によって召喚される。",              # 9009
        "アヒル窯によって焼き上げられる。",              # 9026（保留后半句）
        "幼竜の死亡によって召喚される。",                # 9028
        "機械巨鴨によって召喚される。",                  # 9048
    ],
    "en": [
        'Summoned by "Golemancy". ',
        'Hatched from a "Duck Egg". ',
        "Summoned by Duck Wizard.",
        "Fired by Duck Kiln. ",
        "Summoned by the death of Young Dragon.",
        "Summoned by Mechanical Mega Duck.",
    ],
    "es": [
        "Invocado por «Golemancia». ",
        "Eclosiona de un «Huevo de Pato». ",
        "Invocado por Pato Hechicero.",
        "Horneado por el Horno de Patos. ",
        "Invocado por la muerte del Dragón Joven.",
        "Invocado por el Megapato Mecánico.",
    ],
}

# ── ④ 三张卡的正文改口径 ─────────────────────────────────────────
REWRITE = {
    "9063": {
        "ja": "効果カードを使用するたび、全ての敵に4ダメージを与える。これをX回繰り返す。"
              "このカード自体の使用では発動しない。Xは効果ゾーンにあるこのカードの枚数。",
        "en": "Whenever you use an Effect card, deal 4 damage to all enemies, repeated X times. "
              "Using this card itself does not trigger it. "
              "X is the number of copies of this card in the Effect Zone.",
        "es": "Cada vez que uses una carta de Efecto, inflige 4 de daño a todos los enemigos, "
              "repetido X veces. Usar esta carta no lo activa. "
              "X es el número de copias de esta carta en la zona de Efectos.",
    },
    "9002": {
        "ja": "使用時、「木霊」1枚を山札に加える。ターン開始時、ランダムな敵に8ダメージをX回与える。"
              "Xは効果ゾーンにあるこのカードの枚数。",
        "en": "When used, add a copy of it to your Draw Pile. At the start of your turn, "
              "deal 8 damage to a random enemy X times. "
              "X is the number of copies of this card in the Effect Zone.",
        "es": "Al usarse, añade una copia de «Eco Profundo» a la pila de robo. "
              "Al comienzo de tu turno, inflige 8 de daño a un enemigo aleatorio X veces. "
              "X es el número de copias de esta carta en la zona de Efectos.",
    },
    "9022": {
        "ja": "自分のターン開始時に生存していれば、攻撃力3・HP15のペットアヒルに変わり、"
              "あなたの代わりにHPダメージを受ける。",
        "en": "At the start of your turn, if it is still alive, it becomes a Pet Duck with "
              "3 Attack and 15 Health, taking Health damage in your place.",
        "es": "Al comienzo de tu turno, si sigue vivo, se convierte en un Pato Mascota con "
              "3 de Ataque y 15 de Vida, que recibe el daño de Vida en tu lugar.",
    },
}

# ── ⑤ 新增 9250 / 9251 ────────────────────────────────────────────
NEW = {
    "9250": {
        "ja": {"name": "アヒル母さん",
               "effect_text": "使用時、このカードの両隣にそれぞれ「子ガモ」1体を召喚する（可能な場合）。"},
        "en": {"name": "Mother Duck",
               "effect_text": 'When used, summon one "Duckling" on each side of this card '
                              "(if possible)."},
        "es": {"name": "Pata Madre",
               "effect_text": "Al usarse, invoca un «Patito» a cada lado de esta carta "
                              "(si es posible)."},
    },
    "9251": {
        "ja": {"name": "子ガモ",
               "effect_text": "登場時、手札の効果カード1枚をランダムに選び、コスト-1。"},
        "en": {"name": "Duckling",
               "effect_text": "When it enters, reduce the Cost of a random Effect card "
                              "in your Hand by 1."},
        "es": {"name": "Patito",
               "effect_text": "Al entrar, reduce en 1 el Coste de una carta de Efecto "
                              "aleatoria de tu mano."},
    },
}


def main() -> None:
    for lang in ("ja", "en", "es"):
        path = ROOT + "i18n/cards_%s.json" % lang
        raw = open(path, "rb").read()
        assert raw.count(b"\r\n") == 0, "%s 应为纯 LF" % path
        data = json.loads(raw.decode("utf-8"))
        cards = data["cards"]

        stripped = 0
        for cid, entry in cards.items():
            t = entry.get("effect_text", "")
            orig = t

            # 9154 这类「保留后半句」的先处理
            keep_old, keep_new = KEEP_TAIL[lang]
            if keep_old in t:
                t = t.replace(keep_old, keep_new)
                stripped += 1

            for s in STRIP[lang]:
                if s in t:
                    t = t.replace(s, "")
                    stripped += 1
            for s in SOURCE[lang]:
                if s in t:
                    t = t.replace(s, "")
                    stripped += 1

            t = t.replace("  ", " ").strip()
            entry["effect_text"] = t
            if t != orig:
                pass

        for cid, per_lang in REWRITE.items():
            cards[cid]["effect_text"] = per_lang[lang]

        for cid, per_lang in NEW.items():
            cards[cid] = {"name": per_lang[lang]["name"],
                          "effect_text": per_lang[lang]["effect_text"]}

        # 顺序：既有卡按 id 排，新卡追加在末尾会破坏可读性 → 整体按原顺序 + 新 id 插入排序
        data["cards"] = dict(sorted(cards.items(), key=lambda kv: int(kv[0])))
        data["count"] = len(data["cards"])

        out = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
        print("%s：卡 %d 张，改动 %d 处" % (lang, len(data["cards"]), stripped))
        if WRITE:
            open(path, "wb").write(out.encode("utf-8"))
            b = open(path, "rb").read()
            print("   CRLF %d / LF %d" % (b.count(b"\r\n"), b.count(b"\n")))

    if not WRITE:
        print("DRY-RUN")


main()
