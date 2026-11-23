#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：同步四组卡数断言（+2 张：余音 9274 / 音符 9275）。

图鉴 334→336 / 玩家 256→258 / 吟游诗人 7→9 / 玩家技能 109→111（可造成伤害仍 44：
两张新卡都不打伤害）。
"""
P = "scripts/test_engine.gd"
d = open(P, "rb").read().decode("utf-8")

pairs = [
    # ① 图鉴总数
    ("\tcheck(repo.all_cards().size() == 334,\r\n",
     "\tcheck(repo.all_cards().size() == 336,\r\n"),
    ('\t\t\t"图鉴 = 334 张（R799 玩家 +2：连斩 9272',
     '\t\t\t"图鉴 = 336 张（R800 玩家 +2：余音 9274（吟游诗人 · X 费稀有技能）/'
     ' 音符 9275（0 费技能 · 次元 · event_only 内部卡）；R799 玩家 +2：连斩 9272'),
    # ② 分组
    ("\tcheck(grp_player.size() == 256 and grp_enemy.size() == 78,\r\n",
     "\tcheck(grp_player.size() == 258 and grp_enemy.size() == 78,\r\n"),
    ('\t\t\t"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 256 / 78（R794 玩家 +1：',
     '\t\t\t"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 258 / 78（R800 玩家 +2：'
     '余音 9274 / 音符 9275；R794 玩家 +1：'),
    # ③ 吟游诗人
    ('\t\t\tand int(dr_cls_count.get(PlayerClass.BARD, 0)) == 7\r\n',
     '\t\t\tand int(dr_cls_count.get(PlayerClass.BARD, 0)) == 9\r\n'),
    ("（期望 78 / 67 / 76 / 78 / 吟游诗人 7 / 公用",
     "（期望 78 / 67 / 76 / 78 / 吟游诗人 9（R800 +2：余音 / 音符） / 公用"),
    # ④ R226 玩家技能卡
    ("\tcheck(r226_skills == 109 and r226_dmg == 44 and r226_leak.is_empty(),\r\n",
     "\tcheck(r226_skills == 111 and r226_dmg == 44 and r226_leak.is_empty(),\r\n"),
]

for old, new in pairs:
    assert d.count(old) == 1, "count=%d for %r" % (d.count(old), old[:50])
    d = d.replace(old, new)

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
assert b.count(b"\n") == b.count(b"\r\n"), "行尾被改成 LF 了"
print("counts ok: CRLF %d" % b.count(b"\r\n"))
