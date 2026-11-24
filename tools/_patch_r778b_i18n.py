# -*- coding: utf-8 -*-
"""R778b：i18n 四语同步（文本级替换，保持文件格式与行尾）。

改动：
  * 构状体 → 构装体（9242 效果文本 + 9243~9245 卡名）
  * 灰烬龙 1013 效果清空
  * 量产型赫卡同克瑞斯 9133 效果换成「给随机一个其他友方单位 10 护甲」
  * 14 张敌人效果卡删「效果区多张本卡不可叠加」句
  * glossary traits 条目改名 + 新增「铸甲」
"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"

DROP = {
    "zh_canonical": "效果区多张本卡不可叠加。",
    "en": " Multiple copies of this card in the Effect Zone do not stack.",
    "ja": "効果ゾーンにこのカードが複数あっても重複しない。",
    "es": " Varias copias de esta carta en la zona de Efectos no se acumulan.",
}
ENEMY_EFFECT_IDS = ["9013", "9015", "9024", "9049", "9115", "9117", "9125",
                    "9139", "9147", "9178", "9209", "9210", "9212", "9240"]
NEW_9133 = {
    "zh_canonical": "每回合开始时，给随机一个其他友方单位 10 护甲。",
    "en": "At the start of each turn, give a random other friendly unit 10 Armor.",
    "ja": "毎ターン開始時、ランダムな他の味方ユニット1体に装甲10を与える。",
    "es": "Al comienzo de cada turno, otorga 10 de Armadura a otra unidad aliada aleatoria.",
}
SHAPE_NAMES = {
    "9243": {"zh_canonical": "炮击构装体", "en": "Artillery Construct",
             "ja": "砲撃構装体", "es": "Constructo de Artillería"},
    "9244": {"zh_canonical": "护盾构装体", "en": "Shield Construct",
             "ja": "シールド構装体", "es": "Constructo de Escudo"},
    "9245": {"zh_canonical": "迅捷构装体", "en": "Swift Construct",
             "ja": "迅速構装体", "es": "Constructo Veloz"},
}

FILES = {
    "zh_canonical": "i18n/zh_canonical.json",
    "en": "i18n/cards_en.json",
    "ja": "i18n/cards_ja.json",
    "es": "i18n/cards_es.json",
}


def enc(v):
    return json.dumps(v, ensure_ascii=False)


for lang, rel in FILES.items():
    path = ROOT + rel
    s = io.open(path, "r", encoding="utf-8", newline="").read()
    data = json.loads(s)
    cards = data.get("cards", data)

    def set_field(cid, field, newval, tag):
        global s
        old = cards[cid][field]
        if old == newval:
            print("SKIP %s %s %s (已是目标值)" % (lang, cid, field))
            return
        o, n = enc(old), enc(newval)
        if s.count(o) != 1:
            print("FAIL %s %s %s count=%d" % (lang, cid, field, s.count(o)))
            sys.exit(1)
        s = s.replace(o, n, 1)
        cards[cid][field] = newval
        print("OK %s %s %s" % (lang, cid, tag))

    # 1) 9242 构状体 → 构装体
    txt = cards["9242"]["effect_text"]
    if lang == "zh_canonical":
        new = txt.replace("构状体", "构装体")
    elif lang == "ja":
        new = txt.replace("構状体", "構装体")
    elif lang == "en":
        new = (txt.replace("Artillery Automaton", "Artillery Construct")
                  .replace("Shield Automaton", "Shield Construct")
                  .replace("Swift Automaton", "Swift Construct")
                  .replace("Summon an Automaton", "Summon a Construct")
                  .replace("the current Automaton", "the current Construct"))
    else:
        new = (txt.replace("Autómata de Artillería", "Constructo de Artillería")
                  .replace("Autómata de Escudo", "Constructo de Escudo")
                  .replace("Autómata Veloz", "Constructo Veloz")
                  .replace("invocar un Autómata", "invocar un Constructo")
                  .replace("el Autómata actual", "el Constructo actual"))
    if new.count("构状体") or new.count("構状体") or new.count("Automaton") or new.count("Autómata"):
        print("FAIL %s 9242 仍有旧词" % lang)
        sys.exit(1)
    set_field("9242", "effect_text", new, "构装体")

    # 2) 形态卡改名
    for cid, names in SHAPE_NAMES.items():
        set_field(cid, "name", names[lang], "形态卡改名")

    # 3) 灰烬龙效果清空
    set_field("1013", "effect_text", "", "灰烬龙清空效果")

    # 4) 9133 新效果
    set_field("9133", "effect_text", NEW_9133[lang], "9133 铸甲")

    # 5) 删除不可叠加句
    sent = DROP[lang]
    for cid in ENEMY_EFFECT_IDS:
        txt = cards[cid]["effect_text"]
        if sent not in txt:
            print("FAIL %s %s 不含目标句: %r" % (lang, cid, txt[-60:]))
            sys.exit(1)
        set_field(cid, "effect_text", txt.replace(sent, ""), "删叠加句")
    print("---- %s done ----" % lang)

    io.open(path, "w", encoding="utf-8", newline="\n").write(s)

print("ALL LANGS DONE")
