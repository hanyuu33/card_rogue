# -*- coding: utf-8 -*-
"""R689 引擎补丁。

1) 疾风之力 9045：触发点在「盟友登场」之外再加「使用效果卡」→ 抽 `_wind_force_tick()`。
2) 群起攻之 9070：由「接通单位全场可达」改为「用与它接通的其他己方单位的位置发起攻击」。
3) 生命循环 9150：技能→效果卡，一次授予**全体**己方盟友；死亡改为给一张种子。
4) 新卡：种子 9248（回合开始破坏自己换费用 / 随机卡）、被眷顾者 9249（复制抽牌库效果卡打出 + 回费）。
   顺带把「免费打出一张效果卡」抽成唯一口 `_free_effect_play()`（use_effect / 记忆药水 / 被眷顾者共用）。
"""
import sys

WRITE = "--write" in sys.argv

P = "scripts/game_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
assert raw.count("\r\n") == raw.count("\n"), "不是纯 CRLF"
out = raw.replace("\r\n", "\n")


def rep(old, new, tag, count=1):
    global out
    c = out.count(old)
    if c != count:
        raise SystemExit("[%s] 锚点命中 %d 次（预期 %d），拒绝写入" % (tag, c, count))
    out = out.replace(old, new)


# ── ① 常量块：生命循环注释 + 种子 / 被眷顾者 ───────────────────────────────
OLD_CONST = '''# ---- R227：生命循环（9150，森林精魄 · 稀有 · 0 费技能）----
# 选一个**己方盟友** → 它获得字段「次元」「死亡」，并在 Placement 上打 `life_cycle`：
#   * 次元 → **离场即消失**：进消耗区（`void_count`），不进弃牌区
#     （`_destroy` 的己方分支认这个字段，与「离场消失」trait 同路）；
#   * 死亡 → 被破坏时把**一张随机盟友卡**加入手卡（`_deathrattle` 的 `life_cycle` 分支）。
# 随机源 = 本角色奖励池里的盟友卡（与「新生」9148 同口径），走引擎 rng → 回放可复现。
# ⚠️ 「死亡」字段是**通用标记**（幼龙 / 腐化尸鬼 / 捕兽大师等各有死亡，按卡 id 结算）→
#    本卡的效果绝不能用 `has_affix("死亡")` 判，只认 `Placement.life_cycle`。
# ⚠️ 本卡自己是普通技能（无次元字段）→ 用完照常进弃牌区。
const LIFE_CYCLE_ID:= 9150'''

NEW_CONST = '''# ---- R227 → R689：生命循环（9150，森林精魄 · **1 费史诗效果卡**）----
# R689 店长口径：由「0 费技能、选一个己方盟友」改成「**效果卡**，使用时己方所有盟友获得
# 「次元」与「死亡：将一张种子加入手卡」」。机制主体沿用 R227，只换卡种与产出：
#   * 次元 → **离场即消失**：进消耗区（`void_count`），不进弃牌区
#     （`_destroy` 的己方分支认这个字段，与「离场消失」trait 同路）；
#   * 死亡 → 被破坏时把**一张种子**（9248）加入手卡（`_deathrattle` 的 `life_cycle` 分支）。
# ⚠️ 「死亡」字段是**通用标记**（幼龙 / 腐化尸鬼 / 捕兽大师等各有死亡，按卡 id 结算）→
#    本卡的效果绝不能用 `has_affix("死亡")` 判，只认 `Placement.life_cycle`。
# ⚠️ 改成效果卡后**不再有目标选择**：`use_effect()` 不传 target → 一次性授予全场（见
#    `_life_cycle_all()`）；效果区留一张，多张不叠加（卡面已写明）。
const LIFE_CYCLE_ID:= 9150
# R689 种子（9248，森林精魄 · 0 费效果卡 · token，只有生命循环产出）：
# 回合开始时**破坏效果区里的自己**，随机二选一：+1 费用 / 一张随机卡加入手卡。
# 可叠加：效果区几张就各结算一次（卡面写 X）。
const SEED_ID:= 9248
const SEED_TRAIT:= "种子"
# R689 被眷顾者（9249，森林精魄 · 3 费史诗技能）：
# 随机把抽牌库一张效果卡的**复制**打出（原卡留在抽牌库），再回复等于抽牌库里效果卡张数的费用。
const BLESSED_ID:= 9249'''
rep(OLD_CONST, NEW_CONST, "常量块")

