extends SceneTree
## 诊断探针（R858 地图路线冗余度）：量化「这张图的路线是不是只剩一条」。
##
## 店长反馈的核心不是「格子太少」，而是**能走的路太少**：地图看着铺满 35 格，
## 实际从头到尾只有一条窄带，岔路都是死胡同，走进去只能原路退回。
##
## 指标（每张图）：
##   paths   起点 → 大宝箱的**不同简单路径条数**（截断 CAP，越小越窄）
##   must    起点 → 大宝箱的**必经边数**（删掉就断，= 1 意味着全程被串在一根链上）
##   cyc     「12 步内可达」子图的**独立环数** E - (V-1)（0 = 整块是树，走错必原路返回）
##   rowseg  每行横向被切成几段（7 格本该 1 段；>1 = 横向被切断）
##   leaf    门数 == 该格下界的格子数（视觉上的死胡同口）
##   deg     平均门数
##   vcols   每对相邻行之间的垂直边只集中在几列（越少越像「电梯」）

const SEEDS := 200
const CAP := 400
## ⚠️ 第一版没有限制 DFS 深度，35 格网格的**全部前缀路径**是指数级的（跑到 5 分钟没出结果）。
## 口径改成「巧克力够得着的路线」：深度上限 = MAX_STEPS（12），与游戏里真实可走的步数一致。
const BUDGET := 400000

func _bfs_reach(adj: Array, s: int, skip_a := -1, skip_b := -1) -> Dictionary:
	var seen := {s: true}
	var q := [s]
	var head := 0
	while head < q.size():
		var u := int(q[head])
		head += 1
		for nb in adj[u]:
			var v := int(nb)
			if seen.has(v):
				continue
			if (u == skip_a and v == skip_b) or (u == skip_b and v == skip_a):
				continue
			seen[v] = true
			q.append(v)
	return seen


func _dist_map(adj: Array, s: int) -> Dictionary:
	var d := {s: 0}
	var q := [s]
	var head := 0
	while head < q.size():
		var u := int(q[head])
		head += 1
		for nb in adj[u]:
			var v := int(nb)
			if not d.has(v):
				d[v] = int(d[u]) + 1
				q.append(v)
	return d


## 简单路径计数（DFS + 深度上限 + 截断）。
func _count_paths(adj: Array, s: int, t: int) -> int:
	var visited := {s: true}
	var n := [0, 0]          # [命中数, 已展开节点数]
	_dfs(adj, s, t, visited, n, 0)
	return int(n[0])


func _dfs(adj: Array, u: int, t: int, visited: Dictionary, n: Array, depth: int) -> void:
	if int(n[0]) >= CAP or int(n[1]) >= BUDGET:
		return
	n[1] = int(n[1]) + 1
	if u == t:
		n[0] = int(n[0]) + 1
		return
	if depth >= RogueMap.MAX_STEPS:
		return
	for nb in adj[u]:
		var v := int(nb)
		if visited.has(v):
			continue
		visited[v] = true
		_dfs(adj, v, t, visited, n, depth + 1)
		visited.erase(v)
		if int(n[0]) >= CAP or int(n[1]) >= BUDGET:
			return


func _edges(adj: Array) -> Array:
	var out: Array = []
	for a in adj.size():
		for nb in adj[a]:
			var b := int(nb)
			if b > a:
				out.append([a, b])
	return out


