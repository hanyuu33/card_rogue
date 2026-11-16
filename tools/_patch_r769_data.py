# -*- coding: utf-8 -*-
"""R769：猴爪 6066 加一句「加入手牌的那张，本回合费用 -1」，五处文本同步。

店长原话：「猴爪：新增加入手卡的卡本回合费用－1。注意修改文本」

措辞对齐既有口径（不是自己新造）：
  * 中文「本回合费用-1」 —— relics.json 里已有同款写法（无空格）
  * 英文 "costs -1 this turn" —— 与「随心组装 9144」那条同机制、同措辞
  * 日文「このターン中コスト-1」 —— 与 cards_ja 既有写法一致
  * 西文 "cuesta -1 este turno" —— 与 cards_es 既有写法一致
"""
import io
import json

ROOT = r"E:\work\card_rogue"

OLD_ZH = "每场战斗的前三个回合开始时：将一张随机其他职业卡加入手牌，并将一张「懊悔」加入卡组。"
NEW_ZH = "每场战斗的前三个回合开始时：将一张随机其他职业卡加入手牌（本回合费用-1），并将一张「懊悔」加入卡组。"

OLD_EN = ("At the start of each of the first three turns of every battle: add a random card "
          "of another class to your Hand, and add a Regret to your Deck.")
NEW_EN = ("At the start of each of the first three turns of every battle: add a random card "
          "of another class to your Hand (it costs -1 this turn), and add a Regret to your Deck.")

OLD_JA = ("戦闘ごとの最初の3ターン開始時：他職のランダムなカード1枚を手札に加え、"
          "デッキに「後悔」を1枚加える。")
NEW_JA = ("戦闘ごとの最初の3ターン開始時：他職のランダムなカード1枚を手札に加え"
          "（このターン中コスト-1）、デッキに「後悔」を1枚加える。")

OLD_ES = ("Al inicio de cada uno de los tres primeros turnos de cada combate: añade una carta "
          "aleatoria de otra clase a tu mano y añade un Arrepentimiento a tu mazo.")
NEW_ES = ("Al inicio de cada uno de los tres primeros turnos de cada combate: añade una carta "
          "aleatoria de otra clase a tu mano (cuesta -1 este turno) y añade un Arrepentimiento "
          "a tu mazo.")

JOBS = [
    (r"relics.json", OLD_ZH, NEW_ZH),
    (r"i18n\noncard_zh_canonical.json", OLD_ZH, NEW_ZH),
    (r"i18n\noncard_en.json", OLD_EN, NEW_EN),
    (r"i18n\noncard_ja.json", OLD_JA, NEW_JA),
    (r"i18n\noncard_es.json", OLD_ES, NEW_ES),
]

import os

for rel, old, new in JOBS:
    p = os.path.join(ROOT, rel)
    s = io.open(p, encoding="utf-8", newline="").read()
    n = s.count(old)
    assert n == 1, "%s: 锚点命中 %d 次（期望 1）" % (rel, n)
    io.open(p, "w", encoding="utf-8", newline="").write(s.replace(old, new))
    print("改好", rel)

# 复核：五处都应含新句，且旧句不再出现
for rel, old, new in JOBS:
    p = os.path.join(ROOT, rel)
    s = io.open(p, encoding="utf-8", newline="").read()
    assert new in s and old not in s, "%s 复核失败" % rel

# JSON 仍可解析
for rel in (r"relics.json", r"i18n\noncard_zh_canonical.json",
            r"i18n\noncard_en.json", r"i18n\noncard_ja.json", r"i18n\noncard_es.json"):
    p = os.path.join(ROOT, rel)
    json.load(io.open(p, encoding="utf-8"))
print("五处文本已同步，JSON 均可解析")
