# -*- coding: utf-8 -*-
"""R846 引擎改动（game_engine.gd / CRLF）。

全部用 exact-replace + 命中数断言，改完统一把 LF 还原成 CRLF。
"""
import io

P = "scripts/game_engine.gd"
EDITS = []


def add(old, new):
    EDITS.append((old, new))


# ─────────────────────────────────────────────────────────────
# 1) 删掉闪躲的「全员嘲讽窗口」（R846 起没人再置 true）
# ─────────────────────────────────────────────────────────────
add("""# 闪躲（9103）：本回合（直到自己**下个回合开始**，覆盖中间的敌方回合）所有友方单位获得嘲讽。
# 用法：施放时置 true；_begin_turn(SIDE_SELF) 时清 false。嘲讽判定走 unit_has_taunt()，
# 所以后上场的单位也会实时获得（不是一次性快照）。
var _taunt_all_active:= false
""", "")

add("""	## 场上某单位**当前**是否视为「嘲讽」= 卡面自带嘲讽（traits / affixes） OR
	## （闪躲 9103 的全员嘲讽窗口内 && 是我方单位）。引擎内嘲讽判定统一走这里，
	## 界面也走它（GameEngine.unit_has_taunt）—— 闪躲窗口内后上场的单位实时生效。
	if p == null:
		return false
	return card_has_taunt(p.card) or (_taunt_all_active and p.owner == SIDE_SELF)
""", """	## 场上某单位**当前**是否视为「嘲讽」= 卡面自带嘲讽（traits / affixes）。
	## 引擎内嘲讽判定统一走这里，界面也走它（GameEngine.unit_has_taunt）。
	## ⚠️ R846：闪躲 9103 改成「敌方单位降力」后，原「全员嘲讽窗口」(`_taunt_all_active`)
	##    整条删除 —— 嘲讽只剩卡面这一个来源，别再在判定里开第二个口子。
	if p == null:
		return false
	return card_has_taunt(p.card)
""")

add("""		_aether_left = 0
		_taunt_all_active = false   # 闪躲（9103）：含敌方回合在内的一整个来回结束 → 到期
""", """		_aether_left = 0
""")

add("""func taunt_all_active(side:= SIDE_SELF) -> bool:
	## 闪躲（9103）「全员嘲讽」窗口是否生效（直到自己下个回合开始）。
	return side == SIDE_SELF and _taunt_all_active


""", "")

# ─────────────────────────────────────────────────────────────
# 2) 回转 9089 / 影子猫 8006 常量
# ─────────────────────────────────────────────────────────────
add("""# 回转（9089 技能）：2 费；抽 X 张（X = 本回合已用卡牌数），这些牌本回合结束不弃（state.turn_keep）。
const SPIN_DRAW_ID:= 9089
# 影子猫（8006 盟友）：打出时，含此卡本回合已打出 ≥3 张 → 卡组随机技能卡入手。
const SHADOW_CAT_ID:= 8006
const SHADOW_CAT_NEED:= 3
""", """# 回转（9089 技能，R846 用户口径）：2 费；**对一个目标造成 X 伤 + 抽 X 张**
#   （X = 本回合**其他**卡的使用张数），抽到的牌本回合结束不弃（state.turn_keep）。
const SPIN_DRAW_ID:= 9089
# 影子猫（8006 盟友，R846 用户口径）：打出时，若本回合已使用过 SHADOW_CAT_NEED 张**其他**卡
#   → 抽 SHADOW_CAT_DRAW 张。移速 5 → 2 只是数据（cards.json），引擎不读。
#   ⚠️ 「其他卡」判据 = `self_card_plays`：影子猫的入场钩子跑在 `_note_card_played()` **之前**
#      （见 `_play_from_hand_body`），这个计数器天然不含它自己 —— 不要再 +1。
const SHADOW_CAT_ID:= 8006
const SHADOW_CAT_NEED:= 3
const SHADOW_CAT_DRAW:= 2
""")

