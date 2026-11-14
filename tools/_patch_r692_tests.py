# -*- coding: utf-8 -*-
"""R692 测试补丁：飓风咆哮每次触发×X / 幽深回响 8 点 / 鸭蛋回合开始孵化 /
鸭妈妈 + 小鸭 / 文案清理守卫 / 图鉴与池子计数。

用法：python tools/_patch_r692_tests.py [--write]
"""
import sys

P = "E:/work/card_rogue/scripts/test_engine.gd"
PA = "E:/work/card_rogue/scripts/test_assemble.gd"
WRITE = "--write" in sys.argv

raw = open(P, "rb").read().decode("utf-8")
assert raw.count("\r\n") == raw.count("\n")
out = raw

CR = "\r\n"


def rep(old, new, tag, cnt=1):
    """幂等替换：锚点已消失但新文本已在位 → 视为本轮已打过，跳过。"""
    global out
    c = out.count(old)
    if c == 0 and cnt == 1 and new in out:
        print("  [skip] %s 已应用" % tag)
        return
    assert c == cnt, "[%s] 锚点命中 %d 次（预期 %d）" % (tag, c, cnt)
    out = out.replace(old, new)


# ── ① 幽深回响：6 → 8 ──
rep(
    'and echo_card.rarity == 1 and echo_card.traits.has("幽深回响") and echo_card.value == 6',
    'and echo_card.rarity == 1 and echo_card.traits.has("幽深回响") and echo_card.value == 8',
    "echo value",
)
rep(
    '"幽深回响（R688 取代迅捷）：稀有 2 费效果卡，trait 幽深回响 value=6，文案「加入抽牌库」+「重复 X 次」")',
    '"幽深回响（R688 取代迅捷；R692 伤害 6→8）：稀有 2 费效果卡，trait 幽深回响 value=8，'
    '文案「加入抽牌库」+「重复 X 次」")',
    "echo msg",
)
rep(
    "check(CardData.from_dict(ser).value == 6 and CardData.from_dict(ser).is_effect(),",
    "check(CardData.from_dict(ser).value == 8 and CardData.from_dict(ser).is_effect(),",
    "echo ser",
)
rep(
    '"效果卡 value/kind 序列化保留（R688 幽深回响 value=6）")',
    '"效果卡 value/kind 序列化保留（R688 幽深回响 value=8）")',
    "echo ser msg",
)
rep("check(echo_hp1 == 54,", "check(echo_hp1 == 52,", "echo hp1")
rep(
    '"幽深回响：回合开始按效果区 1 张 → 打 1 下 6 点（60 → 54，实际 %d）" % echo_hp1)',
    '"幽深回响（R692 改成 8 点）：回合开始按效果区 1 张 → 打 1 下 8 点（60 → 52，实际 %d）" % echo_hp1)',
    "echo hp1 msg",
)
rep(
    "check(echo_e2.state.unit_at(Vector2i(1, 0)).health == 48,",
    "check(echo_e2.state.unit_at(Vector2i(1, 0)).health == 44,",
    "echo hp2",
)
rep(
    '"幽深回响：效果区 2 张 → 本回合打 2 下（60 → 48）")',
    '"幽深回响：效果区 2 张 → 本回合打 2 下 × 8 点（60 → 44）")',
    "echo hp2 msg",
)
rep("check(echo_foe_hp == 24,", "check(echo_foe_hp == 22,", "echo foe")
rep(
    '"幽深回响：场上没有敌方单位 → 直击对方 HP（30 → 24，实际 %d）" % echo_foe_hp)',
    '"幽深回响：场上没有敌方单位 → 直击对方 HP（30 → 22，实际 %d）" % echo_foe_hp)',
    "echo foe msg",
)

