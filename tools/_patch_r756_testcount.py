# -*- coding: utf-8 -*-
"""R756：test_engine 里五处计数断言 +3 张卡 / +1 关。"""
import io

P = "e:/work/card_rogue/scripts/test_engine.gd"
raw = io.open(P, "r", encoding="utf-8", newline="").read()
assert "\r\n" in raw


def rep(old, new, why):
    global raw
    o = old.replace("\n", "\r\n")
    n = new.replace("\n", "\r\n")
    c = raw.count(o)
    assert c == 1, "%s：命中 %d" % (why, c)
    raw = raw.replace(o, n)
    print("ok:", why)


rep(
    "\tcheck(repo.all_cards().size() == 320,",
    "\tcheck(repo.all_cards().size() == 323,",
    "图鉴总数",
)
rep(
    "\t\t\t\"图鉴 = 320 张（R756 +1：代偿 9252",
    "\t\t\t\"图鉴 = 323 张（R756 +4：计量工坊三只 9253 常数测量员 / 9254 精密计算者 / 9255 负载增量员 + 代偿 9252",
    "图鉴总数注释",
)
rep(
    "\tcheck(grp_player.size() == 245 and grp_enemy.size() == 75,",
    "\tcheck(grp_player.size() == 245 and grp_enemy.size() == 78,",
    "图鉴分组",
)
rep(
    "\t\t\t\"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 244 / 75（R692 玩家 +2",
    "\t\t\t\"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 245 / 78（R756 敌人 +3：计量工坊三只；R692 玩家 +2",
    "图鉴分组注释",
)
rep(
    "\tcheck(GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size() == 21,",
    "\tcheck(GameLevels.levels_of_layer(GameLayers.LAYER_TWO).size() == 22,",
    "第二层关数",
)
rep(
    "\t\t\t\"第二层自带 21 关（R541 普罗诺亚之影 +1",
    "\t\t\t\"第二层自带 22 关（R756 计量工坊 +1；R541 普罗诺亚之影 +1",
    "第二层关数注释",
)
rep(
    "\tcheck(GameLevels.normal_pool(GameLayers.LAYER_TWO).size() == 9,",
    "\tcheck(GameLevels.normal_pool(GameLayers.LAYER_TWO).size() == 10,",
    "第二层普通池",
)
rep(
    "\t\t\t\"第二层普通池 9 关（专属：普通简单 4 + 普通困难 5；",
    "\t\t\t\"第二层普通池 10 关（专属：普通简单 4 + 普通困难 6（R756 计量工坊）；",
    "第二层普通池注释",
)
rep(
    "\t\t\tand int(dr_cls_count.get(\"敌人\", 0)) == 75",
    "\t\t\tand int(dr_cls_count.get(\"敌人\", 0)) == 78",
    "敌人 class 计数",
)
rep(
    "\t\t\"角色系统：森林精魄 %d 张 / 暗影刺客 %d 张 / 机械之心 %d 张 / 敌人 %d 张（期望 78 / 66 / 75 / 75 / 公用 26，R756 公用 +1（代偿 9252）；",
    "\t\t\"角色系统：森林精魄 %d 张 / 暗影刺客 %d 张 / 机械之心 %d 张 / 敌人 %d 张（期望 78 / 66 / 75 / 78 / 公用 26，R756 敌人 +3（计量工坊三只）+ 公用 +1（代偿 9252）；",
    "敌人 class 注释",
)

io.open(P, "w", encoding="utf-8", newline="").write(raw)
print("written")