# ── ② attack_distance：接通位置 ───────────────────────────────────────────
OLD_AD = '''	if card == null or not _rally_active(side):
		return manhattan(from, to)
	# 群起攻之（新效果）：接通单位攻击不计算距离 → 全场可达
	if card.traits.has(CHARGE_TRAIT):
		if card.attack_range > 0:
			return 0
		return manhattan(from, to)
	return manhattan(from, to)'''
NEW_AD = '''	if card == null or not _rally_active(side):
		return manhattan(from, to)
	# 群起攻之（R689 店长口径）：**接通的己方单位可以拿与它接通的其他己方单位的位置发起攻击**。
	# * 「接通」= `_component_of_cell()` 的四方向连通（隔敌也算连通，与充电装置 / 护盾生成器同源）；
	# * 只认**己方**格子 —— 分量里隔着敌人时，那个敌方格子不能当发射点；
	# * 取分量内所有己方格子到目标的**最短**曼哈顿距离：任一个接通位置够得着就算够得着；
	# * 自身格子也在分量里，所以结果恒 ≤ manhattan(from, to)，孤立单位行为与没有本卡一致；
	# * R689 起**不再要求卡面自带「接通」trait**：旧口径只对 8041/8042/8043 三张机械之心生效，
	#   而本卡是森林精魄的，实际永远够不着人（用户实测口径反过来）。
	var best:= manhattan(from, to)
	for c: Vector2i in _component_of_cell(from):
		var q: Placement = state.unit_at(c)
		if q == null or q.owner != side:
			continue
		best = mini(best, manhattan(c, to))
	return best'''
rep(OLD_AD, NEW_AD, "attack_distance")

# ── ③ 生命循环：技能 → 效果卡（全体授予 + 种子） ─────────────────────────
OLD_LC = '''func _life_cycle(target, side:= SIDE_SELF) -> String:
	## 生命循环（9150，R227）：选一个**己方盟友** → 获得字段「次元」「死亡」。
	## 只认 `kind == "盟友"`（工事不是「盟友」，与森林守护 / 狂暴同口径）；
	## 重复施放同一个目标 → 直接返回提示，不重复挂（0 费，避免玩家白点也没变化）。
	var p:= _target_placement(side, target)
	if p == null or p.owner != side:
		return "（需要指定一个己方盟友）"
	if p.card.kind != "盟友":
		return "生命循环：只能指定己方盟友（%s 不是盟友）" % p.card.card_name
	if p.life_cycle:
		return "「%s」已经获得生命循环" % p.card.card_name
	for lc_a: String in [AFFIX_DIMENSION, AFFIX_DEATH]:
		if p.card.add_affix(lc_a):
			p.life_cycle_added.append(lc_a)
	p.life_cycle = true
	_log("生命循环：%s 获得「次元」与「死亡」（被破坏时加一张随机盟友卡到手卡）"
			% p.card.card_name)
	action.emit("life_cycle_grant", {"cell": _cell_of(p), "card": p.card, "side": side})
	return "%s 获得「次元」+「死亡」" % p.card.card_name


func _life_cycle_death(p: Placement, cell: Vector2i) -> void :
	## 生命循环的「死亡」：被破坏时把**一张随机盟友卡**加入手卡。
	## 随机源 = 本角色奖励池里的盟友卡（与「新生」9148 同口径，走引擎 rng）；
	## 池里一张盟友都没有 → 退到全部玩家盟友卡；仍为空 → 只打日志。
	## 手牌满 → 这张卡不进来（与其它「加入手卡」同口径：不静默丢，写清楚）。
	if p.owner != SIDE_SELF:
		return                     # 只有玩家能施放本卡，敌方分支不需要效果
	var c:= _random_ally_card(p.owner)
	if c == null:
		_log("生命循环：卡池里没有盟友卡可加入手卡")
		return
	var copy:= CardData.from_dict(c.to_dict())
	copy.affixes = (c.affixes as Array).duplicate()
	# R299：手牌满 → 直接进弃牌区（死亡不再因为满手白掉）
	_grant_to_hand(copy, "生命循环")
	_log("生命循环：%s 被破坏 → 手卡加入「%s」" % [p.card.card_name, copy.card_name])
	action.emit("life_cycle", {"card": copy, "from": p.card, "cell": cell})'''