# ─────────────────────────────────────────────────────────────
# 3) 闪躲 9103 常量注释
# ─────────────────────────────────────────────────────────────
add("""# 闪躲（9103 技能）：0 费普通；直到自己下个回合开始，自己受到的 HP 伤害改由
#   **随机一个己方盟友**（kind == "盟友"）代受；该盟友生命不足 → 只吃掉它剩余的生命
#   （随即被破坏），超出部分照旧由自己承担。判定挂在 _damage_player（玩家 HP 伤害的唯一入口）。
const DODGE_ID:= 9103
""", """# 闪躲（9103 技能，R846 用户口径）：0 费**稀有**；**使一个敌方单位力量 -X**，
#   X = 你本回合打出的牌数（`self_card_plays`，自身不计入 —— 结算时本卡还没记账，
#   与终结 9086 的 X 同口径）。降力与敲晕 9088 / 威慑同源（atk_debuff + debuff_stage=1，
#   到它自己回合结束清除）；必须指定**敌方单位**，没有目标就落空。
#   ⚠️ R48~R845 那版「自己受伤转给随机盟友代受 / 全员嘲讽窗口」整条删除，别再加回来。
const DODGE_ID:= 9103
""")

# ─────────────────────────────────────────────────────────────
# 4) 回转 / 闪躲 / 影子猫：实现
# ─────────────────────────────────────────────────────────────
add("""		SPIN_DRAW_ID:
			if side != SIDE_SELF:
				return "（回转：敌方 AI 不使用这张卡）"
			var sp_n := state.self_card_plays
			var sp_got := 0
			for sp_i in sp_n:
				var sp_c: CardData = _assemble_draw_one()
				if sp_c == null:
					break
				if not state.turn_keep.has(sp_c):
					state.turn_keep.append(sp_c)
				sp_got += 1
			_log("回转：本回合已用 %d 张 → 抽 %d 张（本回合结束不丢弃）" % [sp_n, sp_got])
			return "抽了 %d 张牌（本回合不丢弃）" % sp_got
""", """		SPIN_DRAW_ID:
			# R846（用户口径）：先对一个目标造成 X 伤，再抽 X 张（X = 本回合**其他**卡张数），
			# 抽到的牌本回合结束不丢弃。顺序是「先伤后抽」：伤害走 _spell_dmg（吃技能加成），
			# 抽牌走 _assemble_draw_one（手牌满即停，与批量传输 / 起手式同口径）。
			if side != SIDE_SELF:
				return "（回转：敌方 AI 不使用这张卡）"
			if _target_placement(side, target) == null:
				return "（回转：需要指定一个目标）"
			var sp_n := state.self_card_plays
			var sp_msg := ""
			if sp_n > 0:
				sp_msg = _op_deal_damage(side, _spell_dmg(side, sp_n, card), target)
			var sp_got := 0
			for sp_i in sp_n:
				var sp_c: CardData = _assemble_draw_one()
				if sp_c == null:
					break
				if not state.turn_keep.has(sp_c):
					state.turn_keep.append(sp_c)
				sp_got += 1
			_log("回转：本回合已用 %d 张其他卡 → %s；抽 %d 张（本回合结束不丢弃）" % [
					sp_n, sp_msg, sp_got])
			return "%s；抽了 %d 张牌（本回合不丢弃）" % [sp_msg, sp_got]
""")

