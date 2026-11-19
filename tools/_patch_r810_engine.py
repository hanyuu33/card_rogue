# -*- coding: utf-8 -*-
"""R810 引擎层：牛顿耳饰 / 太阳指环 / 海妖鱼叉 / 缺陷时钟。"""
import io

P = "E:/work/card_rogue/scripts/game_engine.gd"
s = io.open(P, encoding="utf-8", newline="").read()
CRLF = "\r\n"


def sub(old, new, cnt=1):
    global s
    assert s.count(old) == cnt, (old[:40], s.count(old))
    s = s.replace(old, new)


def blk(text):
    return text.replace("\n", CRLF)


# ---------------- 1. 成员变量 ----------------
sub(blk("""var _scroll_used:= false   # R806 法术卷轴：本场战斗的第一次「用技能卡」是否已发生（每场一次）
"""), blk("""var _scroll_used:= false   # R806 法术卷轴：本场战斗的第一次「用技能卡」是否已发生（每场一次）
## R810 太阳指环（6082）：重入保护。它自己造成伤害 → 若某只敌人被这一下打死、死亡效果
## 又对敌人补了一刀，`_hit_unit` 会再走回本 tick。这个标记保证一次结算不被递归放大。
var _sun_ring_busy:= false
## R810 海妖鱼叉（6083）：同上。自己补的那 HARPOON_DMG 点**不许**再算一次计数，
## 否则「第 3 次 → 补 6 点 → 这一下又算第 4 次」会滚成雪球。
var _harpoon_busy:= false
## R810 缺陷时钟（6084）：本场战斗**已打出的牌数**（只数我方、只数有实体的牌）。
## 每个新 GameEngine = 一场新战斗 → 自然复位，不跨战斗、不进存档。
var _clock_plays:= 0
## R810 缺陷时钟：第 12 张牌已打完 → 等**这一张彻底结算完**再换回合（见 `_clock_maybe_switch`）。
var _clock_pending:= false
"""))

# ---------------- 2. 常量 ----------------
sub(blk("""const SCROLL_RELIC_ID:= 6080
"""), blk("""const SCROLL_RELIC_ID:= 6080
# R810 新月耳饰（6081，一般档）：每 CRESCENT_EVERY 场战斗，在**那场战斗的第一回合**多给 1 点费用。
#   计数（`RunState.crescent_battles`）跨战斗保留、随存档；推进口只有 `_begin_turn` 里
#   `turn_number == 1` 那一次 —— 每场战斗只成立一次，天然「一场 +1」。
#   ⚠️ 别在战斗开始时另加一次：一场会数两下，第 3 场永远轮不到。
const CRESCENT_EARING_ID:= 6081
const CRESCENT_ENERGY:= 1
# R810 太阳指环（6082，一般档）：**每个我方回合开始**，对所有敌方单位各 SUN_RING_DMG 点伤害。
#   与风妖精 6042 同一套写法（`_hit_unit` → `_destroy_dead` → `action` 演出），
#   差别只在触发时机。伤害走 `_hit_unit` → 护盾 / 减伤 / 光环 / 鱼叉计数全部照常生效。
const SUN_RING_ID:= 6082
const SUN_RING_DMG:= 3
# R810 海妖鱼叉（6083，一般档）：**同一回合内**每对一个敌人造成 HARPOON_HITS 次伤害，
#   就对它再补 HARPOON_DMG 点。计数记在**单位自己身上**（`Placement.harpoon_hits` +
#   `harpoon_turn` 当回合钥匙），换回合自动从 0 重算 —— 不必在回合开始扫全场（漏扫一只
#   就是静默错账，同赫尔墨斯 `turn_dmg_key` 的范式）。
const HARPOON_ID:= 6083
const HARPOON_HITS:= 3
const HARPOON_DMG:= 6
# R810 缺陷时钟（6084，**传奇档**）：每场战斗打出第 DEFECT_CLOCK_AT 张牌时，结束当前回合并
#   **跳过敌方回合**，直接开始新的我方回合（`end_turn(true)`）。
#   ⚠️ 触发点不在 `_note_card_played` 里直接换回合 —— 那时这张牌还没彻底结算完
#      （`play_from_hand` 之后还要处理枭熊倒地之类），换回合会把收尾搬到下一回合去。
#      真正的切换在三个公共出牌入口的返回处，见 `_clock_maybe_switch()`。
const DEFECT_CLOCK_ID:= 6084
const DEFECT_CLOCK_AT:= 12
"""))

