# -*- coding: utf-8 -*-
"""R688：cards_ja / cards_en / cards_es 同步（X 表述 + 不可叠加 + 木霊改名）。LF 原样保留。"""
import json
import re
import sys

ROOT = "E:/work/card_rogue/i18n/"

# 追加型：zh 只多了「效果区多张本卡不可叠加。」
SUFFIX_ONLY = [9013, 9015, 9024, 9045, 9049, 9065, 9070, 9076, 9091, 9092, 9099,
               9101, 9110, 9111, 9112, 9113, 9114, 9115, 9117, 8045, 9147, 9125,
               9139, 8078, 9175, 9178, 9180, 9181, 9201, 9202, 9203, 9209, 9210,
               9211, 9212, 9226, 9240]

SUF = {
    "ja": "効果ゾーンにこのカードが複数あっても重複しない。",
    "en": "Multiple copies of this card in the Effect Zone do not stack.",
    "es": "Varias copias de esta carta en la zona de Efectos no se acumulan.",
}
OLD_SUF = {
    "ja": ["効果ゾーンにこのカードが複数あっても重複しない。", "効果ゾーンに複数あっても重複しない。"],
    "en": ["Multiple copies of this card in the Effect Zone do not stack.",
           "Multiple copies do not stack.", "Does not stack."],
    "es": ["Varias copias de esta carta en la zona de Efectos no se acumulan.",
           "Varias copias no se acumulan.", "No se acumula."],
}

XT = {
    "ja": "Xは効果ゾーンにあるこのカードの枚数。",
    "en": "X is the number of copies of this card in the Effect Zone.",
    "es": "X es el número de copias de esta carta en la zona de Efectos.",
}

