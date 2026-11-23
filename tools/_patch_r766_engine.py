# -*- coding: utf-8 -*-
"""R766 引擎：猴爪（6066）回合钩子 + 懊悔（9265）选卡结算。

补丁点（每处 exact-replace + assert count==1）：
  A 常量区（机械臂 6065 之后）
  B pending 声明（wish_pending 之后）
  C start_game 复位
  D 我方回合开始调用 `_claw_tick()`（抽牌 + 耳环自动出牌之后）
  E `_other_class_card` / `_random_other_class_card` / `_claw_tick`（`_random_ally_card` 之后）
  F `regret_options` / `regret_pick`（`crow_recall` 之后）
  G `_run_spell_effect_body` 出牌分支
  H 三处 pending 守卫（use_spell / _instinct_panel_open / 失眠抽牌）
"""
import pathlib
import sys

P = pathlib.Path(r"E:\work\card_rogue\scripts\game_engine.gd")
src = P.read_text(encoding="utf-8")
orig_len = len(src)
applied = []


def sub(anchor, new, label):
    global src
    n = src.count(anchor)
    if n != 1:
        print("FAIL[%s] anchor count=%d" % (label, n), flush=True)
        raise SystemExit(1)
    src = src.replace(anchor, new)
    applied.append(label)


# ---------------------------------------------------------------- A 常量
A_OLD = """const MECHANICAL_ARM_RELIC_ID:= 6065
const MECHANICAL_ARM_DISCOUNT:= 1
"""
A_NEW = """const MECHANICAL_ARM_RELIC_ID:= 6065
const MECHANICAL_ARM_DISCOUNT:= 1
# R766 猴爪（6066）：每场战斗的**前三个回合开始时** ——
#   ① 随机一张**其他职业卡**进手牌；② 向**卡组**（永久 `RunState.deck_ids`）塞一张「懊悔」。
# ⚠️ 「其他职业」的唯一判据是 `_other_class_card()`：**有明确职业归属且不是玩家当前职业**。
#    公用卡（class 留空，如雪豹 8081）**不算** —— 与诗 6069 的 `_poem_ally()` 故意不同
#    （那里公用卡也算，因为诗吃的是「不是我谱的曲」，猴爪要的是「从别人家借来的卡」）。
# ⚠️ 「加入卡组」= 永久卡组，**本场抽牌堆不掺** —— 下一场战斗才抽得到。
const MONKEY_CLAW_RELIC_ID:= 6066
const MONKEY_CLAW_TURNS:= 3
const REGRET_CARD_ID:= 9265
"""
sub(A_OLD, A_NEW, "A-const")

# ------------------------------------------------------- B pending 声明
B_OLD = """var wish_pending:= false    # 许愿（9168）：等玩家从**卡组**选一张卡加入手卡
"""
B_NEW = """var wish_pending:= false    # 许愿（9168）：等玩家从**卡组**选一张卡加入手卡
## R766 懊悔（9265）：等玩家从**弃牌区**选一张其他职业卡，让它消失（本场移除）。
var regret_pending:= false
"""
sub(B_OLD, B_NEW, "B-decl")

# ------------------------------------------------------------ C 战斗复位
C_OLD = """	wish_pending = false
	recruit_pending = false
"""
C_NEW = """	wish_pending = false
	regret_pending = false
	recruit_pending = false
"""
sub(C_OLD, C_NEW, "C-reset")

# --------------------------------------------------- D 回合开始钩子
D_OLD = """		_melt_ice_walls(SIDE_SELF)
		_clear_fire_walls(SIDE_SELF)
"""
D_NEW = """		_claw_tick()   # R766 猴爪：前三个回合各发一张外来卡 + 一张「懊悔」进卡组
		_melt_ice_walls(SIDE_SELF)
		_clear_fire_walls(SIDE_SELF)
"""
sub(D_OLD, D_NEW, "D-hook")

# ------------------------------------------------------------ E 三个函数
E_OLD = """func _sync_harp() -> void:
"""
E_NEW = '''func _other_class_card(c: CardData) -> bool:
	## R766：「其他职业卡」**唯一判据** —— 猴爪（随机发一张）与懊悔（弃牌区可选）共用这一个口。
	## 判据两件套：① 有明确职业归属（`card_class` 非空）；② 不是玩家当前职业。
	## ⚠️ 公用卡（class 留空）与诅咒（class 留空）都**不算** —— 见常量区那段注释。
	return c != null and c.card_class != "" and c.card_class != RunState.player_class


func _random_other_class_card() -> CardData:
	## R766 猴爪：完整奖励池里随机一张**其他职业**的卡。
	## 走引擎 `rng` → 同种子同结果、回放可复现（与 `_random_ally_card` 同一口径）。
	var repo:= CardRepo.load_json()
	var pool: Array[CardData] = []
	for c: CardData in repo.reward_pool():
		if _other_class_card(c):
			pool.append(c)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]


func _claw_tick() -> void:
	## R766 猴爪（6066）：每场战斗的**前三个回合开始时**各触发一次。
	## ① 随机其他职业卡 → 手牌（走 `_grant_to_hand` 唯一口：满手时按既有口径改投弃牌区，
	##    卡不会凭空蒸发）；② 一张「懊悔」→ **卡组**（永久，`RunState.add_card`）。
	## ⚠️ 调用点排在抽牌与耳环自动出牌**之后** —— 那时手牌状态已稳定，不会出现
	##    「先塞一张再抽牌」把满手判定算在两套口径上。
	## ⚠️ 每回合都**现问** `turn_number`，不另存计数器：读档续战 / 重开都能对上。
	if not self_relics.has(MONKEY_CLAW_RELIC_ID):
		return
	if turn_number <= 0 or turn_number > MONKEY_CLAW_TURNS:
		return
	var alien:= _random_other_class_card()
	if alien == null:
		_log("猴爪：卡池里没有其他职业的卡")
	else:
		var copy:= _new_own_card(alien)
		var got:= _grant_to_hand(copy, "猴爪")
		_log("猴爪：第 %d 回合，%s「%s」" % [
				turn_number, "手牌加入" if got else "手牌已满 → 改投弃牌区", copy.card_name])
		action.emit("relic", {"id": MONKEY_CLAW_RELIC_ID, "turn": turn_number,
				"card": copy, "to_hand": got})
	RunState.add_card(REGRET_CARD_ID)
	_log("猴爪：第 %d 回合，「懊悔」加入卡组（本场抽牌堆不掺）" % turn_number)


func _sync_harp() -> void:
'''
sub(E_OLD, E_NEW, "E-funcs")