# ── ② 飓风咆哮：同回合每次使用都触发（第一处用例） ──
rep(
    "\tcheck(roar_e.state.unit_at(Vector2i(0, 0)).health == 4," + CR
    + CR
    + '\t\t\t"飓风咆哮：同回合第二次使用效果卡不再触发")' + CR
    + CR
    + "\troar_e.end_turn()   # 我方 → 敌方" + CR
    + CR
    + "\troar_e.end_turn()   # 敌方 → 我方（新回合，标记重置）" + CR
    + CR
    + "\troar_e.state.hand = [repo.get_card(9065)]" + CR
    + CR
    + "\troar_e.state.energy = 9" + CR
    + CR
    + "\troar_e.use_effect(0)" + CR
    + CR
    + "\tcheck(roar_e.state.unit_at(Vector2i(0, 0)) == null," + CR
    + CR
    + '\t\t\t"飓风咆哮：新回合再用效果卡再次触发 → 4 血的敌人被打死离场")',
    "\tcheck(roar_e.state.unit_at(Vector2i(0, 0)) == null" + CR
    + "\t\t\tand roar_e.state.unit_at(Vector2i(0, 2)) == null," + CR
    + CR
    + '\t\t\t"飓风咆哮（R692 每次使用都触发）：同回合第二次使用效果卡照样 -4 → 4 血的敌人被打死")',
    "roar 第二次",
)

# 第一处用例补一条「2 张 = 打 2 下」的独立断言（紧跟 roar_e2 之后）
rep(
    "\tcheck(roar_e2.state.hp_opponent == 16," + CR
    + CR
    + '\t\t\t"飓风咆哮：效果卡触发；场上没有敌人 → 直击敌方 HP -4（20→16）")',
    "\tcheck(roar_e2.state.hp_opponent == 16," + CR
    + CR
    + '\t\t\t"飓风咆哮：效果卡触发；场上没有敌人 → 直击敌方 HP -4（20→16）")' + CR
    + CR
    + "\t# R692：叠加不再是「前 X 次」，而是**一次打 X 下**（X = 效果区张数）" + CR
    + CR
    + "\tvar roar_e3 := _new_engine([], 20, 20, -1, false)" + CR
    + CR
    + "\troar_e3.start_game(0)" + CR
    + CR
    + "\troar_e3.state.effects.append(repo.get_card(9063))" + CR
    + CR
    + "\troar_e3.state.effects.append(repo.get_card(9063))" + CR
    + CR
    + '\troar_e3.state.place(_card(8003, "农民", "盟友", 3, 3, 30), Vector2i(0, 0),' + CR
    + CR
    + "\t\t\tGameEngine.SIDE_OPPONENT)" + CR
    + CR
    + "\tfor _r692_i in 3:" + CR
    + CR
    + "\t\troar_e3.state.hand = [repo.get_card(9065)]" + CR
    + CR
    + "\t\troar_e3.state.energy = 9" + CR
    + CR
    + "\t\troar_e3.use_effect(0)" + CR
    + CR
    + "\tcheck(roar_e3.state.unit_at(Vector2i(0, 0)).health == 6," + CR
    + CR
    + '\t\t\t"飓风咆哮（R692 叠加 = 造成 X 次）：2 张 → 3 次使用各打 2 下（30 - 24 = 6，'
    + '实际 %d）" % roar_e3.state.unit_at(Vector2i(0, 0)).health)',
    "roar 2张×X",
)