# 手写：可叠加转 X / 新卡 / 措辞改写
HAND = {
    9002: {
        "ja": ("木霊", "使用時、このカードのコピー1枚を山札に加える。ターン開始時、"
                       "ランダムな敵に6ダメージをX回与える。Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Deep Echo", "When used, add a copy of this card to your Draw Pile. At the start of "
                            "your turn, deal 6 damage to a random enemy X times. X is the number of "
                            "copies of this card in the Effect Zone."),
        "es": ("Eco Profundo", "Al usarse, añade una copia de esta carta a la pila de robo. Al comienzo "
                               "de tu turno, inflige 6 de daño a un enemigo aleatorio X veces. X es el "
                               "número de copias de esta carta en la zona de Efectos."),
    },
    9036: {
        "ja": ("野獣の心", "自分の全ての味方ユニットが与えるダメージ+X。手札から味方ユニットを使用した時、"
                           "その味方ユニットはHP+2Xを得る。Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Heart of the Beast", "All your Allies deal +X damage; when you play an Ally from your "
                                     "Hand, that Ally gains +2X Health. X is the number of copies of this "
                                     "card in the Effect Zone."),
        "es": ("Corazón de Bestia", "Todos tus Aliados infligen +X de daño; cuando uses un Aliado desde la "
                                    "mano, ese Aliado obtiene +2X de Vida. X es el número de copias de esta "
                                    "carta en la zona de Efectos."),
    },
    9056: {
        "ja": ("鏡像", "毎ターン、最初のX回の効果カード使用時、そのコピー1枚を山札に加え、カードを1枚ドローする。"
                       "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Mirror Image", "For each of the first X Effect cards you use each turn, add a copy of it to "
                               "your Draw Pile and draw a card. X is the number of copies of this card in "
                               "the Effect Zone."),
        "es": ("Imagen Especular", "Por cada una de las primeras X cartas de Efecto que uses cada turno, "
                                   "añade una copia de esa carta a la pila de robo y roba una carta. X es el "
                                   "número de copias de esta carta en la zona de Efectos."),
    },
    9058: {
        "ja": ("秘術精通", "効果カードを使用した後、コストをX回復する。Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Arcane Mastery", "After using an Effect card, restore X Cost. X is the number of copies of "
                                 "this card in the Effect Zone."),
        "es": ("Dominio Arcano", "Después de usar una carta de Efecto, recupera X de Coste. X es el número de "
                                 "copias de esta carta en la zona de Efectos."),
    },
    9059: {
        "ja": ("知恵の噴出", "ターン開始時、カードをX枚ドローする。こうして引いた効果カードはコスト-1。"
                             "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Wisdom Surge", "At the start of your turn, draw X cards; Effect cards drawn this way cost -1. "
                               "X is the number of copies of this card in the Effect Zone."),
        "es": ("Torrente de Sabiduría", "Al comienzo de tu turno, roba X cartas; las cartas de Efecto robadas "
                                        "así cuestan -1. X es el número de copias de esta carta en la zona de "
                                        "Efectos."),
    },
    9061: {
        "ja": ("無尽の加護", "ターン開始時、ランダムな効果カードX枚を手札に加える。"
                             "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Endless Blessing", "At the start of your turn, add X random Effect cards to your Hand. "
                                   "X is the number of copies of this card in the Effect Zone."),
        "es": ("Bendición Infinita", "Al comienzo de tu turno, añade X cartas de Efecto aleatorias a la mano. "
                                     "X es el número de copias de esta carta en la zona de Efectos."),
    },
    9062: {
        "ja": ("使い魔の夜", "効果カードを1枚使用するたび、カラスX枚を手札に加える。それらはこのターン、コスト0。"
                             "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Night of Familiars", "Whenever you use an Effect card, add X Crows to your Hand; they cost 0 "
                                     "this turn. X is the number of copies of this card in the Effect Zone."),
        "es": ("Noche de Familiares", "Cada vez que uses una carta de Efecto, añade X Cuervos a la mano; cuestan "
                                      "0 este turno. X es el número de copias de esta carta en la zona de Efectos."),
    },
    9066: {
        "ja": ("石の皮膚", "自分のHPが次に受けるX回のダメージについて、2以上なら1にする。"
                           "Xは効果ゾーンにあるこのカードの枚数×2。"),
        "en": ("Stoneskin", "The next X instances of damage your HP takes become 1 if they would be 2 or more. "
                            "X is the number of copies of this card in the Effect Zone ×2."),
        "es": ("Piel de Piedra", "Las próximas X veces que tus HP reciban daño, si el daño sería de 2 o más, "
                                 "se convierte en 1. X es el número de copias de esta carta en la zona de "
                                 "Efectos ×2."),
    },
    9078: {
        "ja": ("受け継がれた記憶", "毎ターン、捨て札置き場に送られた最初のX体の味方ユニットはコスト-1で手札に戻る。"
                                   "フィールド上の味方ユニット1体につき、手札にあるこのカードのコスト-1。"
                                   "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Inherited Memory", "Each turn, the first X friendly Allies that die and are sent to the Discard "
                                   "Pile return to your Hand with Cost -1. For each friendly Ally on the field, "
                                   "this card's Cost is -1 while in your Hand. X is the number of copies of this "
                                   "card in the Effect Zone."),
        "es": ("Memoria Heredada", "Cada turno, los primeros X Aliados aliados que mueran y vayan a la pila de "
                                   "descarte vuelven a la mano con Coste -1. Por cada Aliado aliado en el campo, "
                                   "el Coste de esta carta es -1 mientras esté en la mano. X es el número de "
                                   "copias de esta carta en la zona de Efectos."),
    },
    8070: {
        "ja": ("創意", "ターン開始時、手札X枚を選び、**改造された時に追加効果を持つ**ランダムなカードへ変え、"
                       "改造を与える：HP+2。Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Ingenuity", "At the start of your turn, choose X cards in your Hand and transform them into random "
                            "cards **that have an extra effect when Upgraded**, then give them an Upgrade: +2 "
                            "Health. X is the number of copies of this card in the Effect Zone."),
        "es": ("Ingenio", "Al comienzo de tu turno, elige X cartas de la mano y transfórmalas en cartas aleatorias "
                          "**que tengan un efecto adicional al ser mejoradas**; luego otórgales una mejora: +2 de "
                          "Vida. X es el número de copias de esta carta en la zona de Efectos."),
    },
    8077: {
        "ja": ("点火", "自分のカードが改造されるたび、ランダムな敵**2**体に**3**ダメージを与える。これをX回繰り返す。"
                       "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Ignition", "Each time one of your cards is Upgraded, deal **3** damage to **2** random enemies, "
                           "repeated X times. X is the number of copies of this card in the Effect Zone."),
        "es": ("Ignición", "Cada vez que una de tus cartas recibe una mejora, inflige **3** de daño a **2** enemigos "
                           "aleatorios, repetido X veces. X es el número de copias de esta carta en la zona de "
                           "Efectos."),
    },
    8079: {
        "ja": ("驚きの運送票", "ターン開始時、山札のカードX枚を選び、ランダムなカードに変えて手札に加える。"
                               "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Surprise Waybill", "At the start of your turn, choose X cards in your Draw Pile, transform them into "
                                   "random cards and add them to your Hand. X is the number of copies of this card "
                                   "in the Effect Zone."),
        "es": ("Albarán Sorpresa", "Al comienzo de tu turno, elige X cartas de la pila de robo, transfórmalas en "
                                   "cartas aleatorias y añádelas a la mano. X es el número de copias de esta carta "
                                   "en la zona de Efectos."),
    },
    9148: {
        "ja": ("新生", "ターン開始時、手札X枚を選んで消滅させ、ランダムなカードX枚を手札に加える。"
                       "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Rebirth", "At the start of your turn, choose X cards in your Hand to Banish, then add X random cards "
                          "to your Hand. X is the number of copies of this card in the Effect Zone."),
        "es": ("Renacimiento", "Al comienzo de tu turno, elige X cartas de la mano para desterrarlas y luego añade X "
                               "cartas aleatorias a la mano. X es el número de copias de esta carta en la zona de "
                               "Efectos."),
    },
    9230: {
        "ja": ("恐怖の化身", "標記された敵にダメージを与えた時、このターン、その攻撃力-X。フィールドに標記がない場合、"
                             "ランダムな敵がいる位置を標記する。Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Dread Incarnate", "When dealing damage to a Marked enemy, give it -X Power this turn. If there is no "
                                  "Mark on the field, Mark the position of a random enemy. X is the number of "
                                  "copies of this card in the Effect Zone."),
        "es": ("Terror Encarnado", "Al infligir daño a un enemigo marcado, le otorga -X de Poder este turno. Si no "
                                   "hay ninguna Marca en el campo, marca la posición de un enemigo aleatorio. X es "
                                   "el número de copias de esta carta en la zona de Efectos."),
    },
    9231: {
        "ja": ("凶兆", "自分のターン終了時、標記されたマスにいる敵は4Xダメージを受ける。"
                       "Xは効果ゾーンにあるこのカードの枚数。"),
        "en": ("Ill Omen", "At the end of your turn, enemies on Marked tiles take 4X damage. X is the number of "
                           "copies of this card in the Effect Zone."),
        "es": ("Mal Augurio", "Al final de tu turno, los enemigos en casillas marcadas reciben 4X de daño. X es el "
                              "número de copias de esta carta en la zona de Efectos."),
    },
    9143: {
        "ja": ("発明家", "カードを1枚**変化**させるたび、コストを**2**回復する。変化：戦闘中にカードを別のカードへ"
                         "変えること。効果ゾーンにこのカードが複数あっても重複しない。"),
        "en": ("Invention Expert", "Whenever you **transform** a card, restore **2** Cost. Transform: turning one card "
                                   "into another during battle. Multiple copies of this card in the Effect Zone do "
                                   "not stack."),
        "es": ("Experto en Invención", "Cada vez que **transformes** una carta, recupera **2** de Coste. Transformar: "
                                       "convertir una carta en otra durante la batalla. Varias copias de esta carta "
                                       "en la zona de Efectos no se acumulan."),
    },
}