add("""func _dodge_spell(side: String) -> String:
	## 闪躲（9103）：置起「全员嘲讽」窗口。窗口一直开到**自己下个回合开始**
	## （_begin_turn(SIDE_SELF) 清掉）—— 覆盖了中间的敌方回合，否则这张卡在自己回合里
	## 几乎没有意义（嘲讽只在敌方回合攻击时才会改变目标选择）。
	if side != SIDE_SELF:
		return "（闪躲：敌方 AI 不使用这张卡）"
	_taunt_all_active = true
	_log("闪躲：本回合所有友方单位获得嘲讽")
	action.emit("dodge", {"active": true})
	return "本回合所有友方单位获得嘲讽"
""", """func _dodge_spell(side: String, card: CardData, target) -> String:
	## 闪躲（9103，R846 用户口径）：0 费稀有；**使一个敌方单位力量 -X**，
	##   X = 本回合该方已打出的牌数（`self_card_plays` / `opp_card_plays`）。
	##   * 自身不计入：结算走到这里时本卡还没经 `_note_card_played` 记账（与终结 9086 同口径）；
	##   * 降力与敲晕 9088 / 威慑同源（atk_debuff + debuff_stage=1，它所属方回合结束清除）；
	##   * 必须指定**敌方单位**：指到自家单位 / 空格 → 落空，不白降。
	##   ⚠️ 别在这里重新加「全员嘲讽」：那条机制 R846 已整条删除（见 unit_has_taunt 注释）。
	if side != SIDE_SELF:
		return "（闪躲：敌方 AI 不使用这张卡）"
	var dp: Placement = _target_placement(side, target)
	if dp == null or dp.owner == side:
		return "（闪躲：需要指定一个敌方单位）"
	var plays: int = state.self_card_plays
	if plays <= 0:
		_log("闪躲：本回合还没打出过别的卡 → %s 力量不变" % dp.card.card_name)
		return "（闪躲：本回合还没打出别的卡 → 力量不变）"
	dp.atk_debuff += plays
	dp.debuff_stage = 1
	_log("闪躲：本回合已打出 %d 张 → %s 力量 -%d（当前 %d），持续到它的回合结束" % [
			plays, dp.card.card_name, plays, dp.effective_power()])
	action.emit("dodge", {"cell": _cell_of(dp), "card": dp.card, "amount": plays,
			"power": dp.effective_power()})
	return "%s 力量 -%d" % [dp.card.card_name, plays]
""")

add("""		DODGE_ID:
			return _dodge_spell(side)
""", """		DODGE_ID:
			return _dodge_spell(side, card, target)
""")

add("""func _shadow_cat_trigger() -> void:
	## 影子猫（8006）打出时：包含这张卡，本回合已打出的卡达到 3 张
	## → 从卡组把一张随机技能卡加入手卡（打出自己也算第 N 张）。
	if state.self_card_plays + 1 >= SHADOW_CAT_NEED:
		var c := _fetch_skill_from_deck(0)
		_log("影子猫：含此卡本回合第 %d 张 → %s" % [state.self_card_plays + 1,
				("卡组随机技能卡「%s」加入手卡" % c.card_name) if c != null else "卡组里没有技能卡"])
		action.emit("shadow_cat", {"card": c})
	else:
		_log("影子猫：含此卡本回合只打了 %d 张（不足 %d）→ 效果落空" % [
				state.self_card_plays + 1, SHADOW_CAT_NEED])
		action.emit("shadow_cat", {"card": null})
""", """func _shadow_cat_trigger() -> void:
	## 影子猫（8006，R846 用户口径）打出时：若本回合**已经使用过** SHADOW_CAT_NEED 张**其他**卡
	## → 抽 SHADOW_CAT_DRAW 张。
	##   * 判据 `self_card_plays`：这个钩子在 `_play_from_hand_body` 里跑，**先于**
	##     `_note_card_played()` → 计数器里只有「这张之前」的卡，正好就是「其他卡」；
	##   * 抽牌走 `_draw_many`（手牌满即停），与起手式 9119 / 批量传输 8040 同口径。
	var plays: int = state.self_card_plays
	if plays >= SHADOW_CAT_NEED:
		var got := _draw_many(SHADOW_CAT_DRAW)
		_log("影子猫：本回合已用 %d 张其他卡（满 %d）→ 抽 %d 张" % [
				plays, SHADOW_CAT_NEED, got])
		action.emit("shadow_cat", {"draw": got, "plays": plays})
	else:
		_log("影子猫：本回合只用了 %d 张其他卡（不足 %d）→ 效果落空" % [plays, SHADOW_CAT_NEED])
		action.emit("shadow_cat", {"draw": 0, "plays": plays})
""")

