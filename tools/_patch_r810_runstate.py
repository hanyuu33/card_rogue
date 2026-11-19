# -*- coding: utf-8 -*-
"""R810 RunState：新月耳饰的跨战斗计数 + 角标 + 状态注。"""
import io

P = "E:/work/card_rogue/scripts/run_state.gd"
s = io.open(P, encoding="utf-8", newline="").read()


def sub(old, new):
    global s
    assert s.count(old) == 1, (old[:50], s.count(old))
    s = s.replace(old, new)


# ---- 1. 常量 + 计数 ----
sub("""const LUCKY7_RELIC_ID := 6045
const LUCKY7_EVERY := 7
## lucky 7 的**跨战斗**计数：每开始一个我方回合 +1（`lucky7_tick()`），
## 满 7 的倍数那一回合生效。随存档走（run_save）。
static var lucky7_turns := 0
""", """const LUCKY7_RELIC_ID := 6045
const LUCKY7_EVERY := 7
## lucky 7 的**跨战斗**计数：每开始一个我方回合 +1（`lucky7_tick()`），
## 满 7 的倍数那一回合生效。随存档走（run_save）。
static var lucky7_turns := 0

## R810 新月耳饰（6081，一般档）：每 `CRESCENT_EVERY` 场战斗，在**那场的第一回合** +1 费用。
## 计数只记「拿着这件道具之后开打的战斗」，跨战斗保留、随存档走（run_save）。
## ⚠️ 推进口唯一 = `GameEngine._begin_turn()` 的 `turn_number == 1` 分支里调 `crescent_tick()`
##    —— 那里每场战斗只成立一次。别在战斗开始处再加一次，否则一场数两下。
const CRESCENT_EARING_ID := 6081
const CRESCENT_EVERY := 3
static var crescent_battles := 0
""")

# ---- 2. 推进函数（放在 lucky7_tick 之前）----
sub("""static func lucky7_tick() -> bool:
""", """static func crescent_tick() -> bool:
	## R810 新月耳饰（6081）：**每场战斗开始时**（引擎侧 = `turn_number == 1`）调一次。
	## 返回「这一场是否该发 1 点费用」—— 场数满 `CRESCENT_EVERY` 的倍数时为 true，
	## 计到倍数就**归零重数**（而不是一直对模），于是角标「还差几场」永远算得清。
	## ⚠️ 无条件累加（只要持有道具）；发不发钱由返回值决定，调用方负责加 `state.energy`。
	crescent_battles += 1
	if crescent_battles >= CRESCENT_EVERY:
		crescent_battles = 0
		return true
	return false


static func crescent_left() -> int:
	## 还差几场战斗才发下一点费用（角标 / 状态注共用）—— 刚发完时是 `CRESCENT_EVERY`。
	return maxi(1, CRESCENT_EVERY - crescent_battles)


static func lucky7_tick() -> bool:
""")

# ---- 3. 角标 ----
sub("""		CAVE_ROPE_RELIC_ID:
			return "1"
""", """		CAVE_ROPE_RELIC_ID:
			return "1"
		CRESCENT_EARING_ID:
			# R810 新月耳饰：还差几场战斗 → 下一点费用（3 / 2 / 1）。
			# 与 lucky 7 不同，这里**没有「正在生效」的回合**要避让，所以永远画。
			return str(crescent_left())
""")

# ---- 4. 状态注 ----
sub("""	if id == LUCKY7_RELIC_ID and relics.has(LUCKY7_RELIC_ID):
""", """	if id == CRESCENT_EARING_ID and relics.has(CRESCENT_EARING_ID):
		return GameI18n.ui("reward", "REWARD_RELIC_STATE_CRESCENT_WAITING",
				"距获得下一点费用还有 %d 场战斗。") % crescent_left()
	if id == LUCKY7_RELIC_ID and relics.has(LUCKY7_RELIC_ID):
""")

io.open(P, "w", encoding="utf-8", newline="").write(s)
assert "\r\n" not in s
print("RUN_STATE OK")
