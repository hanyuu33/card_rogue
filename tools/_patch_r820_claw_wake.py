#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R820 补丁：
① 猴爪 6066 文本 —— 「本回合费用-1」补上主语「该卡」，说清减费的是发进手牌的那张；
② 屏幕苏醒飘字 —— 沉睡不再只属于恶魔鸭（激光巨炮 9241 也带「沉睡」trait），
   飘字按卡名取，去掉写死的「恶魔鸭」。
"""
import io
import sys

ROOT = "."


def patch(path: str, pairs, expect_one=True):
    with io.open(path, "rb") as f:
        raw = f.read()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            old = old.replace("\n", "\r\n")
            new = new.replace("\n", "\r\n")
        n = text.count(old)
        if expect_one:
            assert n == 1, "%s: 锚点命中 %d 次（应为 1）\n---\n%s" % (path, n, old)
        else:
            assert n >= 1, "%s: 锚点未命中\n---\n%s" % (path, old)
        text = text.replace(old, new)
    with io.open(path, "wb") as f:
        f.write(text.encode("utf-8"))
    print("[OK] %s（%s）" % (path, "CRLF" if crlf else "LF"))


OLD_DESC = ('"desc": "每场战斗的前三个回合开始时：将一张随机其他职业卡加入手牌（本回合费用-1），'
            '并将一张「懊悔」加入卡组。"')
NEW_DESC = ('"desc": "每场战斗的前三个回合开始时：将一张随机其他职业卡加入手牌（该卡本回合费用-1），'
            '并将一张「懊悔」加入卡组。"')

patch("relics.json", [(OLD_DESC, NEW_DESC)])
patch("i18n/noncard_zh_canonical.json", [(OLD_DESC, NEW_DESC)])

patch("scripts/battle_scene.gd", [
    # ① 分支头注释：说明这是「沉睡单位」通用事件，不是恶魔鸭专属
    ("\t\t\t# 恶魔鸭（9116，R63 / R72 补特效）：沉睡结束 / 被击中提前醒来。",
     "\t\t\t# 沉睡单位（恶魔鸭 9116 / 激光巨炮 9241 …，R63 / R72 补特效）：沉睡结束 / 被击中提前醒来。"),
    # ② 飘字：按卡名取，去掉写死的「恶魔鸭」
    ('\t\t\tvar wk_txt := "恶魔鸭 苏醒"\n'
     '\t\t\tvar wk_col := Color("9b6bff")\n'
     '\t\t\tif bool(data.get("hurt", false)):\n'
     '\t\t\t\twk_txt = "恶魔鸭 提前醒来"',
     '\t\t\t# R820：沉睡不再只属于恶魔鸭 —— 飘字按**卡名**取，谁醒就显示谁。\n'
     '\t\t\tvar wk_card := data.get("card", null) as CardData\n'
     '\t\t\tvar wk_name := str(wk_card.card_name) if wk_card != null else ""\n'
     '\t\t\tvar wk_txt := ("%s 苏醒" % wk_name) if wk_name != "" else "苏醒"\n'
     '\t\t\tvar wk_col := Color("9b6bff")\n'
     '\t\t\tif bool(data.get("hurt", false)):\n'
     '\t\t\t\twk_txt = ("%s 提前醒来" % wk_name) if wk_name != "" else "提前醒来"'),
    # ③ 挣脱环绘制处的注释
    ("\t## 恶魔鸭苏醒（R72）：一圈圈向外扩散并淡出的**空心**挣脱环。",
     "\t## 沉睡单位苏醒（R72；恶魔鸭 / 激光巨炮等通用）：一圈圈向外扩散并淡出的**空心**挣脱环。"),
])

print("R820 patch done")