# ── ③ 飓风咆哮：第二处「2 张」用例（前 X 次 → 每次 ×X） ──
rep(
    "\tcheck(roar2.state.unit_at(Vector2i(0, 0)).health == 16," + CR
    + CR
    + '\t\t\t"飓风咆哮：2 张 → 第 1 次使用效果卡就触发（20 - 4 = 16）")' + CR
    + CR
    + "\troar2.state.hand = [repo.get_card(9065)]" + CR
    + CR
    + "\troar2.state.energy = 9" + CR
    + CR
    + "\troar2.use_effect(0)" + CR
    + CR
    + "\tcheck(roar2.state.unit_at(Vector2i(0, 0)).health == 12," + CR
    + CR
    + '\t\t\t"飓风咆哮：2 张 → 第 2 次使用再触发（16 - 4 = 12）")' + CR
    + CR
    + "\troar2.state.hand = [repo.get_card(9065)]" + CR
    + CR
    + "\troar2.state.energy = 9" + CR
    + CR
    + "\troar2.use_effect(0)" + CR
    + CR
    + "\tcheck(roar2.state.unit_at(Vector2i(0, 0)).health == 12," + CR
    + CR
    + '\t\t\t"飓风咆哮：2 张 → 第 3 次使用不再触发（仍 12）")',
    "\tcheck(roar2.state.unit_at(Vector2i(0, 0)).health == 12," + CR
    + CR
    + '\t\t\t"飓风咆哮（R692）：2 张 → 第 1 次使用就打 2 下（20 - 8 = 12）")' + CR
    + CR
    + "\troar2.state.hand = [repo.get_card(9065)]" + CR
    + CR
    + "\troar2.state.energy = 9" + CR
    + CR
    + "\troar2.use_effect(0)" + CR
    + CR
    + "\tcheck(roar2.state.unit_at(Vector2i(0, 0)).health == 4," + CR
    + CR
    + '\t\t\t"飓风咆哮（R692）：2 张 → 第 2 次使用再打 2 下（12 - 8 = 4）")' + CR
    + CR
    + "\troar2.state.hand = [repo.get_card(9065)]" + CR
    + CR
    + "\troar2.state.energy = 9" + CR
    + CR
    + "\troar2.use_effect(0)" + CR
    + CR
    + "\tcheck(roar2.state.unit_at(Vector2i(0, 0)) == null," + CR
    + CR
    + '\t\t\t"飓风咆哮（R692）：第 3 次照样触发（不再数次数）→ 4 血的敌人被打死离场")',
    "roar 第二处",
)

# ── ④ 文案清理后，两处「卡面标注」断言改判字段 ──
rep(
    '\t\t\tand r231_u2.effect_text.contains("行动两次"),',
    '\t\t\tand r231_u2.has_affix("疾行"),',
    "231 行动两次",
)
rep(
    '"R231 两张俄倪厄都带「破绽」trait 且文案写明往对方卡组加卡（俄倪厄保留两动）")',
    '"R231 两张俄倪厄都带「破绽」trait 且文案写明往对方卡组加卡（两动由「疾行」字段承载）")',
    "231 msg",
)
rep(
    '\t\tcheck(om_cd_d.effect_text.contains("每回合可以行动两次"),',
    '\t\tcheck(om_cd_d.has_affix("疾行"),',
    "14017 双动",
)
rep(
    '"二层强力怪物 %s(%d)：卡面标注双动" % [om_dbl[om_id_d], om_id_d])',
    '"二层强力怪物 %s(%d)：带「疾行」字段（R692 卡面不再复述字段说明）" % [om_dbl[om_id_d], om_id_d])',
    "14017 msg",
)

# ── ⑤ 鸭蛋：孵化改到「我方回合开始」 ──
rep(
    "\tr336_e.start_game(0)" + CR
    + CR
    + "\tvar r336_cell := Vector2i(FieldState.OPPONENT_ROWS, FieldState.BOARD_COLS / 2)" + CR
    + CR
    + "\tvar r336_void0: int = r336_e.state.void_count" + CR
    + CR
    + "\tvar r336_hatched: Array = []" + CR
    + CR
    + "\tr336_e.action.connect(func(k: String, d: Dictionary) -> void:" + CR
    + CR
    + '\t\t\tif k == "place" and bool(d.get("hatch", false)):' + CR
    + CR
    + "\t\t\t\tr336_hatched.append(d.get(\"cell\")))" + CR
    + CR
    + "\tr336_e.end_turn()",
    "\tvar r336_cell := Vector2i(FieldState.OPPONENT_ROWS, FieldState.BOARD_COLS / 2)" + CR
    + CR
    + "\tvar r336_void0: int = r336_e.state.void_count" + CR
    + CR
    + "\tvar r336_hatched: Array = []" + CR
    + CR
    + "\tr336_e.action.connect(func(k: String, d: Dictionary) -> void:" + CR
    + CR
    + '\t\t\tif k == "place" and bool(d.get("hatch", false)):' + CR
    + CR
    + "\t\t\t\tr336_hatched.append(d.get(\"cell\")))" + CR
    + CR
    + "\t# R692：孵化搬到**我方回合开始** → 第一回合 start_game 时就孵出来（不再等 end_turn）" + CR
    + "\tr336_e.start_game(0)",
    "R340 顺序",
)
rep(
    '"R340 生蛋鸭：回合结束鸭蛋 → 原地变宠物鸭（3/15 盟友）")',
    '"R340 / R692 生蛋鸭：我方回合开始时鸭蛋 → 原地变宠物鸭（3/15 盟友）")',
    "R340 msg",
)

