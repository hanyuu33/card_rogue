# -*- coding: utf-8 -*-
"""R835 数据层（续）：noncard 四语 + glossary + validate_spanish。

noncard_*.json 的 relics 段是**紧凑单行**格式（`"6088": {...}` 一行一条），
与 glossary 的多行格式不同 —— 第一版脚本按多行写，锚点 count=0，这里按真实格式补。
relics.json / demo_scope.json 已在 `_r835_data.py` 里改完。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"

DESC_ZH = "战斗开始时，对所有敌人造成 0 伤害。每经过一个事件或首领战，此伤害 +1。"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def rep(p, old, new, n=1):
    s = read(p)
    c = s.count(old)
    if c != n:
        print("!! %s count=%d 期望 %d\n   %r" % (p, c, n, old[:100]))
        sys.exit(1)
    write(p, s.replace(old, new, n))
    print("ok %-34s" % p)


rep("i18n/noncard_zh_canonical.json",
    '    "6088": {"name": "首饰盒", "desc": "将一张随机史诗卡加入你的卡组。"}\n  },\n',
    '    "6088": {"name": "首饰盒", "desc": "将一张随机史诗卡加入你的卡组。"},\n'
    '    "6089": {"name": "空故事书", "desc": "%s"}\n  },\n' % DESC_ZH)

rep("i18n/noncard_en.json",
    '    "6088": {"name": "Jewelry Box", "desc": "On pickup: add a random Epic card to your deck."}\n  },\n',
    '    "6088": {"name": "Jewelry Box", "desc": "On pickup: add a random Epic card to your deck."},\n'
    '    "6089": {"name": "Empty Storybook", "desc": "At the start of each battle, deal 0 damage '
    'to all enemies. This damage increases by 1 for every event or Boss Battle you complete."}\n  },\n')

rep("i18n/noncard_ja.json",
    '    "6088": {"name": "宝石箱", "desc": "入手時：ランダムなエピックカードを1枚デッキに加える。"}\n  },\n',
    '    "6088": {"name": "宝石箱", "desc": "入手時：ランダムなエピックカードを1枚デッキに加える。"},\n'
    '    "6089": {"name": "空の絵本", "desc": "戦闘開始時、すべての敵に0ダメージを与える。'
    'イベントまたはボス戦を1回経るごとに、このダメージ+1。"}\n  },\n')

rep("i18n/noncard_es.json",
    '    "6088": {"name": "Caja de joyas", "desc": "Al recoger: añade 1 carta épica aleatoria a tu mazo."}\n  },\n',
    '    "6088": {"name": "Caja de joyas", "desc": "Al recoger: añade 1 carta épica aleatoria a tu mazo."},\n'
    '    "6089": {"name": "Libro de cuentos vacío", "desc": "Al inicio de cada combate, inflige 0 de '
    'daño a todos los enemigos. Este daño aumenta en 1 por cada evento o combate contra un jefe que superes."}\n  },\n')

rep("i18n/glossary.json",
    '    "首饰盒": {\n      "en": "Jewelry Box",\n      "ja": "宝石箱",\n      "id": 6088\n    }\n',
    '    "首饰盒": {\n      "en": "Jewelry Box",\n      "ja": "宝石箱",\n      "id": 6088\n    },\n'
    '    "空故事书": {\n      "en": "Empty Storybook",\n      "ja": "空の絵本",\n      "id": 6089\n    }\n')

rep("i18n/validate_spanish.py",
    'check(len(NONCARD_ES["relics"]) == 83 and len(NONCARD_ES["classes"]) == 3,\n'
    '      "noncard 为 82 件道具 + 3 个角色（R792 +3 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R806 +法术卷轴 6080 / R805 +蜂蜜 6079 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087）")',
    'check(len(NONCARD_ES["relics"]) == 84 and len(NONCARD_ES["classes"]) == 3,\n'
    '      "noncard 为 84 件道具 + 3 个角色（R792 +3 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R806 +法术卷轴 6080 / R805 +蜂蜜 6079 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087 / R830 +首饰盒 6088 / R835 +空故事书 6089）")')

print("\n全部通过")