# ─────────────────────────────────────────────────────────────
# 5) 噩兆 9231：打出时若无标记 → 随机标记一个格子
# ─────────────────────────────────────────────────────────────
add("""	if card.id == FEAR_INCARNATE_ID:
		# 恐惧化身本身没有「打出时」的加成（效果常驻效果区），只处理这一条。
		_auto_mark_if_none("恐惧化身")
""", """	if card.id == FEAR_INCARNATE_ID:
		# 恐惧化身本身没有「打出时」的加成（效果常驻效果区），只处理这一条。
		_auto_mark_if_none("恐惧化身")
	# R846 噩兆 9231（用户口径）：使用时若场上没有标记 → 随机标记一个格子。
	# 口径与致命 9226 完全一致（`any_cell = true`：候选是整块棋盘，只排除己方 HP 行）；
	# 已有标记时什么都不做，别挪走玩家/前一张卡放好的那一格。
	if card.id == OMEN_ID:
		_auto_mark_if_none("噩兆", true)
""")

# ─────────────────────────────────────────────────────────────
# 6) 暗影之刃 9111：X 从「已花费用」改成「已使用卡牌张数」
# ─────────────────────────────────────────────────────────────
add("""# 暗影之刃 9111（2 费稀有效果卡）：回合结束时对**随机一个敌人**造成
#   DARK_BLADE_SPENT_MULT(1) × 本回合**已花掉**的费用数 点伤害。
#   X 读 FieldState.self_energy_spent / opp_energy_spent（由 pay_energy 唯一记账，
#   回合开始清零）—— 与「剩余费用」口径相反：这张卡奖励的是**花钱**而不是攒钱。
#   效果区多张不叠加（取一张）。
""", """# 暗影之刃 9111（2 费稀有效果卡）：回合结束时对**随机一个敌人**造成
#   X 点伤害，X = 本回合**已使用的卡牌张数**（R846 用户口径；R56 起原来是「已花掉的费用数」）。
#   X 读 FieldState.self_card_plays / opp_card_plays（出牌唯一收尾口累加，回合开始清零）——
#   结算在回合结束，所以本回合打过的每一张（含这张卡自己）都算。
#   效果区多张不叠加（取一张）。
""")

add("""	if _zone_has(zone, DARK_BLADE_TRAIT):
		var spent := state.energy_spent_of(side)
		if spent <= 0:
			_log("暗影之刃：本回合没有花掉费用 → 效果落空")
		else:
			_blade_strike(side, spent)
""", """	if _zone_has(zone, DARK_BLADE_TRAIT):
		# R846：X = 本回合**已使用的卡牌张数**（不是已花费用了）；回合结束时结算，
		# 所以这一回合打过的每一张都在里面 —— 与费用够不够花完全无关。
		var blade_n: int = state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
		if blade_n <= 0:
			_log("暗影之刃：本回合还没有使用过卡 → 效果落空")
		else:
			_blade_strike(side, blade_n)
""")

add("""	## 暗影之刃（9111，R56）：对**随机一个敌人**造成 dmg 点伤害（dmg = 本回合已花掉的费用）。
""", """	## 暗影之刃（9111，R56 → R846）：对**随机一个敌人**造成 dmg 点伤害
	## （dmg = 本回合已使用的卡牌张数，见 `_end_turn_surplus` 的调用点）。
""")

add("""	_log("暗影之刃：本回合已花 %d 费用 → 随机一个敌人（%s）受到 %d 点伤害"
			% [dmg, src, real])
""", """	_log("暗影之刃：本回合已用 %d 张卡 → 随机一个敌人（%s）受到 %d 点伤害"
			% [dmg, src, real])
""")

