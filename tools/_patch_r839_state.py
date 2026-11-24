## R839：大蒜 7017 —— FieldState 层（不可使用格的表 + 存档 + 落点闸门）
## 用法：python tools/_patch_r839_state.py
import io, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"


def read(p):
    with io.open(ROOT + p, "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with io.open(ROOT + p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def rep(path, old, new, tag):
    d = read(path)
    crlf = "\r\n" in d
    norm = d.replace("\r\n", "\n")
    o, n = old.replace("\r\n", "\n"), new.replace("\r\n", "\n")
    cnt = norm.count(o)
    assert cnt == 1, "%s 锚点命中 %d 次（要求 1）" % (tag, cnt)
    out = norm.replace(o, n)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(path, out)
    print("ok  %-34s (%s)" % (tag, "CRLF" if crlf else "LF"))


P = "scripts/field_state.gd"

# ---------- ① 表本身 ----------
rep(P, '''var trap_fields := {}
''', '''var trap_fields := {}
## R839 大蒜 7017：Vector2i -> 剩余的我方回合数（>0 = 这一格「不可使用」）。
## 与 `trap_fields` 并列但**语义相反**：那张表是「踩上去触发」，这张是「根本踩不进去」。
## 唯一写口 `seal_cell()`、唯一读口 `is_cell_sealed()`、唯一推进口 `tick_seals()` ——
## 移动 BFS / 跳跃 / 召唤落点 / 陷阱与场地落点 / 界面高亮全都读同一个判据。
## ⚠️ 刻意**不进 `trap_fields`**：混进去会被 `trap_legal_cells()` 当成一件已布置的陷阱，
##    而 `_trigger_trap()` 又永远等不到人踩（封锁格本身就进不去）。
var sealed_cells := {}
''', "field_state: sealed_cells")

# ---------- ② 三个方法（跟在 clear_field 之后）----------
rep(P, '''func haste_turn(side: String) -> bool:''', '''func is_cell_sealed(cell: Vector2i) -> bool:
	## R839：这一格现在「不可使用」吗（大蒜）。**唯一读口** ——
	## 引擎的移动 / 跳跃 / 落点判据与界面高亮都读它，别各自再摸一次 `sealed_cells`。
	return int(sealed_cells.get(cell, 0)) > 0


func seal_cell(cell: Vector2i, turns: int) -> void:
	## R839：把一格封住 `turns` 个我方回合（大蒜 block_turns = 3）。
	## 同一格再封一次 → 取**较大**的剩余回合：既不叠成「六回合」，也不会被更短的一次
	## 覆盖成 1 回合（玩家并没有做错什么，不该被后来的短封锁「冲掉」）。
	if turns <= 0:
		return
	sealed_cells[cell] = maxi(int(sealed_cells.get(cell, 0)), turns)


func tick_seals() -> Array[Vector2i]:
	## R839：大蒜倒计时**唯一推进口** —— 引擎在每个我方回合开始时调一次。
	## 返回这一跳后**到期解开**的格子（已排序，界面据此播「这格恢复可用」的提示；
	## 排序是为了回放 / 同种子下事件顺序稳定）。
	var expired: Array[Vector2i] = []
	for cell: Vector2i in sealed_cells.keys():
		var left := int(sealed_cells[cell]) - 1
		if left <= 0:
			sealed_cells.erase(cell)
			expired.append(cell)
		else:
			sealed_cells[cell] = left
	expired.sort()
	return expired


func haste_turn(side: String) -> bool:''', "field_state: 三个方法")

# ---------- ③ 落点闸门（place 拒绝落在封锁格）----------
rep(P, '''	if cell.x == GameEngine.forbidden_row_for(owner):
		push_error("FieldState.place 拒绝：%s 不能站在 %s（owner=%s 的 HP 行）" % [
				card.card_name, cell, owner])
		return null''', '''	if cell.x == GameEngine.forbidden_row_for(owner):
		push_error("FieldState.place 拒绝：%s 不能站在 %s（owner=%s 的 HP 行）" % [
				card.card_name, cell, owner])
		return null
	# R839 大蒜：被封锁的格子「不可使用」—— 召唤 / 效果直达 / 任何落点都不许落在这儿。
	# 关卡摆位不受影响（`sealed_cells` 是局内产生的，摆位那一刻还是空的）。
	if is_cell_sealed(cell):
		push_error("FieldState.place 拒绝：%s 不能落在 %s（该格被大蒜封着）" % [
				card.card_name, cell])
		return null''', "field_state: place 闸门")

# ---------- ④ 存档 ----------
rep(P, '''		"trap_fields": _trap_fields_save(),''',
    '''		"trap_fields": _trap_fields_save(),
		"sealed_cells": _sealed_save(),''', "field_state: save_dict")

rep(P, '''	var tfl: Variant = d.get("trap_fields", [])
	if tfl is Array:
		for tf: Variant in tfl:
			if tf is Dictionary and (tf as Dictionary).has("id"):
				trap_fields[Vector2i(int(tf["r"]), int(tf["c"]))] = int(tf["id"])''',
    '''	var tfl: Variant = d.get("trap_fields", [])
	if tfl is Array:
		for tf: Variant in tfl:
			if tf is Dictionary and (tf as Dictionary).has("id"):
				trap_fields[Vector2i(int(tf["r"]), int(tf["c"]))] = int(tf["id"])
	sealed_cells.clear()
	var sfl: Variant = d.get("sealed_cells", [])
	if sfl is Array:
		for sf: Variant in sfl:
			if sf is Dictionary and int(sf.get("turns", 0)) > 0:
				sealed_cells[Vector2i(int(sf["r"]), int(sf["c"]))] = int(sf["turns"])''',
    "field_state: apply_dict")

rep(P, '''func _fields_save() -> Array:''', '''func _sealed_save() -> Array:
	## R839：封锁格的存档形态 —— 坐标 + 剩余回合（形制与 `_trap_fields_save` 同款）。
	var out: Array = []
	for cell: Vector2i in sealed_cells:
		out.append({"r": cell.x, "c": cell.y, "turns": int(sealed_cells[cell])})
	return out


func _fields_save() -> Array:''', "field_state: _sealed_save")