# ------------------------------------------------------------ F 两个结算口
F_OLD = '''	state.discard.remove_at(discard_index)
	state.hand.append(c)
	crow_pending = false
	_log("乌鸦：%s 从弃牌堆回到手牌" % c.card_name)
	action.emit("crow_recall", {"card": c})
	return true
'''
F_NEW = '''	state.discard.remove_at(discard_index)
	state.hand.append(c)
	crow_pending = false
	_log("乌鸦：%s 从弃牌堆回到手牌" % c.card_name)
	action.emit("crow_recall", {"card": c})
	return true


func regret_options() -> Array[int]:
	## R766 懊悔（9265）：可选目标 = **弃牌区里其他职业卡**的下标（顺序即弃牌区顺序）。
	## 判据只走 `_other_class_card()`，与猴爪发卡同一口 —— 不在这里另写一份职业判定。
	var out: Array[int] = []
	for i in state.discard.size():
		if _other_class_card(state.discard[i]):
			out.append(i)
	return out


func regret_pick(discard_index: int) -> bool:
	## R766 懊悔的结算口：把弃牌区第 discard_index 张**移除** —— 这就是「消失」
	## （口径见 canonical rules：消失 = 本场对战移除）。它已经在弃牌区了，
	## 所以既不进消耗区、也不回任何区域，直接抹掉。
	if not regret_pending:
		return false
	if discard_index < 0 or discard_index >= state.discard.size():
		return false
	var c: CardData = state.discard[discard_index]
	if not _other_class_card(c):
		return false
	state.discard.remove_at(discard_index)
	regret_pending = false
	_log("懊悔：弃牌区的「%s」消失" % c.card_name)
	action.emit("regret_pick", {"card": c})
	return true
'''
sub(F_OLD, F_NEW, "F-pick")

# --------------------------------------------------------- G 出牌分支
G_OLD = """	match card.id:
		WISH_ID:
"""
G_NEW = """	match card.id:
		REGRET_CARD_ID:
			# 懊悔（9265，R766）：选弃牌区一张**其他职业卡**让它消失。
			# 弃牌区没有其他职业卡就白打（这张自己仍按「次元」进消耗区，不进弃牌区）。
			if regret_options().is_empty():
				_log("懊悔：弃牌区没有其他职业的卡")
				return "弃牌区没有其他职业的卡"
			regret_pending = true
			_log("懊悔：从弃牌区选择一张其他职业卡（弃牌区 %d 张）" % state.discard.size())
			return "从弃牌区选择一张其他职业卡消失"
		WISH_ID:
"""
sub(G_OLD, G_NEW, "G-branch")

# ------------------------------------------------------------- H 三处守卫
H1_OLD = """	if overhaul_pending:
		return "返修：请先从弃牌区选择一张盟友或工事"
"""
H1_NEW = """	if regret_pending:
		return "懊悔：请先从弃牌区选择一张其他职业卡"
	if overhaul_pending:
		return "返修：请先从弃牌区选择一张盟友或工事"
"""
sub(H1_OLD, H1_NEW, "H1-use_spell")

H2_OLD = "		or rebirth_pending or eliminate_pending or recruit_pending\n"
H2_NEW = "		or rebirth_pending or eliminate_pending or recruit_pending or regret_pending\n"
sub(H2_OLD, H2_NEW, "H2-instinct")

H3_OLD = """			or focus_pending or overhaul_pending:
		return
	if not _zone_has_id(side, SLEEPLESS_ID) or not state.hand.is_empty():
"""
H3_NEW = """			or focus_pending or overhaul_pending or regret_pending:
		return
	if not _zone_has_id(side, SLEEPLESS_ID) or not state.hand.is_empty():
"""
sub(H3_OLD, H3_NEW, "H3-sleepless")

P.write_text(src, encoding="utf-8", newline="\n")
print("patched %d spots, %d -> %d chars (+%d)" % (
    len(applied), orig_len, len(src), len(src) - orig_len))
for a in applied:
    print("  ok", a)