NEW_LC = '''func _life_cycle_all(side:= SIDE_SELF) -> void :
	## 生命循环（9150，R689 起是 1 费史诗**效果卡**）：使用时，己方**所有盟友**获得
	## 「次元」+「死亡」，并在 Placement 上打 `life_cycle` 标记。
	## * 只认 `kind == "盟友"`（工事不是「盟友」，与森林守护 / 狂暴同口径）；
	## * 已经挂过的不重复挂（`life_cycle` 为真就跳过）—— 第二张效果卡不该白刷一遍字段；
	## * 「死亡」给的是**一张种子**（9248），不再是随机盟友卡（R689 改动）。
	if side != SIDE_SELF:
		return                     # 只有玩家能施放本卡
	var n:= 0
	for cell: Vector2i in _side_cells(side):
		var p: Placement = state.board[cell]
		if p.card.kind != "盟友" or p.life_cycle:
			continue
		for lc_a: String in [AFFIX_DIMENSION, AFFIX_DEATH]:
			if p.card.add_affix(lc_a):
				p.life_cycle_added.append(lc_a)
		p.life_cycle = true
		n += 1
		action.emit("life_cycle_grant", {"cell": cell, "card": p.card, "side": side})
	if n <= 0:
		_log("生命循环：场上没有未获得过的己方盟友，只留下效果区这一张")
		return
	_log("生命循环：%d 个己方盟友获得「次元」与「死亡」（被破坏时加一张种子到手卡）" % n)


func _life_cycle_death(p: Placement, cell: Vector2i) -> void :
	## 生命循环的「死亡」：被破坏时把**一张种子**（9248）加入手卡。
	## 手牌满 → 走 `_grant_to_hand()` 的统一口径（进弃牌区，不静默蒸发）。
	if p.owner != SIDE_SELF:
		return                     # 只有玩家能施放本卡，敌方分支不需要效果
	var repo:= CardRepo.load_json()
	var base: CardData = repo.get_card(SEED_ID)
	if base == null:
		_log("生命循环：卡库里缺少种子（%d）" % SEED_ID)
		return
	var copy:= CardData.from_dict(base.to_dict())
	copy.affixes = (base.affixes as Array).duplicate()
	_grant_to_hand(copy, "生命循环")
	_log("生命循环：%s 被破坏 → 手卡加入「%s」" % [p.card.card_name, copy.card_name])
	action.emit("life_cycle", {"card": copy, "from": p.card, "cell": cell})'''
rep(OLD_LC, NEW_LC, "生命循环函数")

# dispatch：生命循环不再是技能 → 分支改成被眷顾者
OLD_DISP = '''		LIFE_CYCLE_ID:
			# 生命循环 9150（R227，森林精魄）：己方盟友获得「次元」+「死亡」。
			return _life_cycle(target, side)'''
NEW_DISP = '''		BLESSED_ID:
			# 被眷顾者 9249（R689，森林精魄 3 费史诗技能）：
			# 复制抽牌库一张效果卡打出 + 回复等于抽牌库效果卡张数的费用。
			return _blessed_one(side)'''
rep(OLD_DISP, NEW_DISP, "dispatch")