# ---------------- 3. _begin_turn：新月耳饰 ----------------
sub(blk("""		var earring_energy:= 0
		if self_relics.has(EARRING_RELIC_ID):
			earring_energy = 1
			state.energy += earring_energy
			_log("鸭语耳环：本回合费用 +1")
"""), blk("""		var earring_energy:= 0
		if self_relics.has(EARRING_RELIC_ID):
			earring_energy = 1
			state.energy += earring_energy
			_log("鸭语耳环：本回合费用 +1")

		# R810 新月耳饰（6081）：每 3 场战斗，**在该场第一回合**多给 1 点费用。
		# 推进计数的口只有这里（`turn_number == 1` 每场只成立一次）——
		# 与鸭翼 / 鸭语耳环同一条 `state.energy` 发放口，日志也挨着写。
		if self_relics.has(CRESCENT_EARING_ID) and RunState.crescent_tick():
			state.energy += CRESCENT_ENERGY
			_log("新月耳饰：第 %d 场战斗 → 本回合费用 +%d"
					% [RunState.crescent_battles, CRESCENT_ENERGY])
			action.emit("relic", {"id": CRESCENT_EARING_ID,
					"text": "新月耳饰：每 %d 场战斗，首回合费用 +%d"
							% [RunState.CRESCENT_EVERY, CRESCENT_ENERGY]})
"""))

# ---------------- 4. _begin_turn：太阳指环 ----------------
sub(blk("""		_run_battlecries(SIDE_SELF)
		_log("── 我方第 %d 回合：费用重置为 %d"""), blk("""		_run_battlecries(SIDE_SELF)
		# R810 太阳指环（6082）：**每个我方回合开始**，对所有敌方单位 3 点伤害。
		# 放在召唤 / 成长 / 战吼之后 = 「这一拍已经站在台上的敌人才吃」；
		# 也保证回合头那条总日志之前场内已经稳定（被打死的不会在日志里还挂着）。
		# ⚠️ 打完可能把战斗直接结束 → 立刻 `return`，别让后面的回合头日志写一场已结束的仗。
		_sun_ring_tick()
		if over:
			return
		_log("── 我方第 %d 回合：费用重置为 %d"""))

# ---------------- 5. _hit_unit：海妖鱼叉 ----------------
sub(blk("""	_fear_harvest_tick(p, dmg)
"""), blk("""	_fear_harvest_tick(p, dmg)
	# R810 海妖鱼叉（6083）：与上两条同一处纪律 —— 「打到敌人身上」的记账挂在扣血落地口。
	# ⚠️ 必须在 `p.health -= dmg` **之后**：判「这一下有没有打死」要读扣完的血。
	_harpoon_tick(p, dmg)
"""))