# ── ⑥ 计数 ──
rep("check(repo.all_cards().size() == 317,", "check(repo.all_cards().size() == 319,", "图鉴数")
rep(
    '"图鉴 = 317 张（R689 +2：种子 9248 / 被眷顾者 9249；',
    '"图鉴 = 319 张（R692 +2：鸭妈妈 9250 / 小鸭 9251；R689 +2：种子 9248 / 被眷顾者 9249；',
    "图鉴文案",
)
rep("check(grp_player.size() == 242 and grp_enemy.size() == 75,",
    "check(grp_player.size() == 244 and grp_enemy.size() == 75,", "分组数")
rep('"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 242 / 75（R689 玩家 +2；',
    '"图鉴分组：玩家卡牌 %d 张 / 敌人 %d 张（期望 244 / 75（R692 玩家 +2：鸭妈妈 9250 / 小鸭 9251；R689 玩家 +2；',
    "分组文案")
rep("check(pool.size() == 200,", "check(pool.size() == 201,", "池数")
rep('"奖励池 200 张（R689 +1：',
    '"奖励池 201 张（R692 +1：鸭妈妈 9250 稀有进池（小鸭 9251 是 token 不进池）；R689 +1：',
    "池文案")
rep("check(int(dr_cls_count.get(PlayerClass.DRUID, 0)) == 76",
    "check(int(dr_cls_count.get(PlayerClass.DRUID, 0)) == 78",
    "森林精魄数", 1)
rep("check(int(r45_cls_count.get(PlayerClass.DRUID, 0)) == 76",
    "check(int(r45_cls_count.get(PlayerClass.DRUID, 0)) == 78",
    "R45 森林精魄数", 1)
rep('check(int(r45_pool.size()) == 200, "R689 +1：被眷顾者 9249',
    'check(int(r45_pool.size()) == 201, "R692 +1：鸭妈妈 9250（稀有进池；小鸭 9251 是 token 不进池）→ 201；R689 +1：被眷顾者 9249',
    "R45 池子")
rep("check(r47_dr.size() == 69 and r47_rg.size() == 61",
    "check(r47_dr.size() == 70 and r47_rg.size() == 61",
    "R47 池子")