# ── ④ _on_ally_entered：疾风之力改走 tick ────────────────────────────────
OLD_ENTER = '''	if p.card.kind != "盟友":
		return
	var dmg:= _wind_force_dmg(side)
	if dmg <= 0:
		return
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var targets: Array[Vector2i] = []
	for c: Vector2i in state.board:
		if state.board[c].owner == foe:
			targets.append(c)
	targets.sort()
	if targets.is_empty():
		_log("疾风之力：%s 登场 → 场上没有敌方单位，直击敌方 HP %d 点" % [p.card.card_name, dmg])
		_damage_player(foe, dmg, "疾风之力")
		return
	var t: Vector2i = targets[rng.randi() % targets.size()]
	var q: Placement = state.unit_at(t)
	var dealt:= _hit_unit(q, dmg, "疾风之力")
	_log("疾风之力：%s 登场 → %s -%d（剩余 %d）" % [
		p.card.card_name, q.card.card_name, dealt, maxi(0, q.health)])
	if q.health <= 0:
		_destroy_dead()'''
NEW_ENTER = '''	if p.card.kind != "盟友":
		return
	_wind_force_tick(side, "%s 登场" % p.card.card_name)'''
rep(OLD_ENTER, NEW_ENTER, "盟友入场")

OLD_WFD = '''func _wind_force_dmg(side: String) -> int:
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(WIND_FORCE_TRAIT):
			return maxi(WIND_FORCE_DMG, c.value)
	return 0'''
NEW_WFD = '''func _wind_force_dmg(side: String) -> int:
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	for c: CardData in zone:
		if c.traits.has(WIND_FORCE_TRAIT):
			return maxi(WIND_FORCE_DMG, c.value)
	return 0


func _wind_force_tick(side: String, reason: String) -> void :
	## 疾风之力（9045，R689 店长口径）：**己方盟友进入战场时** 或 **使用效果卡时**，
	## 随机对一个敌人造成 `value`（现为 4）点伤害。
	## * 两个触发点共用这一份：`_on_ally_entered()`（reason = 「X 登场」）与
	##   `_on_effect_card_played()`（reason = 「使用效果卡」）；
	## * 效果区没有这张卡 → `_wind_force_dmg()` 返回 0，直接返回；
	## * 场上没有敌方单位 → 直击敌方 HP（与幽深回响 / 飓风咆哮同口径，不吞伤害）；
	## * 候选格先 `sort()` 再走引擎 rng → 同种子回放可复现。
	var dmg:= _wind_force_dmg(side)
	if dmg <= 0:
		return
	var foe:= SIDE_OPPONENT if side == SIDE_SELF else SIDE_SELF
	var targets: Array[Vector2i] = []
	for c: Vector2i in state.board:
		if state.board[c].owner == foe:
			targets.append(c)
	targets.sort()
	if targets.is_empty():
		_log("疾风之力：%s → 场上没有敌方单位，直击敌方 HP %d 点" % [reason, dmg])
		_damage_player(foe, dmg, "疾风之力")
		return
	var t: Vector2i = targets[rng.randi() % targets.size()]
	var q: Placement = state.unit_at(t)
	var dealt:= _hit_unit(q, dmg, "疾风之力")
	_log("疾风之力：%s → %s -%d（剩余 %d）" % [
		reason, q.card.card_name, dealt, maxi(0, q.health)])
	if q.health <= 0:
		_destroy_dead()'''
rep(OLD_WFD, NEW_WFD, "_wind_force_tick")

# ── ⑤ 效果卡打出钩子：疾风之力的第二个触发点 ─────────────────────────────
OLD_HOOK = '''	var nest_n:= _trait_copies(zone, DUCK_NEST_TRAIT)
	if nest_n > 0 and plays <= nest_n:
		_egg_to_hand("鸭窝（本回合第 %d 次效果牌）" % plays)'''
