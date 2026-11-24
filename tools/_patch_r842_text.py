# -*- coding: utf-8 -*-
"""R842 补丁 ③ 文案与登记表：relics.json / noncard 四语 / glossary / demo_scope。

全部是 LF 文件；逐条 exact-replace + assert count==1。
"""
import io

ROOT = "E:/work/card_rogue/"

NAME = "稀有价值"
DESC_ZH = ("获得时：卡组里同名卡最多保留 3 张，多出来的随机删除，直到每个名字只剩 3 张为止；"
           "每因此效果删除一张卡，失去 5 点生命。")
DESC_EN = ("On pickup: your deck keeps at most 3 copies of each name; the extras are removed at "
           "random until only 3 remain, and you lose 5 Health for each card removed this way.")
DESC_JA = ("獲得時：デッキ内の同名カードは3枚までとなり、超えた分はランダムに削除されて3枚だけが残る。"
           "この効果で削除された1枚ごとに体力を5失う。")
DESC_ES = ("Al recoger: tu mazo conserva como máximo 3 copias de cada nombre; las sobrantes se "
           "retiran al azar hasta dejar solo 3, y pierdes 5 de vida por cada carta retirada por "
           "este efecto.")


def read(p):
    with io.open(ROOT + p, "rb") as f:
        return f.read().decode("utf-8")


def write(p, s):
    with io.open(ROOT + p, "wb") as f:
        f.write(s.encode("utf-8"))


def patch(p, pairs):
    s = read(p)
    nl = "\r\n" if s.count("\r\n") > 0 else "\n"
    for i, (old, new) in enumerate(pairs):
        o = old.replace("\n", nl)
        n = new.replace("\n", nl)
        c = s.count(o)
        assert c == 1, "%s 第 %d 条锚点出现 %d 次：%r" % (p, i + 1, c, old[:60])
        s = s.replace(o, n)
    write(p, s)
    print("OK", p)


# ── ① relics.json ────────────────────────────────────────────────────────────
patch("relics.json", [
    (
        '    {\n'
        '      "id": 6089,\n'
        '      "name": "空故事书",\n'
        '      "kind": "战斗",\n'
        '      "source": "初始",\n'
        '      "tier": "一般",\n'
        '      "desc": "战斗开始时，对所有敌人造成 0 伤害。每经过一个事件或首领战，此伤害 +1。"\n'
        '    }\n',
        '    {\n'
        '      "id": 6089,\n'
        '      "name": "空故事书",\n'
        '      "kind": "战斗",\n'
        '      "source": "初始",\n'
        '      "tier": "一般",\n'
        '      "desc": "战斗开始时，对所有敌人造成 0 伤害。每经过一个事件或首领战，此伤害 +1。"\n'
        '    },\n'
        '    {\n'
        '      "id": 6090,\n'
        '      "name": "稀有价值",\n'
        '      "kind": "即时",\n'
        '      "source": "事件",\n'
        '      "tier": "一般",\n'
        '      "desc": "%s"\n'
        '    }\n' % DESC_ZH,
    ),
])

# ── ② noncard 四语 ──────────────────────────────────────────────────────────
patch("i18n/noncard_zh_canonical.json", [
    (
        '    "6089": {"name": "空故事书", "desc": "战斗开始时，对所有敌人造成 0 伤害。每经过一个事件或首领战，此伤害 +1。"}\n',
        '    "6089": {"name": "空故事书", "desc": "战斗开始时，对所有敌人造成 0 伤害。每经过一个事件或首领战，此伤害 +1。"},\n'
        '    "6090": {"name": "%s", "desc": "%s"}\n' % (NAME, DESC_ZH),
    ),
])
for lang, nm, ds in (("en", "Rare Value", DESC_EN),
                     ("ja", "希少価値", DESC_JA),
                     ("es", "Valor escaso", DESC_ES)):
    patch("i18n/noncard_%s.json" % lang, [
        (
            '    "6089": {',
            '    "6090": {"name": "%s", "desc": "%s"},\n    "6089": {' % (nm, ds),
        ),
    ])

# ── ③ glossary.json：事件名 / 道具名 / 附魔名 ────────────────────────────────
patch("i18n/glossary.json", [
    (
        '    "空故事书": {\n'
        '      "en": "Empty Storybook",\n'
        '      "ja": "空の絵本",\n'
        '      "id": 6089\n'
        '    }\n',
        '    "空故事书": {\n'
        '      "en": "Empty Storybook",\n'
        '      "ja": "空の絵本",\n'
        '      "id": 6089\n'
        '    },\n'
        '    "稀有价值": {\n'
        '      "en": "Rare Value",\n'
        '      "ja": "希少価値",\n'
        '      "id": 6090\n'
        '    }\n',
    ),
    (
        '    "诡异洋房": {\n'
        '      "en": "The Haunted House",\n'
        '      "ja": "不気味な洋館",\n'
        '      "key": "haunted_house"\n'
        '    }\n',
        '    "诡异洋房": {\n'
        '      "en": "The Haunted House",\n'
        '      "ja": "不気味な洋館",\n'
        '      "key": "haunted_house"\n'
        '    },\n'
        '    "龙石板": {\n'
        '      "en": "Dragon Slab",\n'
        '      "ja": "龍の石板",\n'
        '      "key": "dragon_slab",\n'
        '      "note": "刻着盘龙的土黄石板；「强力的龙 / 尊贵的龙」是玩家的解读"\n'
        '    }\n',
    ),
    (
        '    "契约核心": {\n'
        '      "en": "Contract Core",\n'
        '      "ja": "契約コア",\n'
        '      "note": "动态数值名；与事件契约的核心区分"\n'
        '    }\n',
        '    "契约核心": {\n'
        '      "en": "Contract Core",\n'
        '      "ja": "契約コア",\n'
        '      "note": "动态数值名；与事件契约的核心区分"\n'
        '    },\n'
        '    "力量 +8": {\n'
        '      "en": "Power +8",\n'
        '      "ja": "パワー+8",\n'
        '      "note": "R842 事件「龙石板」专属附魔；沿用「伤害 +8」的标记外观"\n'
        '    }\n',
    ),
])

# ── ④ demo_scope.json（试玩基线：道具全登陆 + 新事件按白名单） ────────────────
patch("demo_scope.json", [
    (
        '    "divination",\n    "factory",\n',
        '    "divination",\n    "dragon_slab",\n    "factory",\n',
    ),
    (
        '    6088,\n    6089\n  ],\n',
        '    6088,\n    6089,\n    6090\n  ],\n',
    ),
])
print("done")
