# -*- coding: utf-8 -*-
## R857：沉睡单位每回合获得 5 护甲（回合开始重置，醒来消失）。
## 只动 game_engine.gd，exact-replace + assert count==1；文件是 CRLF。
import io, sys

P = "scripts/game_engine.gd"
src = io.open(P, encoding="utf-8", newline="").read()
orig = src
NL = "\r\n"


def rep(old, new, tag):
    global src
    o = old.replace("\n", NL)
    n = new.replace("\n", NL)
    c = src.count(o)
    assert c == 1, "[%s] 锚点命中 %d 次" % (tag, c)
    src = src.replace(o, n, 1)


# ── ① 常量 ──
rep(
"""const ASCLEPIUS_GROWTH_ATK:= 1
""",
"""const ASCLEPIUS_GROWTH_ATK:= 1

# ---- R857：沉睡「甲壳」 ----
# 沉睡中的单位（`Placement.sleep_left > 0`；任何带「沉睡」trait 的卡：恶魔鸭 9116 /
# 激光巨炮 9241 / 将来新增的睡着的单位）在**自己回合开始**把护甲重置为 SLEEP_ARMOR。
# * 覆盖而非累加（`armor = SLEEP_ARMOR`）：卡面写的是「重置」，叠上去就变成滚雪球；
# * 醒来那一刻甲壳碎裂 —— 只扣掉这 5 点，别处攒的护甲（赫卡同克瑞斯 +10 等）保留；
# * 口径选「自己回合」而不是「每半回合」：后者玩家削完 5 点、敌方回合又被补满，
#   等于每个玩家回合白打一刀，手感是「打不动」而不是「有层壳」。
const SLEEP_ARMOR:= 5
""",
"const",
)

# ── ② 两个函数（紧贴在 _sleep_tick 之前） ──
rep(
"""func _sleep_tick(side: String) -> void :
""",
"""func _sleep_armor_tick(side: String) -> void :
	## 沉睡（R857）：**本方回合开始**，本方还在睡的单位把护甲重置为 SLEEP_ARMOR。
	## 判据只看 `sleep_left > 0` —— 机制层不认 id，任何带「沉睡」trait 的单位都吃。
	## 调用点：`_begin_turn` 两个分支的成长区开头（在 `_asclepius_armor_tick` 之前），
	## 于是「先重置甲壳，其他加甲照常叠在上面」（沉睡的阿斯克勒庇厄斯 = 5 + 20）。
	for cell: Vector2i in state.board:
		var p: Placement = state.unit_at(cell)
		if p == null or p.owner != side or p.sleep_left <= 0:
			continue
		var before: int = p.armor
		p.armor = SLEEP_ARMOR
		_log("沉睡甲壳：%s 的护甲重置为 %d（原 %d）" % [p.card.card_name, p.armor, before])
		action.emit("armor_gain", {"cell": cell, "card": p.card, "side": side,
				"armor": p.armor, "gained": p.armor - before})


func _sleep_shed_armor(p: Placement) -> void :
	## 沉睡醒来的**唯一收尾口**：甲壳碎裂 —— 扣掉 SLEEP_ARMOR，别处攒的护甲留着。
	## 两个醒来口（`_sleep_tick` 的回合口 / `_demon_duck_hurt` 的受伤口）都走这里，
	## 所以不会出现「被打醒还顶着 5 点甲」或「两边各扣一次扣成负数」。
	if p.armor <= 0:
		return
	var lost: int = mini(p.armor, SLEEP_ARMOR)
	p.armor -= lost
	_log("%s 醒来：甲壳碎裂，失去 %d 点护甲（剩 %d）" % [p.card.card_name, lost, p.armor])


func _sleep_tick(side: String) -> void :
""",
"func",
)

# ── ③ _begin_turn 我方分支 ──
rep(
"""		_asclepius_armor_tick(SIDE_SELF)   # R162：护甲积攒结算
""",
"""		_sleep_armor_tick(SIDE_SELF)       # R857：沉睡甲壳重置（必须在其他加甲之前）
		_asclepius_armor_tick(SIDE_SELF)   # R162：护甲积攒结算
""",
"begin_self",
)

# ── ④ _begin_turn 敌方分支 ──
rep(
"""		_asclepius_armor_tick(SIDE_OPPONENT)   # R162：护甲积攒结算
""",
"""		_sleep_armor_tick(SIDE_OPPONENT)       # R857：沉睡甲壳重置（同我方，对称）
		_asclepius_armor_tick(SIDE_OPPONENT)   # R162：护甲积攒结算
""",
"begin_opp",
)

# ── ⑤ 回合口醒来 → 碎甲 ──
rep(
"""		if p.sleep_left <= 0:
			_log("%s 睡满了本轮，从沉睡中醒来（下一回合可以行动）" % p.card.card_name)
""",
"""		if p.sleep_left <= 0:
			_log("%s 睡满了本轮，从沉睡中醒来（下一回合可以行动）" % p.card.card_name)
			_sleep_shed_armor(p)
""",
"wake_turn",
)

# ── ⑥ 受伤口醒来 → 碎甲 ──
rep(
"""		if p.sleep_left <= 0:
			_log("%s 被打够次数，从沉睡中醒来（立即可以行动）" % p.card.card_name)
""",
"""		if p.sleep_left <= 0:
			_log("%s 被打够次数，从沉睡中醒来（立即可以行动）" % p.card.card_name)
			_sleep_shed_armor(p)
""",
"wake_hurt",
)

assert src != orig
io.open(P, "w", encoding="utf-8", newline="").write(src)
print("ok 写入", P, "长度", len(orig), "->", len(src))
