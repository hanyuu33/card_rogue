# -*- coding: utf-8 -*-
"""R778b：game_engine.gd ——① 灰烬龙战吼下线；② 9133 换成「铸甲」回合开始护甲。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
P = ROOT + "scripts/game_engine.gd"

s = io.open(P, "r", encoding="utf-8", newline="").read()
assert s.count("\n") == s.count("\r\n"), "game_engine.gd 应为纯 CRLF"
s = s.replace("\r\n", "\n")


def rep(old, new, tag):
    global s
    n = s.count(old)
    if n != 1:
        print("FAIL[%s] count=%d" % (tag, n))
        sys.exit(1)
    s = s.replace(old, new, 1)
    print("OK %s" % tag)


# ---------- 1. 删常量 ----------
rep("const ASH_DRAGON_ID:= 1013\nconst ASH_DRAGON_AOE:= 4\n",
    '', "删 ASH_DRAGON_ID / ASH_DRAGON_AOE")

# ---------- 2. _battlecry 分派：去掉 ash 分支 ----------
rep('''func _battlecry(cell: Vector2i, p: Placement) -> void :
	match p.card.id:
		ASH_DRAGON_ID:
			_battlecry_ash(cell, p)
		_:
			pass
''', '''func _battlecry(cell: Vector2i, p: Placement) -> void :
	## R778：灰烬龙（1013）的「登场后首个回合对全场 4 伤」已删除，当前没有任何单位带战吼。
	## 分派骨架留着：`_run_battlecries()` 每场仍会走一遍，`battlecry_done` 保证每只只判一次，
	## 以后要加战吼直接在这个 match 里挂分支。
	match p.card.id:
		_:
			pass
''', "_battlecry 去 ash 分支")

# ---------- 3. 删整个 _battlecry_ash 函数 ----------
start = s.index("func _battlecry_ash(cell: Vector2i, p: Placement) -> void :")
end = s.index("\n\n\nfunc _deathrattle(", start)
s = s[:start] + s[end + 3:]   # 连带吃掉前面的空行，保留 _deathrattle 前的两空行
print("OK 删 _battlecry_ash 函数（%d 字符）" % (end - start))

# ---------- 4. 9133 常量与 tick ----------
rep("const HECATE_ID:= 9133              # 量产型赫卡同克瑞斯（盟友 3/35 程1 速1）\n",
    "const HECATE_ID:= 9133              # 量产型赫卡同克瑞斯（盟友 3/60 程1 速1）\n"
    "const HECATE_ARMOR_GAIN:= 10        # R778：每回合给随机一个**其他**友方单位 +10 护甲\n",
    "HECATE 常量")

# 把 tick 插在 _scavenger_tick 之前
anchor = "func _scavenger_tick(side: String) -> void :\n"
newfunc = '''func _hecaton_armor_tick(side: String) -> void :
	## R778：量产型赫卡同克瑞斯（9133）—— `side` 这一方**回合开始时**，每只 9133 给
	## 「随机一个**其他**友方单位」+10 护甲。
	## * 原效果「铸造倒计时 → 原地立起钢铁要塞」已废弃（卡面 effect_text 同步换掉，
	##   traits 里的「铸造」也删了，所以 `Placement.fuse_left` 不再挂表）；
	## * 目标随机（引擎 rng → 同种子同结果，回放可复现）；没有其他友方单位 → 跳过；
	## * 护甲写 `Placement.armor`，受击时由 `_unit_damage_taken()` 优先吸收（共用唯一口）；
	## * 候选格子**先排序再摇**：同一方多只 9133 时 rng 消耗顺序必须稳定（回放）。
	var casters: Array[Vector2i] = []
	for cell: Vector2i in state.board.keys():
		var p: Placement = state.unit_at(cell)
		if p != null and p.owner == side and p.card != null and p.card.id == HECATE_ID:
			casters.append(cell)
	if casters.is_empty():
		return
	casters.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y)
	for cell: Vector2i in casters:
		var p: Placement = state.unit_at(cell)
		if p == null:
			continue
		var picks: Array[Vector2i] = []
		for c2: Vector2i in state.board.keys():
			var q: Placement = state.unit_at(c2)
			if q != null and q.owner == side and c2 != cell:
				picks.append(c2)
		if picks.is_empty():
			_log("铸甲：场上没有其他友方单位，%s 无处加护甲" % p.card.card_name)
			continue
		picks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.x < b.x if a.x != b.x else a.y < b.y)
		var tc: Vector2i = picks[rng.randi() % picks.size()]
		var t: Placement = state.unit_at(tc)
		if t == null:
			continue
		t.armor += HECATE_ARMOR_GAIN
		_log("铸甲：%s → %s 获得 %d 护甲（现 %d）" % [
			p.card.card_name, t.card.card_name, HECATE_ARMOR_GAIN, t.armor])
		action.emit("armor_gain", {"cell": tc, "card": t.card, "side": side,
				"armor": t.armor, "gained": HECATE_ARMOR_GAIN})


'''
rep(anchor, newfunc + anchor, "插入 _hecaton_armor_tick")

# ---------- 5. 接进两侧 start_turn ----------
rep("\t\t_asclepius_armor_tick(SIDE_SELF)   # R162：护甲积攒结算\n",
    "\t\t_asclepius_armor_tick(SIDE_SELF)   # R162：护甲积攒结算\n"
    "\t\t_hecaton_armor_tick(SIDE_SELF)     # R778 量产型赫卡同克瑞斯 9133：给其他友军 +10 护甲\n",
    "接 SIDE_SELF")
rep("\t\t_asclepius_armor_tick(SIDE_OPPONENT)   # R162：护甲积攒结算\n",
    "\t\t_asclepius_armor_tick(SIDE_OPPONENT)   # R162：护甲积攒结算\n"
    "\t\t_hecaton_armor_tick(SIDE_OPPONENT)     # R778 9133 铸甲\n",
    "接 SIDE_OPPONENT")

io.open(P, "w", encoding="utf-8", newline="").write(s.replace("\n", "\r\n"))
print("ENGINE DONE")