NEW_HOOK = '''	var nest_n:= _trait_copies(zone, DUCK_NEST_TRAIT)
	if nest_n > 0 and plays <= nest_n:
		_egg_to_hand("鸭窝（本回合第 %d 次效果牌）" % plays)
	# 疾风之力（9045，R689）：触发源由「己方盟友进入战场」再扩一条「使用效果卡」。
	# ⚠️ 本函数在 `use_effect()` / `_free_effect_play()` 的 `append` **之前**被调 →
	#    打出疾风之力自己时它还不算在效果区，不会自己触发自己（与镜像 / 威慑同口径）。
	_wind_force_tick(side, "使用效果卡")'''
rep(OLD_HOOK, NEW_HOOK, "效果卡钩子")

# ── ⑥ use_effect 主体 → _free_effect_play 唯一口 ─────────────────────────
OLD_UE = '''	var card:= state.hand[hand_index]
	var cap_msg:= _play_cap_blocked()
	if cap_msg != "":
		return cap_msg
	_pay(card)

	state.self_next_effect_reduction = 0
	state.hand.remove_at(hand_index)
	state.self_effect_plays += 1
	_on_effect_card_played(SIDE_SELF, card)
	_on_turn_first_play(SIDE_SELF, card)
	# R504：致命**不可叠加**（用户口径）—— 效果区已经有一张时，第二张不再入区。
	# 与恐惧化身 9230 的「可叠加」正好相对：那张用 `_zone_count()` 按张数叠，这张用 `_zone_has()` 只认有没有。
	# ⚠️ 判在 `append` **之前**：进去了就成两张，界面也会画两张。
	if card.id == FATAL_ID and _zone_has(state.effects, FATAL_TRAIT):
		_log("致命：效果区已经有这一条了，不叠加")
		action.emit("effect_no_stack", {"card": card, "trait": FATAL_TRAIT})
		return "致命（已经生效，不叠加）"
	state.effects.append(card)
	_note_card_played(SIDE_SELF, card)

	if card.traits.has(STONESKIN_TRAIT):
		_stoneskin_left += maxi(1, card.value)
		_log("石肤：己方 HP 接下来 %d 次伤害变为 1（累计剩余 %d 次）" % [
			maxi(1, card.value), _stoneskin_left])
		action.emit("stoneskin", {"left": _stoneskin_left, "add": maxi(1, card.value)})

	if card.traits.has(DUCK_NEST_TRAIT):
		_egg_to_hand("鸭窝")

	# R581 致命 9226：若无标记，随机标一个格子（引擎排除己方 HP 行，卡面不写这条限定）；
	# R504 恐惧化身 9230：若无标记，仍随机标一个敌人所在格（口径一字未改）。
	if card.id == FATAL_ID:
		_auto_mark_if_none("致命", true)
	if card.id == FEAR_INCARNATE_ID:
		# 恐惧化身本身没有「打出时」的加成（效果常驻效果区），只处理这一条。
		_auto_mark_if_none("恐惧化身")
	# R465 折射炮 9211：打出时把一张「聚能炮击」加入手卡（此后每发炮击都会折射）。
	if card.id == REFRACT_CANNON_ID:
		_refract_grant_cannon()
	_log("启用效果卡 %s（效果区持续生效）" % card.card_name)

	state.apply_extra_actions(SIDE_SELF)
	action.emit("effect", {"card": card})
	return "%s 生效中" % card.card_name'''