def blink(txt, cid):
    m = re.search(r'\n  "%d": \{' % cid, txt)
    if not m:
        return None
    start = txt.index("{", m.start())
    depth = 0
    i = start
    in_str = False
    esc = False
    while i < len(txt):
        ch = txt[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return start, i + 1
        i += 1
    return None


def set_card(raw, cid, name, text):
    a, b = blink(raw, cid)
    blk = raw[a:b]
    blk2 = re.sub(r'("name": ")((?:[^"\\]|\\.)*)(")',
                  lambda m: m.group(1) + json.dumps(name, ensure_ascii=False)[1:-1] + m.group(3), blk, count=1)
    blk2 = re.sub(r'("effect_text": ")((?:[^"\\]|\\.)*)(")',
                  lambda m: m.group(1) + json.dumps(text, ensure_ascii=False)[1:-1] + m.group(3), blk2, count=1)
    return raw[:a] + blk2 + raw[b:]


def main():
    write = "--write" in sys.argv
    for lang in ("ja", "en", "es"):
        p = ROOT + "cards_%s.json" % lang
        raw = open(p, "rb").read().decode("utf-8")
        assert raw.count("\r\n") == 0, p
        data = json.loads(raw)["cards"]
        touched = 0
        for cid in SUFFIX_ONLY:
            old = data[str(cid)]["effect_text"]
            t = old
            for s in OLD_SUF[lang]:
                if t.endswith(s):
                    t = t[: -len(s)].rstrip()
                    break
            sep = "" if lang == "ja" else " "
            new = t + sep + SUF[lang]
            if new != old:
                raw = set_card(raw, cid, data[str(cid)]["name"], new)
                touched += 1
        for cid, trans in HAND.items():
            name, text = trans[lang]
            raw = set_card(raw, cid, name, text)
            touched += 1
        d2 = json.loads(raw)
        print("%s：改 %d 张，卡数 %d，校验 9002=%s / 9056=%s"
              % (lang, touched, len(d2["cards"]), d2["cards"]["9002"]["name"], d2["cards"]["9056"]["name"]))
        if write:
            open(p, "wb").write(raw.encode("utf-8"))
    if not write:
        print("[dry-run] 未落盘")


if __name__ == "__main__":
    main()
