# -*- coding: utf-8 -*-
"""R858b：生成期加一条「路线冗余」结构校验 —— 把剩下 4.5% 的单行图也挡掉。

判据：起点 → 两个大宝箱，各要有 **≥2 条不同的简单路径**（限深 MAX_STEPS，
因为一层只有 12 块巧克力，走不完的路线不算「选择」）。
不过就整张重摇（与现有结构校验同一出口）。

⚠️ 不要求「边不相交」：大宝箱在角上、角格上限 1 度 → 通往它的最后一条边
   必然是必经边，任何图都过不了 2-边连通。所以口径只能落在「简单路径条数」。
"""
from pathlib import Path

path = Path(__file__).resolve().parent.parent / "scripts" / "rogue_map.gd"
raw = path.read_bytes()
crlf = b"\r\n" in raw
text = raw.decode("utf-8").replace("\r\n", "\n")

ANCHOR = """	for p in BIGCHEST_POS:
		if int(dist.get(idx(p.x, p.y), 9999)) > MAX_STEPS:
			return []
	return adj
"""

NEW = """	for p in BIGCHEST_POS:
		var bi := idx(p.x, p.y)
		if int(dist.get(bi, 9999)) > MAX_STEPS:
			return []
		# R858（用户口径「避免极端单行路线」）：**宝箱至少要有两条走法**。
		# 只判「可达」是不够的 —— 实测有 4.5% 的图连一条岔路都没有，玩家从起点
		# 到宝箱只有唯一一条线，中途没有第二次选择，整张图就成了店长截图里那种窄带。
		# ⚠️ 口径是「不同简单路径条数 ≥2」而不是「边不相交」：大宝箱在角上、
		#    角格上限 1 度，通往它的最后一条边必然必经，2-边连通永远过不了。
		# ⚠️ 深度上限取 MAX_STEPS：巧克力走不完的绕路，对玩家不构成「选择」。
		if _route_count(adj, start_i, bi, 2) < 2:
			return []
	return adj


static func _route_count(adj: Array, src: int, dst: int, cap: int = 2) -> int:
	## R858：从 src 到 dst 的**不同简单路径**条数（限深 MAX_STEPS，数到 cap 即停）。
	## 只用于生成期校验，`cap` 一律给小值（2）—— 我们只关心「有没有第二条」。
	var visited := {src: true}
	var counter := [0, 0]        # [命中数, 已展开节点数]
	_route_dfs(adj, src, dst, visited, counter, 0, cap)
	return int(counter[0])


static func _route_dfs(adj: Array, u: int, dst: int, visited: Dictionary, counter: Array,
		depth: int, cap: int) -> void:
	if int(counter[0]) >= cap or int(counter[1]) >= 20000:
		return
	counter[1] = int(counter[1]) + 1
	if u == dst:
		counter[0] = int(counter[0]) + 1
		return
	if depth >= MAX_STEPS:
		return
	for nb in adj[u]:
		var v := int(nb)
		if visited.has(v):
			continue
		visited[v] = true
		_route_dfs(adj, v, dst, visited, counter, depth + 1, cap)
		visited.erase(v)
		if int(counter[0]) >= cap:
			return
"""

n = text.count(ANCHOR)
assert n == 1, "锚点命中 %d 次（应为 1）" % n
text = text.replace(ANCHOR, NEW)
out = text.replace("\n", "\r\n") if crlf else text
path.write_bytes(out.encode("utf-8"))
print("✓ 已加 _route_count 校验")