NEW_UE = '''	var card:= state.hand[hand_index]
	var cap_msg:= _play_cap_blocked()
	if cap_msg != "":
		return cap_msg
	_pay(card)

	state.hand.remove_at(hand_index)
	if not _free_effect_play(card, "启用效果卡"):
		return "致命（已经生效，不叠加）"
	return "%s 生效中" % card.card_name


func _free_effect_play(card: CardData, reason: String) -> bool:
	## **免费把一张效果卡走完整生效路径的唯一口**（R689 抽出来，原先在 use_effect 里手写一份、
	## 记忆药水又复刻一份）。三条调用方：
	##   * `use_effect()` —— 玩家从手牌打出（已 `_pay` + 离手，这里只做生效段）；
	##   * 记忆药水 6067 —— 战斗开始从抽牌库自动打一张；
	##   * 被眷顾者 9249 —— 从抽牌库复制一张打出。
	## 省掉的东西：`_pay` / `hand.remove_at` / 小精灵减费（`self_next_effect_reduction` 归零）。
	## 返回 false = 被「不可叠加」拦下（致命 9226），这张卡没有进效果区。
	## ⚠️ `_on_effect_card_played()` 必须在 `append` **之前** —— 幽深回响靠这个顺序把副本
	##    塞进抽牌库，镜像 / 威慑 / 疾风之力也都按「本张还没入区」结算。
	state.self_next_effect_reduction = 0
	state.self_effect_plays += 1
	_on_effect_card_played(SIDE_SELF, card)
	_on_turn_first_play(SIDE_SELF, card)
	# R504：致命**不可叠加**（用户口径）—— 效果区已经有一张时，第二张不再入区。
	# 与恐惧化身 9230 的「可叠加」正好相对：那张用 `_zone_count()` 按张数叠，这张用 `_zone_has()` 只认有没有。
	# ⚠️ 判在 `append` **之前**：进去了就成两张，界面也会画两张。
	if card.id == FATAL_ID and _zone_has(state.effects, FATAL_TRAIT):
		_log("致命：效果区已经有这一条了，不叠加")
		action.emit("effect_no_stack", {"card": card, "trait": FATAL_TRAIT})
		return false
	state.effects.append(card)
	_note_card_played(SIDE_SELF, card)

	if card.traits.has(STONESKIN_TRAIT):
		_stoneskin_left += maxi(1, card.value)
		_log("石肤：己方 HP 接下来 %d 次伤害变为 1（累计剩余 %d 次）" % [
			maxi(1, card.value), _stoneskin_left])
		action.emit("stoneskin", {"left": _stoneskin_left, "add": maxi(1, card.value)})

	if card.traits.has(DUCK_NEST_TRAIT):
		_egg_to_hand("鸭窝")

	# R581 致命 9226：若无标记，随机标一个格子（引擎排除己方 HP 行，卡面不写这条限定）；
	# R504 恐惧化身 9230：若无标记，仍随机标一个敌人所在格（口径一字未改）。
	if card.id == FATAL_ID:
		_auto_mark_if_none("致命", true)
	if card.id == FEAR_INCARNATE_ID:
		# 恐惧化身本身没有「打出时」的加成（效果常驻效果区），只处理这一条。
		_auto_mark_if_none("恐惧化身")
	# R465 折射炮 9211：打出时把一张「聚能炮击」加入手卡（此后每发炮击都会折射）。
	if card.id == REFRACT_CANNON_ID:
		_refract_grant_cannon()
	# R689 生命循环 9150（效果卡）：使用时己方所有盟友获得「次元」+「死亡」。
	if card.id == LIFE_CYCLE_ID:
		_life_cycle_all(SIDE_SELF)
	_log("%s：%s（效果区持续生效）" % [reason, card.card_name])

	state.apply_extra_actions(SIDE_SELF)
	action.emit("effect", {"card": card})
	return true'''
rep(OLD_UE, NEW_UE, "use_effect")