func _stats(cells: Array) -> Dictionary:
	var adj: Array = []
	for c: Dictionary in cells:
		adj.append((c.get("doors", []) as Array).duplicate())
	var start_i := RogueMap.idx(RogueMap.START_COL, RogueMap.START_ROW)
	var es := _edges(adj)
	var total_edges := es.size()
	# 必经边：删掉后起点到任一大宝箱都断 → 先看「到两个宝箱整体」
	var dist := _dist_map(adj, start_i)
	var targets: Array = []
	for p in RogueMap.BIGCHEST_POS:
		var i := RogueMap.idx(p.x, p.y)
		targets.append(i)
	# paths：两个大宝箱取较小值（最窄的那条才决定体感）
	var paths := 9999
	for t: int in targets:
		paths = mini(paths, _count_paths(adj, start_i, t))
	# must：删除该边后「至少一个宝箱变得不可达」的边数
	var must := 0
	for e: Array in es:
		var ok_all := true
		for t2: int in targets:
			if not _bfs_reach(adj, start_i, int(e[0]), int(e[1])).has(t2):
				ok_all = false
				break
		if not ok_all:
			must += 1
	# 12 步可达子图
	var near := {}
	for i in 35:
		if int(dist.get(i, 9999)) <= RogueMap.MAX_STEPS:
			near[i] = true
	var e_in := 0
	for e2: Array in es:
		if near.has(int(e2[0])) and near.has(int(e2[1])):
			e_in += 1
	var v := near.size()
	var cyc := e_in - (v - 1)
	# 行内横段数
	var rowseg := 0.0
	for row in RogueMap.ROWS:
		var seg := 1
		for col in RogueMap.COLS - 1:
			if not (adj[RogueMap.idx(col, row)] as Array).has(RogueMap.idx(col + 1, row)):
				seg += 1
		rowseg += float(seg)
	rowseg /= float(RogueMap.ROWS)
	# 死胡同 + 平均度
	var leaf := 0
	var deg_sum := 0
	for i in 35:
		var n := (adj[i] as Array).size()
		deg_sum += n
		if n <= RogueMap.lo_of(i):
			leaf += 1
	# 垂直边按列统计（每对行）
	var vcols: Array = []
	for row in RogueMap.ROWS - 1:
		var cols: Array = []
		for col in RogueMap.COLS:
			if (adj[RogueMap.idx(col, row)] as Array).has(RogueMap.idx(col, row + 1)):
				cols.append(col)
		vcols.append(cols.size())
	return {"paths": paths, "must": must, "cyc": cyc, "rowseg": rowseg,
			"leaf": leaf, "deg": float(deg_sum) / 35.0, "vcols": vcols,
			"edges": total_edges}


func _init() -> void:
	RunState.set_difficulty(1)
	var acc := {"paths": 0.0, "must": 0.0, "cyc": 0.0, "rowseg": 0.0,
			"leaf": 0.0, "deg": 0.0, "edges": 0.0}
	var hist := {}
	var single := 0
	var no_cycle := 0
	var vcol_hist := {0: 0, 1: 0, 2: 0, 3: 0, 4: 0}
	var n := 0
	var att_sum := 0
	var att_worst := 0
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 857000 + s * 7919
		var cells: Array = RogueMap.generate(rng, GameLayers.LAYER_DEFAULT)
		if cells.is_empty():
			continue
		var r := _stats(cells)
		n += 1
		att_sum += RogueMap.last_attempts
		att_worst = maxi(att_worst, RogueMap.last_attempts)
		if n % 20 == 0:
			print("  .. %d / %d" % [n, SEEDS])
		for k in acc:
			if k == "vcols":
				continue
			acc[k] += float(r[k])
		var p := int(r["paths"])
		if p <= 1:
			single += 1
		hist[p] = int(hist.get(p, 0)) + 1
		if int(r["cyc"]) <= 0:
			no_cycle += 1
		for k in (r["vcols"] as Array):
			var kv := int(k)
			vcol_hist[kv] = int(vcol_hist.get(kv, 0)) + 1
	print("===== R858 地图路线冗余度（%d 张）=====" % n)
	print("平均边数        : %.2f" % (acc["edges"] / float(n)))
	print("平均门数        : %.2f" % (acc["deg"] / float(n)))
	print("到宝箱路径条数  : 均值 %.2f（上限 %d）" % [acc["paths"] / float(n), CAP])
	print("  仅 1 条路径   : %d 张 = %.1f%%" % [single, 100.0 * float(single) / float(n)])
	print("必经边数(must)  : 均值 %.2f" % (acc["must"] / float(n)))
	print("可达子图环数    : 均值 %.2f；无环 %d 张 = %.1f%%" % [acc["cyc"] / float(n), no_cycle,
			100.0 * float(no_cycle) / float(n)])
	print("行内横向段数    : 均值 %.2f（1.0 = 每行贯通）" % (acc["rowseg"] / float(n)))
	print("死胡同格数      : 均值 %.2f / 35" % (acc["leaf"] / float(n)))
	print("行间垂直边列数  : 0列 %d / 1列 %d / 2列 %d / 3列 %d / 4列 %d" %
			[int(vcol_hist[0]), int(vcol_hist[1]), int(vcol_hist[2]),
			int(vcol_hist[3]), int(vcol_hist[4])])
	var keys := hist.keys()
	keys.sort()
	var seg := ""
	for k in keys:
		if seg != "":
			seg += "  "
		seg += "%d条:%d" % [int(k), int(hist[k])]
	print("路径数分布      : " + seg)
	print("重摇次数        : 均值 %.3f / 最差 %d" % [float(att_sum) / float(n), att_worst])
	quit()