# ─────────────────────────────────────────────────────────────
# 7) 组合素材：draw_if_third（影子猫下半句 R846 改版）
# ─────────────────────────────────────────────────────────────
add("""		"draw":
			if p.owner == SIDE_SELF:
				_draw_many(value)
			else:
				_assemble_opponent_draw(value)
""", """		"draw":
			if p.owner == SIDE_SELF:
				_draw_many(value)
			else:
				_assemble_opponent_draw(value)
		"draw_if_third":
			# R846：影子猫 8006 的下半句 —— 本回合**其他**卡已用满 SHADOW_CAT_NEED 张才抽 value 张。
			# 判据与母卡 `_shadow_cat_trigger` 同源（`*_card_plays` 在组合结算时**不含**产物自己）。
			var dft_plays: int = state.self_card_plays if p.owner == SIDE_SELF else state.opp_card_plays
			if dft_plays < SHADOW_CAT_NEED:
				_log("组合：抽牌条件不满足（本回合已用 %d 张其他卡，需 %d 张）" % [
						dft_plays, SHADOW_CAT_NEED])
				return
			if p.owner == SIDE_SELF:
				_draw_many(value)
			else:
				_assemble_opponent_draw(value)
""")

add("""		"fetch_skill":
			# R775：影子猫 / 幽灵「从卡组随机技能卡入手」（无减费）。
			# if_third = 影子猫条件「本回合第 3 张（含本卡）」，判据与母卡 _shadow_cat_trigger 同源。
			if p.owner != SIDE_SELF:
				_assemble_opponent_draw(1)
				return
			if fx.get("if_third", false) and state.self_card_plays + 1 < SHADOW_CAT_NEED:
				_log("组合：影子猫条件不满足（本回合第 %d 张，需 %d 张）" % [state.self_card_plays + 1, SHADOW_CAT_NEED])
				return
			_fetch_skill_from_deck(0)
""", """		"fetch_skill":
			# R775：幽灵 8008「从卡组随机技能卡入手」（无减费）。
			# ⚠️ R846：影子猫 8006 的下半句已改成 `draw_if_third`（抽 2 张），
			#    这里不再有 `if_third` 分支 —— 别再按旧口径判「本回合第 3 张」。
			if p.owner != SIDE_SELF:
				_assemble_opponent_draw(1)
				return
			_fetch_skill_from_deck(0)
""")

# ─────────────────────────────────────────────────────────────
# 8) 猫鼠游戏 5 → 4 费（注释口径）
# ─────────────────────────────────────────────────────────────
add("""	## R580 猫鼠游戏（9190，5 费普通技能）：丢弃所有手牌 → 下回合自己技能伤害 ×2。
""", """	## R580 猫鼠游戏（9190，普通技能；R846 起 5 费 → 4 费）：丢弃所有手牌 →
	## 下回合自己技能伤害 ×2（与其他加算乘算）。
""")


def main():
    raw = io.open(P, "r", encoding="utf-8", newline="").read()
    assert raw.count("\r\n") > 0 and raw.count("\n") == raw.count("\r\n"), "不是纯 CRLF"
    txt = raw.replace("\r\n", "\n")

    for old, new in EDITS:
        n = txt.count(old)
        assert n == 1, "锚点命中 %d 次（应为 1）：\n%s" % (n, old[:120])
        txt = txt.replace(old, new)

    out = txt.replace("\n", "\r\n")
    io.open(P, "w", encoding="utf-8", newline="").write(out)

    # 复核
    body = io.open(P, "r", encoding="utf-8", newline="").read()
    for must in ("const SHADOW_CAT_DRAW:= 2", '"draw_if_third":', "func _dodge_spell(side: String, card: CardData, target)",
                 "var blade_n: int =", "_auto_mark_if_none(\"噩兆\", true)"):
        assert must in body, "缺 %s" % must
    for gone in ("_taunt_all_active", "func taunt_all_active", "const INSTINCT_COUNT"):
        assert gone not in body, "残留 %s" % gone
    print("ENGINE_OK")


if __name__ == "__main__":
    main()