# ── ⑦ 记忆药水改走唯一口 ─────────────────────────────────────────────────
OLD_MP = '''	# 复刻 use_effect 的生效逻辑（跳过 _pay 与 hand.remove_at、不消耗小精灵减费）：
	state.self_next_effect_reduction = 0
	state.self_effect_plays += 1
	_on_effect_card_played(SIDE_SELF, chosen)
	_on_turn_first_play(SIDE_SELF, chosen)
	if chosen.id == FATAL_ID and _zone_has(state.effects, FATAL_TRAIT):
		_log("致命：效果区已经有这一条了，不叠加")
		action.emit("effect_no_stack", {"card": chosen, "trait": FATAL_TRAIT})
		return
	state.effects.append(chosen)
	_note_card_played(SIDE_SELF, chosen)
	if chosen.traits.has(STONESKIN_TRAIT):
		_stoneskin_left += maxi(1, chosen.value)
		_log("石肤：己方 HP 接下来 %d 次伤害变为 1（累计剩余 %d 次）" % [
			maxi(1, chosen.value), _stoneskin_left])
		action.emit("stoneskin", {"left": _stoneskin_left, "add": maxi(1, chosen.value)})
	if chosen.traits.has(DUCK_NEST_TRAIT):
		_egg_to_hand("鸭窝")
	if chosen.id == FATAL_ID:
		_auto_mark_if_none("致命", true)
	if chosen.id == FEAR_INCARNATE_ID:
		_auto_mark_if_none("恐惧化身")
	if chosen.id == REFRACT_CANNON_ID:
		_refract_grant_cannon()
	_log("记忆药水：战斗开始自动打出效果卡「%s」" % chosen.card_name)
	state.apply_extra_actions(SIDE_SELF)
	action.emit("effect", {"card": chosen})
	action.emit("relic", {"id": MEMORY_POTION_RELIC_ID,
		"text": "记忆药水：自动打出「%s」" % chosen.card_name})'''
NEW_MP = '''	# R689：生效段统一走 `_free_effect_play()`（与 use_effect / 被眷顾者同一条路）。
	if not _free_effect_play(chosen, "记忆药水"):
		return
	_log("记忆药水：战斗开始自动打出效果卡「%s」" % chosen.card_name)
	action.emit("relic", {"id": MEMORY_POTION_RELIC_ID,
		"text": "记忆药水：自动打出「%s」" % chosen.card_name})'''
rep(OLD_MP, NEW_MP, "记忆药水")

