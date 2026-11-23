# -*- coding: utf-8 -*-
## R859：沉睡甲壳改口径 —— 开局 10 点、不重置、醒来全失；甲还在时挨打不算「挨打」。
import io

NL = "\r\n"


def patch(path, pairs):
    src = io.open(path, encoding="utf-8", newline="").read()
    orig = src
    for old, new, tag in pairs:
        o = old.replace("\n", NL)
        n = new.replace("\n", NL)
        c = src.count(o)
        assert c == 1, "[%s/%s] 锚点命中 %d 次" % (path, tag, c)
        src = src.replace(o, n, 1)
    assert src != orig
    io.open(path, "w", encoding="utf-8", newline="").write(src)
    print("ok", path, len(orig), "->", len(src))


# ── game_engine.gd ──
GE = "scripts/game_engine.gd"
pairs = []

# ① 常量块重写
pairs.append((
"""# ---- R857：沉睡「甲壳」 ----
# 沉睡中的单位（`Placement.sleep_left > 0`；任何带「沉睡」trait 的卡：恶魔鸭 9116 /
# 激光巨炮 9241 / 将来新增的睡着的单位）在**自己回合开始**把护甲重置为 SLEEP_ARMOR。
# * 覆盖而非累加（`armor = SLEEP_ARMOR`）：卡面写的是「重置」，叠上去就变成滚雪球；
# * 醒来那一刻甲壳碎裂 —— 只扣掉这 5 点，别处攒的护甲（赫卡同克瑞斯 +10 等）保留；
# * 口径选「自己回合」而不是「每半回合」：后者玩家削完 5 点、敌方回合又被补满，
#   等于每个玩家回合白打一刀，手感是「打不动」而不是「有层壳」。
const SLEEP_ARMOR:= 5
""",
"""# ---- R859：沉睡「甲壳」----
# 带「沉睡」trait 的单位**一上场**（关卡摆位 / 召唤 / 手牌打出，都走 FieldState.place）
# 就带 SLEEP_ARMOR 点护甲，**不随回合重置**；醒来那一刻整个脱落（armor = 0）。
# ⚠️ R857 曾是「每个自己回合开始重置 5 点」，R859 按店长口径改为一次性 10 点。
# * 甲还在时挨打**不算「挨打」**（`_demon_duck_hurt` 的 `dealt` 判据）：开局的自动伤害
#   道具只能磨甲、磨不醒它 —— 这正是这层甲存在的理由。副作用：普通攻击同样磨不醒，
#   沉睡单位只能等自己的回合数走完（或甲被打穿之后）。
# * 数值只放引擎这一处：卡面 / 测试 / 日志都读它。
const SLEEP_ARMOR:= 10
""",
"const",
))

# ② 删掉每回合重置函数（含它前面的空行，保留 _sleep_shed_armor）
pairs.append((
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


""",
"""# R859：`_sleep_armor_tick`（每个自己回合重置 5 点）**已删除** —— 甲壳改成
# 「一上场给一次、不重置」。给甲的口在 `FieldState.place()`（唯一初始化口），
# 脱落的口就是下面的 `_sleep_shed_armor()`。
""",
"del_tick",
))

# ③ 两处 _begin_turn 调用
pairs.append((
"""		_sleep_armor_tick(SIDE_SELF)       # R857：沉睡甲壳重置（必须在其他加甲之前）
""",
"""""",
"begin_self",
))
pairs.append((
"""		_sleep_armor_tick(SIDE_OPPONENT)       # R857：沉睡甲壳重置（同我方，对称）
""",
"""""",
"begin_opp",
))

# ④ 醒来收尾：失去**所有**护甲
pairs.append((
"""func _sleep_shed_armor(p: Placement) -> void :
	## 沉睡醒来的**唯一收尾口**：甲壳碎裂 —— 扣掉 SLEEP_ARMOR，别处攒的护甲留着。
	## 两个醒来口（`_sleep_tick` 的回合口 / `_demon_duck_hurt` 的受伤口）都走这里，
	## 所以不会出现「被打醒还顶着 5 点甲」或「两边各扣一次扣成负数」。
	if p.armor <= 0:
		return
	var lost: int = mini(p.armor, SLEEP_ARMOR)
	p.armor -= lost
	_log("%s 醒来：甲壳碎裂，失去 %d 点护甲（剩 %d）" % [p.card.card_name, lost, p.armor])
""",
"""func _sleep_shed_armor(p: Placement) -> void :
	## 沉睡醒来的**唯一收尾口**：甲壳整个脱落 —— **失去所有护甲**（R859 店长口径），
	## 不是扣一个定值。两个醒来口（`_sleep_tick` 的回合口 / `_demon_duck_hurt` 的受伤口）
	## 都走这里，所以不会出现「被打醒还顶着甲」或「两边各清一次」。
	if p.armor <= 0:
		return
	_log("%s 醒来：甲壳脱落，失去全部 %d 点护甲" % [p.card.card_name, p.armor])
	p.armor = 0
""",
"shed",
))

# ⑤ _demon_duck_hurt 加 dealt 参数
pairs.append((
"""func _demon_duck_hurt(p: Placement, cell: Vector2i) -> void :
""",
"""func _demon_duck_hurt(p: Placement, cell: Vector2i, dealt:= 1) -> void :
""",
"hurt_sig",
))

pairs.append((
"""	if p.sleep_left > 0:
		p.sleep_left -= 1
""",
"""	if p.sleep_left > 0:
		# R859：甲壳还在、这一下**完全没打到肉**（`dealt == 0`）→ 不算「挨打」，
		# 沉睡计数不变。开局的自动伤害道具因此打不醒它（只能磨甲）。
		# 判据用「这次实际扣了多少血」而不是「当前 armor 是否 > 0」：
		# 后者在「刚好把甲打穿的那一下」吸收后已经归零，会漏掉一次。
		if dealt <= 0:
			_log("%s 的沉睡甲壳挡住了这一下（沉睡计数不变，护甲 %d）" % [
					p.card.card_name, p.armor])
			return
		p.sleep_left -= 1
""",
"hurt_branch",
))

# ⑥ _hit_unit 调用点带上实际扣血
pairs.append((
"""		_demon_duck_hurt(p, _cell_of(p))
""",
"""		_demon_duck_hurt(p, _cell_of(p), dmg)
""",
"call",
))

patch(GE, pairs)

# ── field_state.gd：place 时给甲 ──
patch("scripts/field_state.gd", [(
"""	if card.traits.has(SLEEP_TRAIT):
		p.sleep_left = SLEEP_TURNS
""",
"""	if card.traits.has(SLEEP_TRAIT):
		p.sleep_left = SLEEP_TURNS
		# R859：沉睡单位**一上场就带甲壳**（GameEngine.SLEEP_ARMOR，目前 10 点），
		# 且**不随回合重置**。放在 place 里 = 唯一初始化口，关卡摆位 / 召唤 / 手牌打出
		# 三条路径一致；醒来时由 `_sleep_shed_armor()` 整个清掉。
		# ⚠️ 甲还在时挨打不算「挨打」（`_demon_duck_hurt` 的 dealt 判据）——
		#    这是「自动伤害道具打不醒沉睡单位」的实现方式，别只加甲不改判据。
		p.armor = GameEngine.SLEEP_ARMOR
""",
"place",
)])
