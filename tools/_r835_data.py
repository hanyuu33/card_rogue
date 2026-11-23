# -*- coding: utf-8 -*-
"""R835 数据层：新增一层初始道具「空故事书」6089。

改 6 个文件（全部 LF，精确锚点 + count==1 断言）：
  relics.json                      6089 定义
  demo_scope.json                  relics 白名单 +6089（83→84）
  i18n/noncard_zh_canonical.json   四语之一：中文母本
  i18n/noncard_en.json             en
  i18n/noncard_ja.json             ja
  i18n/noncard_es.json             es
  i18n/glossary.json               词条
  i18n/validate_spanish.py         条数 83→84 + 文案

用法：python tools/_r835_data.py
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
        print("!! %s count=%d 期望 %d\n   %r" % (p, c, n, old[:80]))
        sys.exit(1)
    write(p, s.replace(old, new, n))
    print("ok %-34s +%d 处" % (p, n))


# ── 1) relics.json：6088 之后追加 6089 ──────────────────────────────────────
old = ('      "id": 6088,\n'
       '      "name": "首饰盒",\n'
       '      "kind": "即时",\n'
       '      "source": "初始",\n'
       '      "tier": "一般",\n'
       '      "desc": "将一张随机史诗卡加入你的卡组。"\n'
       '    }\n'
       '  ]\n'
       '}\n')
new = ('      "id": 6088,\n'
       '      "name": "首饰盒",\n'
       '      "kind": "即时",\n'
       '      "source": "初始",\n'
       '      "tier": "一般",\n'
       '      "desc": "将一张随机史诗卡加入你的卡组。"\n'
       '    },\n'
       '    {\n'
       '      "id": 6089,\n'
       '      "name": "空故事书",\n'
       '      "kind": "战斗",\n'
       '      "source": "初始",\n'
       '      "tier": "一般",\n'
       '      "desc": "%s"\n'
       '    }\n'
       '  ]\n'
       '}\n' % DESC_ZH)
rep("relics.json", old, new)

# ── 2) demo_scope.json：白名单 +6089 ───────────────────────────────────────
rep("demo_scope.json",
    "    6087,\n    6088\n  ],\n",
    "    6087,\n    6088,\n    6089\n  ],\n")

# ── 3) noncard 四语 ───────────────────────────────────────────────────────
rep("i18n/noncard_zh_canonical.json",
    '    "6088": {\n      "name": "首饰盒",\n      "desc": "将一张随机史诗卡加入你的卡组。"\n    }\n',
    '    "6088": {\n      "name": "首饰盒",\n      "desc": "将一张随机史诗卡加入你的卡组。"\n    },\n'
    '    "6089": {\n      "name": "空故事书",\n      "desc": "%s"\n    }\n' % DESC_ZH)

rep("i18n/noncard_en.json",
    '    "6088": {\n      "name": "Jewelry Box",\n      "desc": "On pickup: add a random Epic card to your deck."\n    }\n',
    '    "6088": {\n      "name": "Jewelry Box",\n      "desc": "On pickup: add a random Epic card to your deck."\n    },\n'
    '    "6089": {\n      "name": "Empty Storybook",\n'
    '      "desc": "At the start of each battle, deal 0 damage to all enemies. '
    'This damage increases by 1 for every event or Boss Battle you complete."\n    }\n')

rep("i18n/noncard_ja.json",
    '    "6088": {\n      "name": "宝石箱",\n      "desc": "入手時：ランダムなエピックカードを1枚デッキに加える。"\n    }\n',
    '    "6088": {\n      "name": "宝石箱",\n      "desc": "入手時：ランダムなエピックカードを1枚デッキに加える。"\n    },\n'
    '    "6089": {\n      "name": "空の絵本",\n'
    '      "desc": "戦闘開始時、すべての敵に0ダメージを与える。'
    'イベントまたはボス戦を1回経るごとに、このダメージ+1。"\n    }\n')

rep("i18n/noncard_es.json",
    '    "6088": {\n      "name": "Caja de joyas",\n      "desc": "Al recoger: añade 1 carta épica aleatoria a tu mazo."\n    }\n',
    '    "6088": {\n      "name": "Caja de joyas",\n      "desc": "Al recoger: añade 1 carta épica aleatoria a tu mazo."\n    },\n'
    '    "6089": {\n      "name": "Libro de cuentos vacío",\n'
    '      "desc": "Al inicio de cada combate, inflige 0 de daño a todos los enemigos. '
    'Este daño aumenta en 1 por cada evento o combate contra un jefe que superes."\n    }\n')

# ── 4) glossary 词条 ──────────────────────────────────────────────────────
rep("i18n/glossary.json",
    '    "首饰盒": {\n      "en": "Jewelry Box",\n      "ja": "宝石箱",\n      "id": 6088\n    }\n',
    '    "首饰盒": {\n      "en": "Jewelry Box",\n      "ja": "宝石箱",\n      "id": 6088\n    },\n'
    '    "空故事书": {\n      "en": "Empty Storybook",\n      "ja": "空の絵本",\n      "id": 6089\n    }\n')

# ── 5) validate_spanish：条数 83→84 + 文案 ────────────────────────────────
rep("i18n/validate_spanish.py",
    'check(len(NONCARD_ES["relics"]) == 83 and len(NONCARD_ES["classes"]) == 3,\n'
    '      "noncard 为 82 件道具 + 3 个角色（R792 +3 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R806 +法术卷轴 6080 / R805 +蜂蜜 6079 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087）")',
    'check(len(NONCARD_ES["relics"]) == 84 and len(NONCARD_ES["classes"]) == 3,\n'
    '      "noncard 为 84 件道具 + 3 个角色（R792 +3 / R793 +刺墙 6073 / 应急装甲 6074 / R794 +圣剑 6075 / R796 +兔脚 6076 / 钻头 6077 / R797 +龟壳 6078 / R806 +法术卷轴 6080 / R805 +蜂蜜 6079 / R810 +新月耳饰 6081 / 太阳指环 6082 / 海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085 / R826 +音乐盒 6086 / R829 +这是礼帽 6087 / R830 +首饰盒 6088 / R835 +空故事书 6089）")')

print("\n全部通过")