# ── ⑦ 新用例：鸭妈妈 / 小鸭 + 文案守卫（插在幽深回响直击 HP 之后） ──
NEW = (
    CR
    + CR
    + "\t# ---- R692 鸭妈妈（9250）/ 小鸭（9251）----" + CR
    + CR
    + "\tvar dm_repo := CardRepo.load_json()" + CR
    + CR
    + "\tvar dm_mom: CardData = dm_repo.get_card(9250)" + CR
    + CR
    + "\tvar dm_duck: CardData = dm_repo.get_card(9251)" + CR
    + CR
    + '\tcheck(dm_mom != null and dm_mom.kind == "盟友" and dm_mom.cost == 4' + CR
    + CR
    + "\t\t\tand dm_mom.power == 3 and dm_mom.health == 15 and dm_mom.attack_range == 1" + CR
    + CR
    + "\t\t\tand dm_mom.move_speed == 1 and dm_mom.rarity == 1 and dm_mom.class == \"森林精魄\"" + CR
    + CR
    + '\t\t\tand dm_mom.effect_text.contains("「小鸭」"),' + CR
    + CR
    + '\t\t\t"R692 鸭妈妈：森林精魄 · 4 费稀有盟友 3/15/程1/速1，正文用「」引用小鸭（可点开卡面）")' + CR
    + CR
    + '\tcheck(dm_duck != null and dm_duck.kind == "盟友" and dm_duck.power == 1' + CR
    + CR
    + "\t\t\tand dm_duck.health == 1 and dm_duck.attack_range == 1 and dm_duck.move_speed == 1" + CR
    + CR
    + '\t\t\tand dm_duck.rarity == 5 and dm_duck.has_affix("次元"),' + CR
    + CR
    + '\t\t\t"R692 小鸭：1/1/程1/速1 的 token（rarity 5 不进池），带「次元」（离场即消失）")' + CR
    + CR
    + "\t# 名字表 / 正文解析：鸭妈妈正文里的「小鸭」必须真的指向 9251（否则浮窗点开是空）" + CR
    + CR
    + '\tvar dm_ref := Mention.resolve("小鸭")' + CR
    + CR
    + '\tcheck(not dm_ref.is_empty() and str(dm_ref.get("kind", "")) == "card"' + CR
    + CR
    + '\t\t\tand int(dm_ref.get("id", -1)) == 9251,' + CR
    + CR
    + '\t\t\t"R692 名字表：「小鸭」解析成卡牌 9251（鸭妈妈正文可点开它的卡面）")' + CR
    + CR
    + "\tvar dm_hits := 0" + CR
    + CR
    + "\tfor dm_seg in CardText.parse(dm_mom.effect_text):" + CR
    + CR
    + '\t\tvar dm_men: Dictionary = dm_seg.get("mention", {})' + CR
    + CR
    + '\t\tif str(dm_men.get("name", "")) == "小鸭" and int(dm_men.get("id", -1)) == 9251:' + CR
    + CR
    + "\t\t\tdm_hits += 1" + CR
    + CR
    + "\tcheck(dm_hits == 1," + CR
    + CR
    + '\t\t\t"R692 显示层：鸭妈妈正文里的「小鸭」生成指向 9251 的提及片段（各种界面都能带出小鸭）")' + CR
    + CR
    + "\t# ① 打出鸭妈妈：左右各一只小鸭" + CR
    + CR
    + "\tvar dm_e := _new_engine([], 20, 20, -1, false)" + CR
    + CR
    + "\tdm_e.start_game(0)" + CR
    + CR
    + "\tvar dm_fx: CardData = dm_repo.get_card(9065)" + CR
    + CR
    + "\tvar dm_fx2: CardData = dm_repo.get_card(9058)" + CR
    + CR
    + "\tdm_e.state.hand = [CardData.from_dict(dm_mom.to_dict())," + CR
    + CR
    + "\t\t\tCardData.from_dict(dm_fx.to_dict()), CardData.from_dict(dm_fx2.to_dict())]" + CR
    + CR
    + "\tdm_e.state.energy = 9" + CR
    + CR
    + "\tdm_e.play_from_hand(0, Vector2i(3, 1))" + CR
    + CR
    + "\tvar dm_l := dm_e.state.unit_at(Vector2i(3, 0))" + CR
    + CR
    + "\tvar dm_r := dm_e.state.unit_at(Vector2i(3, 2))" + CR
    + CR
    + "\tcheck(dm_l != null and dm_l.card.id == 9251 and dm_r != null and dm_r.card.id == 9251," + CR
    + CR
    + '\t\t\t"R692 鸭妈妈：上场时左右各召唤一只小鸭")' + CR
    + CR
    + "\t# ② 小鸭入场：手卡里两张效果卡的总减费 = 2（每只各 -1，可能叠到同一张）" + CR
    + CR
    + "\tvar dm_cut := 0" + CR
    + CR
    + "\tfor dm_hc: CardData in dm_e.state.hand:" + CR
    + CR
    + "\t\tif dm_hc.is_effect():" + CR
    + CR
    + "\t\t\tdm_cut += int(dm_e.state.hand_cost_delta.get(dm_hc, 0))" + CR
    + CR
    + '\tcheck(dm_cut == 2, "R692 小鸭：两只各使手卡随机一张效果卡 -1（合计 %d）" % dm_cut)' + CR
    + CR
    + "\t# ③ 最左列：越界那侧跳过，只召唤右边" + CR
    + CR
    + "\tvar dm_e2 := _new_engine([], 20, 20, -1, false)" + CR
    + CR
    + "\tdm_e2.start_game(0)" + CR
    + CR
    + "\tdm_e2.state.hand = [CardData.from_dict(dm_mom.to_dict())]" + CR
    + CR
    + "\tdm_e2.state.energy = 9" + CR
    + CR
    + "\tdm_e2.play_from_hand(0, Vector2i(3, 0))" + CR
    + CR
    + "\tcheck(dm_e2.state.unit_at(Vector2i(3, 1)) != null" + CR
    + CR
    + "\t\t\tand dm_e2.state.unit_at(Vector2i(3, 1)).card.id == 9251," + CR
    + CR
    + '\t\t\t"R692 鸭妈妈：站在最左列 → 只召唤右边一只（越界那侧不替补）")' + CR
    + CR
    + "\t# ④ 一侧已被占：只召唤空的那侧" + CR
    + CR
    + "\tvar dm_e3 := _new_engine([], 20, 20, -1, false)" + CR
    + CR
    + "\tdm_e3.start_game(0)" + CR
    + CR
    + '\tdm_e3.state.place(_card(8003, "农民", "盟友", 3, 3, 8), Vector2i(3, 0),' + CR
    + CR
    + "\t\t\tGameEngine.SIDE_SELF)" + CR
    + CR
    + "\tdm_e3.state.hand = [CardData.from_dict(dm_mom.to_dict())]" + CR
    + CR
    + "\tdm_e3.state.energy = 9" + CR
    + CR
    + "\tdm_e3.play_from_hand(0, Vector2i(3, 1))" + CR
    + CR
    + "\tcheck(dm_e3.state.unit_at(Vector2i(3, 2)) != null" + CR
    + CR
    + "\t\t\tand dm_e3.state.unit_at(Vector2i(3, 2)).card.id == 9251" + CR
    + CR
    + "\t\t\tand dm_e3.state.unit_at(Vector2i(3, 0)).card.id == 8003," + CR
    + CR
    + '\t\t\t"R692 鸭妈妈：左边被己方单位占住 → 只补右边，不覆盖原单位")' + CR
    + CR
    + "\t# ⑤ 没有效果卡可减：不报错、不落空喊" + CR
    + CR
    + "\tvar dm_e4 := _new_engine([], 20, 20, -1, false)" + CR
    + CR
    + "\tdm_e4.start_game(0)" + CR
    + CR
    + "\tdm_e4.state.hand = [CardData.from_dict(dm_mom.to_dict())]" + CR
    + CR
    + "\tdm_e4.state.energy = 9" + CR
    + CR
    + "\tdm_e4.play_from_hand(0, Vector2i(3, 1))" + CR
    + CR
    + "\tcheck(dm_e4.state.unit_at(Vector2i(3, 0)) != null" + CR
    + CR
    + "\t\t\tand dm_e4.state.hand_cost_delta.is_empty()," + CR
    + CR
    + '\t\t\t"R692 小鸭：手卡没有效果卡 → 减费落空（不报错，场上两只照常）")' + CR
    + CR
    + "\t# ⑥ 文案守卫（R692 店长口径）：卡面不再写「由「…」」来源，也不再复述字段说明" + CR
    + CR
    + "\tvar dm_bad: Array[int] = []" + CR
    + CR
    + "\tfor dm_c: CardData in dm_repo.all_cards():" + CR
    + CR
    + '\t\tif dm_c.effect_text.contains("字段「") or dm_c.effect_text.contains("由「"):' + CR
    + CR
    + "\t\t\tdm_bad.append(dm_c.id)" + CR
    + CR
    + '\tcheck(dm_bad.is_empty(), "R692：所有卡面都不再写「由「…」」来源句 / 「字段「…」」说明（残留 %s）" % str(dm_bad))' + CR
    + CR
    + "\tvar dm_egg: CardData = dm_repo.get_card(9022)" + CR
    + CR
    + '\tcheck(dm_egg.effect_text.contains("我方回合开始时") and not dm_egg.effect_text.contains("回合结束"),' + CR
    + CR
    + '\t\t\t"R692 鸭蛋：文案改为「我方回合开始时若存活」（不再写由生蛋鸭放置 / 次元说明）")' + CR
    + CR
    + '\tcheck(dm_egg.has_affix("次元") and not dm_egg.effect_text.contains("次元"),' + CR
    + CR
    + '\t\t\t"R692 鸭蛋：「次元」只由字段承载，正文不再重复解释")' + CR
)