# ---------------- 6. 三个新函数（放在 _inspire_tick 之前）----------------
sub(blk("""func _inspire_tick() -> int:
"""), blk("""func _sun_ring_tick() -> int:
	## R810 太阳指环（6082）：**每个我方回合开始**，对所有敌方单位各 SUN_RING_DMG 点伤害。
	## 与风妖精 6042 逐款同构（伤害走 `_hit_unit`、致死统一交 `_destroy_dead()`、
	## 最后 `action.emit` 让界面演出），差别只有触发时机。
	## ⚠️ 格子先 `sort()`：Dictionary 迭代顺序不可依赖，回放 / 同种子必须一致。
	## ⚠️ 只打**场上的敌方单位**，不直击敌方 HP（没有单位时效果落空）。
	if not self_relics.has(SUN_RING_ID) or _sun_ring_busy:
		return 0
	_sun_ring_busy = true
	var cells: Array[Vector2i] = []
	for cell: Vector2i in state.board:
		var q: Placement = state.board[cell]
		if q != null and q.owner == SIDE_OPPONENT and q.health > 0:
			cells.append(cell)
	if cells.is_empty():
		_sun_ring_busy = false
		return 0
	cells.sort()
	var hits: Array[Vector2i] = []
	for c: Vector2i in cells:
		var q2: Placement = state.board.get(c, null)
		if q2 == null or q2.health <= 0:
			continue
		_hit_unit(q2, SUN_RING_DMG, "太阳指环")
		hits.append(c)
	_sun_ring_busy = false
	_destroy_dead()
	_log("太阳指环：对所有敌方单位造成 %d 点伤害（%d 个目标）"
			% [SUN_RING_DMG, hits.size()])
	action.emit("sun_ring", {"dmg": SUN_RING_DMG, "hits": hits.size(), "cells": hits})
	return hits.size()


func _harpoon_tick(p: Placement, dmg: int) -> void:
	## R810 海妖鱼叉（6083）：**同一回合内**每对一个敌人造成 HARPOON_HITS 次伤害，
	## 就对它再补 HARPOON_DMG 点。
	## 计数记在**单位自己身上**：`harpoon_hits` + `harpoon_turn`（回合钥匙）。
	##   * 用 `turn_number` 当钥匙 → 换回合自动从 0 重算，不必在回合开始扫全场
	##     （漏扫一只就是静默错账，与赫尔墨斯 `turn_dmg_key` 同一范式）；
	##   * 只认**我方回合**：卡面写「同一回合内」，那一回合是玩家的回合；
	##   * 只认**敌方单位**：打自己的单位不该攒层。
	## ⚠️ `_harpoon_busy`：自己补的那 6 点不许再算一次计数，否则会自我滚雪球。
	## ⚠️ 不在这里调 `_destroy_dead()`：本函数是在别人的 `_hit_unit` 里被调的，
	##    外层那条伤害链自己会收尾（`attack()` 走 `_reap`、技能走 `_destroy_dead`）。
	if _harpoon_busy or dmg <= 0:
		return
	if current_side != SIDE_SELF or p.owner != SIDE_OPPONENT:
		return
	if not self_relics.has(HARPOON_ID):
		return
	if p.harpoon_turn != turn_number:
		p.harpoon_turn = turn_number
		p.harpoon_hits = 0
	p.harpoon_hits += 1
	if p.harpoon_hits % HARPOON_HITS != 0:
		return
	if p.health <= 0:
		return    # 这一下已经打死了 —— 补刀没有意义（也不该再触发一次受击演出）
	var cell := _cell_of(p)
	_harpoon_busy = true
	_hit_unit(p, HARPOON_DMG, "海妖鱼叉")
	_harpoon_busy = false
	_log("海妖鱼叉：%s 本回合第 %d 次受伤 → 追加 %d 点伤害（剩余 %d）"
			% [p.card.card_name, p.harpoon_hits, HARPOON_DMG, p.health])
	action.emit("harpoon", {"cell": cell, "card": p.card,
			"amount": HARPOON_DMG, "hits": p.harpoon_hits})


func _clock_maybe_switch() -> void:
	## R810 缺陷时钟（6084）：本场第 DEFECT_CLOCK_AT 张牌打完 → 结束当前回合、
	## **跳过敌方回合**，直接开始新的我方回合。
	## 为什么要有这个「二次入口」：`_note_card_played()` 是出牌收尾的唯一口，但它被调用时
	## 这张牌还没彻底结算完（`play_from_hand` 之后还要处理枭熊倒地之类）—— 在那里直接
	## `end_turn()` 会把那些收尾动作搬进「下一个回合」。所以真正的切换放在**三个公共出牌
	## 入口的返回处**（play_from_hand / use_spell / use_effect），那时这张牌已经完全落地。
	if not _clock_pending:
		return
	_clock_pending = false
	if over:
		return
	_log("缺陷时钟：本场第 %d 张牌 → 结束当前回合，立刻开始新的我方回合（敌方回合被跳过）"
			% DEFECT_CLOCK_AT)
	action.emit("defect_clock", {"at": DEFECT_CLOCK_AT})
	end_turn(true)


func _inspire_tick() -> int:
"""))