# ── ⑧ 种子 tick + 被眷顾者：插在 _echo_tick 之后 ─────────────────────────
ANCHOR = '''func _mirror_reflect(side: String, played: CardData) -> void :'''
NEW_FUNCS = '''func _seed_tick(side: String) -> void :
	## 种子（9248，R689）：**回合开始时**破坏效果区里的自己，随机二选一。
	## * X = 效果区里种子的张数 —— 每张各结算一次（卡面「多张可叠加」）；
	## * 「破坏」= 从效果区移除；效果卡没有实体牌位，进不了弃牌区 / 消耗区；
	## * 二选一走引擎 rng → 同种子回放可复现；
	## * 「一张随机卡」= `_random_reward_card()`（本职业奖励池 / 稀有度三等分），
	##   与随心组装 9144 / 库存整理 9184 同源；满手走 `_grant_to_hand()` 的统一口径。
	var zone: Array[CardData] = state.effects if side == SIDE_SELF else state.enemy_effects
	var n:= 0
	for c: CardData in zone:
		if c.id == SEED_ID or c.traits.has(SEED_TRAIT):
			n += 1
	if n <= 0:
		return
	for i in n:
		var target: CardData = null
		for c: CardData in zone:
			if c.id == SEED_ID or c.traits.has(SEED_TRAIT):
				target = c
				break
		if target == null:
			break
		zone.erase(target)
		action.emit("seed_break", {"card": target, "side": side, "index": i + 1, "total": n})
		if rng.randi() % 2 == 0:
			if side == SIDE_SELF:
				state.energy += 1
			else:
				state.opp_energy += 1
			_log("种子：第 %d/%d 张破坏 → 获得 1 点费用（当前 %d）"
					% [i + 1, n, state.energy_of(side)])
			action.emit("seed", {"gain": "energy", "side": side})
		elif side == SIDE_SELF:
			var pick:= _random_reward_card(side)
			if pick == null:
				_log("种子：卡池里没有可加的卡，这一张落空")
				continue
			var copy:= CardData.from_dict(pick.to_dict())
			copy.affixes = (pick.affixes as Array).duplicate()
			_grant_to_hand(copy, "种子")
			_log("种子：第 %d/%d 张破坏 → 手卡加入「%s」" % [i + 1, n, copy.card_name])
			action.emit("seed", {"gain": "card", "card": copy, "side": side})
		else:
			state.opp_deck_count += 1
			_log("种子（敌方）：第 %d/%d 张破坏 → 卡组 +1" % [i + 1, n])


func _blessed_one(side: String) -> String:
	## 被眷顾者（9249，森林精魄 3 费史诗技能 · R689）：
	##   ① 随机挑**抽牌库**里的一张效果卡，**复制**一份并打出（原卡留在抽牌库）；
	##   ② 回复等于「抽牌库里效果卡张数」的费用。
	## * 复制而非取走：卡面写的是「复制」，所以抽牌库张数不变；
	## * 计数取**打出之前**的快照 —— 复制出来的那张若自己是「幽深回响」，会往抽牌库塞副本，
	##   那是它自己的结算，不该算进本次回费（顺序：先取数 → 再打出 → 最后回费）；
	## * 抽牌库里没有效果卡 → 整件事落空（与记忆药水「没有效果卡就跳过」同口径），日志写清楚；
	## * 打出走 `_free_effect_play()`（与记忆药水 / use_effect 同一条免费生效路径）。
	if side != SIDE_SELF:
		return "被眷顾者：只对己方生效"
	var cand: Array[int] = []
	for i in state.deck.size():
		if state.deck[i].is_effect():
			cand.append(i)
	if cand.is_empty():
		_log("被眷顾者：抽牌库里没有效果卡，效果落空")
		return "抽牌库里没有效果卡"
	var refund:= cand.size()
	var pick: int = cand[rng.randi() % cand.size()]
	var base: CardData = state.deck[pick]
	var copy:= CardData.from_dict(base.to_dict())
	copy.affixes = (base.affixes as Array).duplicate()
	copy.own_copy = true
	_log("被眷顾者：抽牌库随机取「%s」的复制并打出（抽牌库 %d 张 / 效果卡 %d 张）"
			% [copy.card_name, state.deck.size(), refund])
	_free_effect_play(copy, "被眷顾者")
	state.energy += refund
	_log("被眷顾者：回复 %d 点费用（当前 %d）" % [refund, state.energy])
	action.emit("blessed", {"card": copy, "refund": refund})
	return "复制打出「%s」，回复 %d 点费用" % [copy.card_name, refund]


func _mirror_reflect(side: String, played: CardData) -> void :'''
rep(ANCHOR, NEW_FUNCS, "新函数")

# ── ⑨ 回合开始挂种子 ────────────────────────────────────────────────────
rep('''		_echo_tick(SIDE_SELF)            # 幽深回响 9002（R688）：效果区几张就打几下''',
    '''		_echo_tick(SIDE_SELF)            # 幽深回响 9002（R688）：效果区几张就打几下
		_seed_tick(SIDE_SELF)            # 种子 9248（R689）：回合开始破坏几张种子、各换 1 费 / 1 张卡''',
    "回合开始(己方)")
rep('''		_echo_tick(SIDE_OPPONENT)        # 幽深回响 9002（R688，对称保留）''',
    '''		_echo_tick(SIDE_OPPONENT)        # 幽深回响 9002（R688，对称保留）
		_seed_tick(SIDE_OPPONENT)        # 种子 9248（R689，对称保留：敌方无真实手牌 → 记卡组 +1）''',
    "回合开始(敌方)")

if WRITE:
    open(P, "wb").write(out.replace("\n", "\r\n").encode("utf-8"))
    b = open(P, "rb").read()
    print("写入 %s CRLF=%d LF=%d stray=%d" % (P, b.count(b"\r\n"), b.count(b"\n"),
                                             b.count(b"\r") - b.count(b"\r\n")))
    for k in ("_free_effect_play", "_wind_force_tick", "_seed_tick", "_blessed_one", "_life_cycle_all"):
        print("  %s ×%d" % (k, b.decode("utf-8").count(k)))
else:
    print("干跑通过（未写入）")