_echo_tail = (
    "\tcheck(echo_foe_hp == 22," + CR
    + CR
    + '\t\t\t"幽深回响：场上没有敌方单位 → 直击对方 HP（30 → 22，实际 %d）" % echo_foe_hp)'
)
if NEW in out:
    print("  [skip] 新用例 已应用")
else:
    rep(_echo_tail, _echo_tail + NEW, "新用例")

if WRITE:
    open(P, "wb").write(out.replace("\r\n", "\n").replace("\n", "\r\n").encode("utf-8"))
b = open(P, "rb").read()
print("test_engine: CRLF %d / LF %d" % (b.count(b"\r\n"), b.count(b"\n")))

# ── test_assemble（纯 LF）：数据层不再写「字段「次元」…」 ──
rawa = open(PA, "rb").read().decode("utf-8")
assert rawa.count("\r\n") == 0, "test_assemble.gd 应为纯 LF"
outa = rawa
old_a = (
    "\t# 三张传授卡：**显示层**正文只剩一句（用户口径「只需要：从全职业卡池组合一张卡。」）。\n"
    + "\t# 数据层仍保留「字段「次元」：…」这句 —— R411 的源头保真锁认它，\n"
    + "\t# `CardText.clean_meta_notes()` 在显示层整句剥掉（R600 同一套口径：数据权威、显示清洗）。\n"
    + "\t# 两条一起锁，才既不会为了「看着短」把后果从数据里删掉，也不会让玩家在卡面上读到它。\n"
)
new_a = (
    "\t# 三张传授卡：正文只剩一句（用户口径「只需要：从全职业卡池组合一张卡。」）。\n"
    + "\t# R692（店长口径「多余的字段描述文本删除」）：数据层**也**不再写「字段「次元」：…」——\n"
    + "\t# 「次元」由字段本身承载（卡面 glyph + 悬停解释），正文复述一遍属于冗余。\n"
    + "\t# 下面两条锁住「显示层一句 + 数据层不再有那句」。\n"
)
if old_a in outa:
    outa = outa.replace(old_a, new_a)
elif new_a in outa:
    print("  [skip] assemble 注释 已应用")
else:
    raise AssertionError("assemble 注释锚点 0")

old_b = (
    '\t\tcheck(tc.effect_text.contains("字段「次元」"),\n'
    + '\t\t\t\t"R614：%d %s 数据层仍要写明次元后果（R411 源头保真）" % [tid, tc.card_name])'
)
new_b = (
    '\t\tcheck(not tc.effect_text.contains("字段「次元」") and tc.has_affix("次元"),\n'
    + '\t\t\t\t"R692：%d %s 数据层不再复述次元说明，但字段本身必须在" % [tid, tc.card_name])'
)
if old_b in outa:
    outa = outa.replace(old_b, new_b)
elif new_b in outa:
    print("  [skip] assemble 断言 已应用")
else:
    raise AssertionError("assemble 断言锚点 0")

if WRITE:
    open(PA, "wb").write(outa.encode("utf-8"))
print("test_assemble: CRLF %d / LF %d" % (outa.count("\r\n"), outa.count("\n")))
print("WROTE" if WRITE else "DRY-RUN")
