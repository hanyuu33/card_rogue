# -*- coding: utf-8 -*-
"""R858：地图路线冗余度补丁 —— 让「整层只有一条窄带」不再出现。

改动两处（都在 RogueMap._build_adjacency）：
  ① 行间垂直边 1~3 条 → **每对相邻行强制左区一条 + 右区一条**（col 1/2 与 col 4/5），
     再随机补 0~2 条（含中列 3）→ 纵向上升路线天然分岔，而不是一根「电梯」。
  ② 随机删边拆成两组：垂直边 quota 4~9；横向边 quota 0~2 且**同一行最多删 1 条**。
     原来 6~16 条在全局打乱后删，横边占 71% → 等于专门切横向廊道（行内段数 1.96）。

跑法：python tools/_patch_r857_map.py
"""
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "scripts" / "rogue_map.gd"
raw = path.read_bytes()
crlf = b"\r\n" in raw
text = raw.decode("utf-8").replace("\r\n", "\n")
print("行尾：", "CRLF" if crlf else "LF")


def sub(old: str, new: str, tag: str) -> None:
    global text
    n = text.count(old)
    assert n == 1, "%s：锚点命中 %d 次（应为 1）" % (tag, n)
    text = text.replace(old, new)
    print("✓ %s" % tag)


OLD_SKEL2 = """	# --- 骨架 2：相邻两行之间随机连 1~3 条垂直边（行间连通）
	#     ⚠️ 角的垂直边**永不加**：角的上限就是 1，那条额度必须留给水平边，
	#     否则角会变成 2 度。
	for row in ROWS - 1:
		var cols: Array = []
		for col in COLS:
			if is_corner(col, row) or is_corner(col, row + 1):
				continue
			cols.append(col)
		_shuffle(cols, rng)
		var k: int = mini(rng.randi_range(1, 3), cols.size())
		for j in k:
			_link(adj, idx(int(cols[j]), row), idx(int(cols[j]), row + 1))
"""

NEW_SKEL2 = """	# --- 骨架 2：相邻两行之间**左区一条 + 右区一条**，再随机补 0~2 条（行间连通）
	#     ⚠️ 角的垂直边**永不加**：角的上限就是 1，那条额度必须留给水平边，
	#     否则角会变成 2 度。候选列因此只可能是 1..5。
	#     R858（用户口径「避免极端单行路线」）：原来这里是 `randi_range(1, 3)` 条、
	#     且列完全是 shuffle 出来的 —— 实测每对行常常只有 1 条通道、还和上一行的
	#     通道挤在相邻列，纵向走起来就是一根「电梯」，玩家没有第二条上升路。
	#     现在把左右两个区各钉一条，两行的通道天然分居画面两侧 → 上升必然分岔；
	#     中间再补 0~2 条制造不规则（中列 3 优先参与，视觉上像第三条主廊）。
	for row in ROWS - 1:
		var lzone: Array = [1, 2]
		var rzone: Array = [4, 5]
		_shuffle(lzone, rng)
		_shuffle(rzone, rng)
		_link(adj, idx(int(lzone[0]), row), idx(int(lzone[0]), row + 1))
		_link(adj, idx(int(rzone[0]), row), idx(int(rzone[0]), row + 1))
		var mzone: Array = [3, int(lzone[1]), int(rzone[1])]
		_shuffle(mzone, rng)
		var extra_k: int = rng.randi_range(0, 2)
		for j in extra_k:
			_link(adj, idx(int(mzone[j]), row), idx(int(mzone[j]), row + 1))
"""

OLD_DEL = """	# --- 随机删边：制造死路与不规则岔口（删后必须仍连通且不破度数下界）
	var cur: Array = []
	for a in CELLS:
		for b: int in adj[a]:
			if b > a:
				cur.append([a, b])
	_shuffle(cur, rng)
	var quota: int = rng.randi_range(6, 16)
	var done := 0
	var start_i := idx(START_COL, START_ROW)
	for e: Array in cur:
		if done >= quota:
			break
		var a: int = e[0]
		var b: int = e[1]
		if not (adj[a] as Array).has(b):
			continue
		_unlink(adj, a, b)
		if (adj[a] as Array).size() >= lo_of(a) and (adj[b] as Array).size() >= lo_of(b) \\
				and _reach_count(adj, start_i) == CELLS:
			done += 1
		else:
			_link(adj, a, b)
"""

NEW_DEL = """	# --- 随机删边：制造死路与不规则岔口（删后必须仍连通且不破度数下界）
	#     R858：**横向边与垂直边分开算额度**。
	#     原来是一锅端打乱后删 6~16 条，而横向边占全部边的 ~71% —— 等于每张图都
	#     平均砍掉 8 条横廊，七格一行被切成近两段（实测 rowseg 1.96）。玩家看到的
	#     「一条窄带」就是这些断口串起来的。
	#     现在：垂直边额度 4~9（不规则感主要来自这里）；横向边额度 0~2，
	#     且**同一行最多删 1 条** —— 这样任意一行的横向最多被切一刀，
	#     「这一行还能横着走」几乎永远成立。
	var vcur: Array = []
	var hcur: Array = []
	for a in CELLS:
		for b: int in adj[a]:
			if b <= a:
				continue
			if row_of(a) == row_of(b):
				hcur.append([a, b])
			else:
				vcur.append([a, b])
	_shuffle(vcur, rng)
	_shuffle(hcur, rng)
	var start_i := idx(START_COL, START_ROW)
	var vquota: int = rng.randi_range(4, 9)
	var hquota: int = rng.randi_range(0, 2)
	var vdone := 0
	for e: Array in vcur:
		if vdone >= vquota:
			break
		var a: int = e[0]
		var b: int = e[1]
		if not (adj[a] as Array).has(b):
			continue
		_unlink(adj, a, b)
		if (adj[a] as Array).size() >= lo_of(a) and (adj[b] as Array).size() >= lo_of(b) \\
				and _reach_count(adj, start_i) == CELLS:
			vdone += 1
		else:
			_link(adj, a, b)
	var hdone := 0
	var hrow_used := {}
	for e2: Array in hcur:
		if hdone >= hquota:
			break
		var a2: int = e2[0]
		var b2: int = e2[1]
		if not (adj[a2] as Array).has(b2):
			continue
		var r2 := row_of(a2)
		if hrow_used.has(r2):
			continue          # 同一行只许切一刀
		_unlink(adj, a2, b2)
		if (adj[a2] as Array).size() >= lo_of(a2) and (adj[b2] as Array).size() >= lo_of(b2) \\
				and _reach_count(adj, start_i) == CELLS:
			hdone += 1
			hrow_used[r2] = true
		else:
			_link(adj, a2, b2)
"""

sub(OLD_SKEL2, NEW_SKEL2, "骨架 2：行间垂直边左右分居")
sub(OLD_DEL, NEW_DEL, "随机删边：横/纵分账 + 每行最多一刀")

out = text.replace("\n", "\r\n") if crlf else text
path.write_bytes(out.encode("utf-8"))
print("已写回：", path)
