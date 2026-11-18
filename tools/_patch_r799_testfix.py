# -*- coding: utf-8 -*-
"""R799：test_engine.gd 的配套修正。
① 数据计数 +2（图鉴 / 分组 / 奖励池 / 角色 / 技能伤害表）
② R769 猴爪：起手牌抽到 X 费卡时假红 → 候选池排除 x_cost
③ R311 不锈钢盆：环境道具（荒野形态的首次受击 -4）会改掉精确差值 → 先隔离
"""
P = "scripts/test_engine.gd"
d = open(P, "rb").read().decode("utf-8")


def rep(old, new, tag):
    global d
    n = d.count(old)
    assert n == 1, "%s count=%d" % (tag, n)
    d = d.replace(old, new)


NOTE = "R799 玩家 +2：连斩 9272（暗影刺客 · X 费稀有技能）/ 炮火就位 9273（机械之心 · X 费史诗技能）；"

# ①-1 图鉴总数
rep("check(repo.all_cards().size() == 332,\r\n", "check(repo.all_cards().size() == 334,\r\n", "allcards")
rep('"图鉴 = 332 张（', '"图鉴 = 334 张（' + NOTE, "allcards-msg")

# ①-2 玩家 / 敌人分组
rep("check(grp_player.size() == 254 and grp_enemy.size() == 78,\r\n",
    "check(grp_player.size() == 256 and grp_enemy.size() == 78,\r\n", "grp")
rep('（期望 254 / 78（', '（期望 256 / 78（', "grp-msg")

# ①-3 奖励池
rep("check(pool.size() == 202,\r\n", "check(pool.size() == 204,\r\n", "pool")
rep('"奖励池 202 张（', '"奖励池 204 张（' + NOTE, "pool-msg")
rep('check(int(r45_pool.size()) == 202, "R757 +1：漩涡 9186',
    'check(int(r45_pool.size()) == 204, "R757 +1：漩涡 9186', "pool-msg2")

# ①-4 角色系统（R45 汇总）
rep('and int(dr_cls_count.get(PlayerClass.ROGUE, 0)) == 66\r\n',
    'and int(dr_cls_count.get(PlayerClass.ROGUE, 0)) == 67\r\n', "cls-rogue")
rep('and int(dr_cls_count.get(PlayerClass.MECH, 0)) == 75\r\n',
    'and int(dr_cls_count.get(PlayerClass.MECH, 0)) == 76\r\n', "cls-mech")
rep('（期望 78 / 66 / 75 / 78 /', '（期望 78 / 67 / 76 / 78 /', "cls-msg")

# ①-5 R45 归属
rep('and int(r45_cls_count.get(PlayerClass.ROGUE, 0)) == 66,',
    'and int(r45_cls_count.get(PlayerClass.ROGUE, 0)) == 67,', "r45")
rep('"R45：全库角色归属（森林精魄 %d / 暗影刺客 %d；',
    '"R45：全库角色归属（森林精魄 %d / 暗影刺客 %d；' + NOTE, "r45-msg")

# ①-6 R226 技能卡 / 可造成伤害
rep("check(r226_skills == 107 and r226_dmg == 42 and r226_leak.is_empty(),\r\n",
    "check(r226_skills == 109 and r226_dmg == 44 and r226_leak.is_empty(),\r\n", "r226")

# ①-7 奖励池过滤
rep("check(r47_dr.size() == 71 and r47_rg.size() == 61\r\n",
    "check(r47_dr.size() == 72 and r47_rg.size() == 62\r\n", "r47")

# ② R769 猴爪：候选池排掉 X 费卡
rep("\t\tif r769_e._other_class_card(c) and c.id != GameEngine.ECHO_ID:\r\n",
    "\t\t# R799：X 费卡（连斩 9272 / 炮火就位 9273）的 `cost_of()` 返回「当前全部费用」，\r\n"
    "\t\t# 本来就不吃这张 -1 折扣 —— 落进起手牌时这条断言会假红，候选池直接排掉。\r\n"
    "\t\tif r769_e._other_class_card(c) and c.id != GameEngine.ECHO_ID and not c.x_cost:\r\n",
    "r769")

# ③ R311 不锈钢盆：先清空道具，避免环境道具改掉精确差值
rep("\tr311_beng.basin_charge = 10\r\n",
    "\t# R799：这条断言算的是「盆吃多少 / 玩家吃多少」的精确差值。环境里若挂着\r\n"
    "\t# 荒野形态 6022（每场首次受击 -4）之类的道具，3 点会变成 1 点 → 差值对不上。\r\n"
    "\t# 与紧随其后那段「商店抵账」同样先清空道具栏，保证可复现。\r\n"
    "\tRunState.relics = []\r\n"
    "\tr311_beng.self_relics = []\r\n"
    "\tr311_beng.basin_charge = 10\r\n",
    "r311")

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
print("ok")