# ---------------- 7. _note_card_played：计数 ----------------
sub(blk("""	var assembly_plays: int = state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
	if played != null and assembly_plays == 1:
		_assemble_tick(side, "turn_first_play")
"""), blk("""	var assembly_plays: int = state.self_card_plays if side == SIDE_SELF else state.opp_card_plays
	if played != null and assembly_plays == 1:
		_assemble_tick(side, "turn_first_play")
	# R810 缺陷时钟（6084）：**每场战斗**打出第 DEFECT_CLOCK_AT 张牌时触发（一场只触发一次）。
	# 计数记在引擎上 → 每个新 GameEngine = 一场新战斗，自然复位；不跨战斗、不进存档。
	# ⚠️ 这里只**置待办**，真正的换回合交给 `_clock_maybe_switch()`（理由见那里的说明）。
	if side == SIDE_SELF and played != null and self_relics.has(DEFECT_CLOCK_ID):
		_clock_plays += 1
		if _clock_plays == DEFECT_CLOCK_AT:
			_clock_pending = true
			_log("缺陷时钟：本场已打出第 %d 张牌，本卡结算完后结束回合" % DEFECT_CLOCK_AT)
"""))

# ---------------- 8. end_turn 支持跳过敌方回合 ----------------
sub(blk("""func end_turn() -> void :
	if _assemble_busy():
"""), blk("""func end_turn(skip_enemy: bool = false) -> void :
	## `skip_enemy = true`（R810 缺陷时钟 6084 专用）：照常跑完**我方**这条回合结束链，
	## 但不把回合交给对手，而是直接 `_begin_turn(SIDE_SELF)` —— 卡面写的是
	## 「结束当前回合并变成你新的回合开始（完全不进行敌方回合）」。
	## ⚠️ 其余一切（弃手牌 / 清一次性 buff / 超负荷 / 死亡收尾 / 结算剩余费用）一字不动：
	##    这是「多给你一个回合」，不是「取消回合结束的代价」。
	## ⚠️ 只有我方回合才允许传 true（敌方回合跳过自己毫无意义）—— 见末尾的兜底。
	if _assemble_busy():
"""))
sub(blk("""	var nxt:= SIDE_OPPONENT if current_side == SIDE_SELF else SIDE_SELF
	_begin_turn(nxt)
"""), blk("""	var nxt:= SIDE_OPPONENT if current_side == SIDE_SELF else SIDE_SELF
	# R810 缺陷时钟：跳过对手 → 下一个仍是我方回合。敌方回合传 true 时按原逻辑走
	# （没有「跳过自己」这种语义，别让它把回合卡死）。
	if skip_enemy and current_side == SIDE_SELF:
		nxt = SIDE_SELF
	_begin_turn(nxt)
"""))

# ---------------- 9. 三个公共出牌入口加薄壳 ----------------
sub(blk("""func play_from_hand(hand_index: int, cell: Vector2i) -> Placement:
"""), blk("""func play_from_hand(hand_index: int, cell: Vector2i) -> Placement:
	## R810：外层薄壳 —— 真正结算在 `_play_from_hand_body()`。
	## 回来之后再判缺陷时钟（那时这张牌已经彻底落地，换回合不会打断它的收尾）。
	var placed := _play_from_hand_body(hand_index, cell)
	_clock_maybe_switch()
	return placed


func _play_from_hand_body(hand_index: int, cell: Vector2i) -> Placement:
"""))
sub(blk("""func use_spell(hand_index: int, target = null, free_cast := false) -> String:
"""), blk("""func use_spell(hand_index: int, target = null, free_cast := false) -> String:
	## R810：同 `play_from_hand` —— 薄壳 + 缺陷时钟判定（技能卡也算「打出的第 N 张牌」）。
	var out := _use_spell_body(hand_index, target, free_cast)
	_clock_maybe_switch()
	return out


func _use_spell_body(hand_index: int, target = null, free_cast := false) -> String:
"""))
sub(blk("""func use_effect(hand_index: int) -> String:
"""), blk("""func use_effect(hand_index: int) -> String:
	## R810：同 `play_from_hand` —— 薄壳 + 缺陷时钟判定（效果卡同样计入张数）。
	var out := _use_effect_body(hand_index)
	_clock_maybe_switch()
	return out


func _use_effect_body(hand_index: int) -> String:
"""))

io.open(P, "w", encoding="utf-8", newline="").write(s)
print("ENGINE PATCH OK, CRLF kept:", "\r\n" in s)
