#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R821 补丁：机械臂 6065 两处真源措辞统一（店长口径「用前一种」）。
前一种 = relics.json 的简短句式；同时把全库唯一一处「手卡」改成主流的「手牌」。
canonical 原来是「每场战斗开始时，从当前角色奖励池随机选择一张盟友加入手牌；
这张卡在第一个我方回合费用 -1。」——信息更细但句式更长，按店长口径退成简版，
en/ja/es 同步退成简版，避免三语比中文更细。
"""
import io
import json


def patch(path, pairs):
    with io.open(path, "rb") as f:
        raw = f.read()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            old = old.replace("\n", "\r\n")
            new = new.replace("\n", "\r\n")
        n = text.count(old)
        assert n == 1, "%s: 命中 %d 次\n%s" % (path, n, old)
        text = text.replace(old, new)
    with io.open(path, "wb") as f:
        f.write(text.encode("utf-8"))
    print("[OK]", path)


ZH_NEW = "每次战斗开始，将一张随机盟友加入手牌，本回合费用-1。"

patch("relics.json", [
    ('"desc": "每次战斗开始，把一张随机盟友加入你的手卡，本回合费用-1。"',
     '"desc": "%s"' % ZH_NEW),
])

patch("i18n/noncard_zh_canonical.json", [
    ('"6065": {"name": "机械臂", "desc": "每场战斗开始时，从当前角色奖励池随机选择一张盟友加入手牌；这张卡在第一个我方回合费用 -1。"},',
     '"6065": {"name": "机械臂", "desc": "%s"},' % ZH_NEW),
])

patch("i18n/noncard_en.json", [
    ('"desc": "At the start of each battle, add a random Ally from the current class\'s reward pool to your Hand; it has Cost -1 during your first turn."',
     '"desc": "At the start of each battle, add a random Ally to your Hand; it has Cost -1 this turn."'),
])

patch("i18n/noncard_ja.json", [
    ('"desc": "各戦闘開始時、現在のキャラクターの報酬プールからランダムな味方1枚を選んで手札に加える。このカードは最初の自分のターンにコスト-1。"',
     '"desc": "各戦闘開始時、ランダムな味方1枚を手札に加える。このカードはこのターン中コスト-1。"'),
])

patch("i18n/noncard_es.json", [
    ('"desc": "Al comienzo de cada combate, añade a tu mano un Aliado aleatorio del grupo de recompensas de la clase actual; tiene Coste -1 durante tu primer turno."',
     '"desc": "Al comienzo de cada combate, añade un Aliado aleatorio a tu mano; cuesta -1 este turno."'),
])

# 结构体检
for p in ["relics.json", "i18n/noncard_zh_canonical.json", "i18n/noncard_en.json",
          "i18n/noncard_ja.json", "i18n/noncard_es.json"]:
    d = json.load(io.open(p, encoding="utf-8"))
    print("[json ok]", p)
print("R821 patch done")
