class_name RogueMap
extends RefCounted
## 格子地图生成（R128 重写）—— 7 列 × 5 行的相接正方形格子。
##
## 与旧版的根本区别：旧版是「14 个分层列、每列 2~5 个圆节点、层间连边」，
## 新版是**一张固定 5×7 的网格**，每格一个房间，房间之间由「门」相连。
## 玩家从最下一行中间出发，可以在网格上自由走动（走过的地方可以零消耗返回）。
##
## 坐标：col 0..6 横向（宽 7），row 0..4 纵向（高 5），**row = 0 是最上一行**。
## 玩家起点在最下一行中间 = (col 3, row 4)。
##
## 门的方向数约束（用户口径）：
##   * 四个角：**只有 1 个方向**（死路尽头）；
##   * 起点：2~3 个方向；
##   * 其他边缘格：**2~3** 个方向（R136：边缘但不是角的房间至少通 2 个）；
##   * 内部格：2~4 个方向。
## 门是**双向**的：A 有通往 B 的门 ⇔ B 有通往 A 的门（doors 对称，生成时保证）。
##
## 房间类型：
##   start 起点 / battle 战斗 / elite 精英 / rest 休息 / event 事件 /
##   chest 普通宝箱 / bigchest 大宝箱 / unknown 「?」（走进才揭晓）
## 固定格：起点 (3,4)；**左上 (0,0) 与右上 (6,0) 固定为大宝箱**。
## 「?」房的实际类型在**生成时**就定好（而非进入时抽）—— 这样休息点的
## 「不与起点相邻 / 不与另一个休息相邻」两条约束对隐藏房同样成立。
##
## 生成算法（R128 实验选定；R136 把「边缘非角」的下限提到 2 后重测 300 张：
##   平均 1.997 次重试、51% 一次成功、最差 9 次、0 失败）：
##   1) 骨架：每行横向全连（端点得 1 度、中间列得 2 度）；
##      **最左 / 最右两列的非角格再纵向串成链**（R136：边缘非角至少 2 个方向，
##      而这两列横向只有 1 条门，不补纵向就永远不达标）；
##      相邻两行之间在「非角列」随机连 1~3 条垂直边（保证行间连通）；
##   2) 随机加边：两端都还没到度数上限的边，按概率加（制造分支感）；
##   3) 随机删边：删后仍连通、且两端度数都不低于下界才真删（制造死路与岔路）；
##   4) 校验：度数区间 / 全连通 / 起点到两个大宝箱都不超过 MAX_STEPS 步；
##      任一项不过 → 整张重摇（最多 MAX_ATTEMPTS 次）。
##
## 「12 步内不可能同时进两个大宝箱」是**几何必然**，不用额外控制：
##   起点→上角曼哈顿距离 ≥ 3+4 = 7，两个上角之间 ≥ 6，所以
##   「先到任一大宝箱再赶去另一个」最少 13 步 > 12 步。生成时只需保证
##   **两个大宝箱各自 ≤ 12 步可达**（见 _validate）。

const COLS := 7                      # 横向格数
const ROWS := 5                      # 纵向格数
const CELLS := COLS * ROWS           # 35
const MAX_STEPS := 12                # 每层的巧克力块数 = 可探索的新房间数

## ⚠️ 门的存储口径：`cell["doors"]` 是**邻居房间的 id 列表**（不是方向索引）。
## 生成时邻接表就是按 id 建的，直接沿用最不容易出错；
## 需要「哪条边」时用 `dir_between(a_id, b_id)` 从两格坐标反算（只有画门用到）。

const START_COL := 3
const START_ROW := 4                                        # 最下一行
const START_POS := Vector2i(START_COL, START_ROW)
const BIGCHEST_POS := [Vector2i(0, 0), Vector2i(6, 0)]        # 左上 / 右上

const TYPE_LABELS := {
	"start": "起点", "battle": "战斗", "elite": "精英", "rest": "休息",
	"event": "事件", "chest": "宝箱", "bigchest": "大宝箱", "unknown": "未知",
}
## 格子正中间的短标记（没有对应图标素材时用）。
const TYPE_MARKS := {
	"start": "起", "battle": "战", "elite": "英", "rest": "息",
	"event": "事", "chest": "箱", "bigchest": "大", "unknown": "?",
}

const P_UNKNOWN := 0.28              # 「?」房占比（其余格直接写明类型）
const REST_MIN := 2                  # 每张地图的休息点数量区间
const REST_MAX := 4
## 普通格的类型权重（战斗为主，精英与宝箱略少）。
const WEIGHTS := {"battle": 6, "event": 3, "elite": 2, "chest": 2}
## 「?」房的实际类型权重 —— 用户口径：**精英与普通宝箱出现概率略低**。
const WEIGHTS_UNKNOWN := {"battle": 7, "event": 4, "elite": 1, "chest": 1}

const MAX_ATTEMPTS := 200
## 上一次 generate() 实际用了几次重摇（1 = 一次成功）。仅供测试与调参看；
## 生成结果本身与它无关（同一 rng 状态必然得到同一张图）。
static var last_attempts := 0


# ------------------------------------------------------------ 坐标工具

static func idx(col: int, row: int) -> int:
	return row * COLS + col


static func col_of(i: int) -> int:
	return i % COLS


static func row_of(i: int) -> int:
	return int(i / COLS) if i >= 0 else 0


static func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and col < COLS and row >= 0 and row < ROWS


static func is_corner(col: int, row: int) -> bool:
	return (col == 0 or col == COLS - 1) and (row == 0 or row == ROWS - 1)


static func is_edge(col: int, row: int) -> bool:
	return col == 0 or col == COLS - 1 or row == 0 or row == ROWS - 1


static func limits(col: int, row: int) -> Vector2i:
	## 该格门数的允许区间 (下界, 上界)。
	if is_corner(col, row):
		return Vector2i(1, 1)          # 四角只有 1 个方向
	if col == START_COL and row == START_ROW:
		return Vector2i(2, 3)          # 初始房间 2~3 个方向
	if is_edge(col, row):
		return Vector2i(2, 3)          # 其他边缘房间 2~3 个方向（R136：下限提到 2）
	return Vector2i(2, 4)              # 内部房间 2~4 个方向


static func lo_of(i: int) -> int:
	return limits(col_of(i), row_of(i)).x


static func hi_of(i: int) -> int:
	return limits(col_of(i), row_of(i)).y


static func is_bigchest(i: int) -> bool:
	for p in BIGCHEST_POS:
		if idx(p.x, p.y) == i:
			return true
	return false


# ------------------------------------------------------------ 生成

static func generate(rng: RandomNumberGenerator,
		layer := GameLayers.LAYER_DEFAULT) -> Array:
	## 生成一整张 5×7 地图（返回 35 个 cell 的数组，下标即 id）。
	## 完全确定：同一 rng 状态必然得到同一张图（重试次数也确定）。
	for attempt in MAX_ATTEMPTS:
		var adj := _build_adjacency(rng)
		if adj.is_empty():
			continue
		last_attempts = attempt + 1
		return _make_cells(adj, rng, layer)
	push_error("RogueMap：%d 次尝试仍未生成满足约束的 5×7 地图" % MAX_ATTEMPTS)
	return []


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	## ⚠️ 只能用这个，**不要用 `Array.shuffle()`** —— 后者走全局随机源，
	## 录像回放（同一种子）会得到不同的地图。Fisher-Yates 手工版走传入的 rng。
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t


static func _link(adj: Array, a: int, b: int) -> void:
	if not (adj[a] as Array).has(b):
		(adj[a] as Array).append(b)
	if not (adj[b] as Array).has(a):
		(adj[b] as Array).append(a)


static func _unlink(adj: Array, a: int, b: int) -> void:
	(adj[a] as Array).erase(b)
	(adj[b] as Array).erase(a)


static func _build_adjacency(rng: RandomNumberGenerator) -> Array:
	## 生成门的邻接表（Array[35] of Array[int]）。不满足约束时返回空数组。
	var adj: Array = []
	for i in CELLS:
		adj.append([])

	# --- 骨架 1：每行横向全连（端点得 1 度，中间列得 2 度；四角因此恰好 1 度）
	for row in ROWS:
		for col in COLS - 1:
			_link(adj, idx(col, row), idx(col + 1, row))

	# --- 骨架 1.5（R136）：最左 / 最右两列的**非角**格横向只有 1 条门，
	#     而「边缘非角 ≥ 2 个方向」是硬约束 → 这两列必须各自纵向串成一条链：
	#     (0,1)-(0,2)-(0,3) 与 (6,1)-(6,2)-(6,3)。缺任何一条，那一格就只剩 1 度，
	#     整张图判不合格 → 实测会让生成几乎必然失败（只能靠重摇，代价极高）。
	#     角格的垂直边仍然**永不加**（角的上限 1 要留给水平边）。
	for c in [0, COLS - 1]:
		for row in range(1, ROWS - 2):
			_link(adj, idx(c, row), idx(c, row + 1))

	# --- 骨架 2：相邻两行之间随机连 1~3 条垂直边（行间连通）
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

	# --- 随机加边（两端都还没到上限才加）
	var extra: Array = []
	for row in ROWS:
		for col in COLS:
			if col + 1 < COLS:
				extra.append([idx(col, row), idx(col + 1, row)])
			if row + 1 < ROWS and not is_corner(col, row) and not is_corner(col, row + 1):
				extra.append([idx(col, row), idx(col, row + 1)])
	_shuffle(extra, rng)
	for e: Array in extra:
		var a: int = e[0]
		var b: int = e[1]
		if (adj[a] as Array).size() < hi_of(a) and (adj[b] as Array).size() < hi_of(b) \
				and not (adj[a] as Array).has(b):
			if rng.randf() < 0.55:
				_link(adj, a, b)

	# --- 随机删边：制造死路与不规则岔口（删后必须仍连通且不破度数下界）
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
		if (adj[a] as Array).size() >= lo_of(a) and (adj[b] as Array).size() >= lo_of(b) \
				and _reach_count(adj, start_i) == CELLS:
			done += 1
		else:
			_link(adj, a, b)

	return _validate(adj, start_i)


static func _validate(adj: Array, start_i: int) -> Array:
	## 校验并返回邻接表；任一项不过就返回空数组（交给上层重摇）。
	for i in CELLS:
		var n: int = (adj[i] as Array).size()
		if n < lo_of(i) or n > hi_of(i):
			return []
	if _reach_count(adj, start_i) != CELLS:
		return []
	var dist := _bfs(adj, start_i)
	for p in BIGCHEST_POS:
		if int(dist.get(idx(p.x, p.y), 9999)) > MAX_STEPS:
			return []      # 大宝箱必须在 12 步内可达
	return adj


static func _reach_count(adj: Array, src: int) -> int:
	var seen := {src: true}
	var queue: Array = [src]
	while not queue.is_empty():
		var u: int = queue.pop_front()
		for v: int in adj[u]:
			if not seen.has(v):
				seen[v] = true
				queue.append(v)
	return seen.size()


static func _bfs(adj: Array, src: int) -> Dictionary:
	## 从 src 出发的步数表（id -> 步数）。
	var dist := {src: 0}
	var queue: Array = [src]
	while not queue.is_empty():
		var u: int = queue.pop_front()
		for v: int in adj[u]:
			if not dist.has(v):
				dist[v] = int(dist[u]) + 1
				queue.append(v)
	return dist


static func _make_cells(adj: Array, rng: RandomNumberGenerator, layer: int) -> Array:
	## 把邻接表定型成 35 个 cell 字典。
	var start_i := idx(START_COL, START_ROW)

	# --- 休息点位置：全局先定（起点与两个大宝箱不参与）
	var rest_set := {}
	var cands: Array = []
	for i in CELLS:
		if i == start_i or is_bigchest(i):
			continue
		cands.append(i)
	_shuffle(cands, rng)
	var want_rest: int = rng.randi_range(REST_MIN, REST_MAX)
	for i: int in cands:
		if rest_set.size() >= want_rest:
			break
		# 约束：休息点不与起点相邻，也不与另一个休息点相邻
		var ok := true
		for nb: int in adj[i]:
			if nb == start_i or rest_set.has(nb):
				ok = false
				break
		if ok:
			rest_set[i] = true

	# --- 逐格定类型
	var used_events := {}
	var cells: Array = []
	for i in CELLS:
		var type := "battle"
		var hidden := false
		if i == start_i:
			type = "start"
		elif is_bigchest(i):
			type = "bigchest"
		elif rest_set.has(i):
			type = "rest"
		else:
			# 「?」房的实际类型在生成时就定（约束才对隐藏房生效），
			# 只是**先不告诉玩家**，走进才揭晓。
			hidden = rng.randf() < P_UNKNOWN
			type = _weighted(WEIGHTS_UNKNOWN if hidden else WEIGHTS, rng)
		var cell := {
			"id": i,
			"col": col_of(i), "row": row_of(i),
			"type": type,
			"hidden": hidden,             # 是「?」房（揭晓前不显示真实类型）
			"revealed": not hidden,       # 是否已揭晓（非隐藏房一开始就是明的）
			"doors": (adj[i] as Array).duplicate(),
			"layer": layer,
			"event_kind": "",
		}
		if type == "event":
			# 事件子类型：本张地图上不重复（全出过一遍后才允许重复）。
			cell["event_kind"] = GameLayers.roll_event_kind(layer, rng, used_events)
		cells.append(cell)
	return cells


static func _weighted(w: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in w:
		total += int(w[k])
	if total <= 0:
		return "battle"
	var roll := rng.randi_range(1, total)
	for k in w:
		roll -= int(w[k])
		if roll <= 0:
			return str(k)
	return "battle"


# ------------------------------------------------------------ 查询（消费方 / 测试共用）

static func cell_at(cells: Array, col: int, row: int) -> Dictionary:
	if not in_bounds(col, row):
		return {}
	return cells[idx(col, row)]


static func start_cell(cells: Array) -> Dictionary:
	if cells.size() != CELLS:
		return {}
	return cells[idx(START_COL, START_ROW)]


static func neighbor_ids(cell: Dictionary) -> Array:
	## 该格所有「有门」的邻居房间 id（`doors` 本身就是 id 列表）。
	if cell.is_empty():
		return []
	return (cell["doors"] as Array).duplicate()


static func dir_between(a_id: int, b_id: int) -> Vector2i:
	## 从格 a 指向格 b 的**方向增量**（只用于画门；不是正交相邻则返回 ZERO）。
	if a_id < 0 or b_id < 0 or a_id >= CELLS or b_id >= CELLS:
		return Vector2i.ZERO
	var d := Vector2i(col_of(b_id) - col_of(a_id), row_of(b_id) - row_of(a_id))
	if absi(d.x) + absi(d.y) != 1:
		return Vector2i.ZERO
	return d


static func has_door_to(cell: Dictionary, other_id: int) -> bool:
	return neighbor_ids(cell).has(other_id)


static func doors_between(cells: Array, a_id: int, b_id: int) -> bool:
	## 两个格之间是否真的有门（双向校验，防单向 bug）。
	if a_id < 0 or b_id < 0 or a_id >= cells.size() or b_id >= cells.size():
		return false
	return neighbor_ids(cells[a_id]).has(b_id) \
			and neighbor_ids(cells[b_id]).has(a_id)


static func steps_from(cells: Array, from_id: int) -> Dictionary:
	## 从某格出发的步数表（id -> 步数）。只走有门的相邻格。
	var adj: Array = []
	for c: Dictionary in cells:
		adj.append(neighbor_ids(c))
	if from_id < 0 or from_id >= adj.size():
		return {}
	return _bfs(adj, from_id)


static func display_type(cell: Dictionary) -> String:
	## 玩家**当前能看到**的类型：隐藏房未揭晓时一律显示「?」。
	if cell.is_empty():
		return ""
	if bool(cell.get("hidden", false)) and not bool(cell.get("revealed", false)):
		return "unknown"
	return str(cell["type"])


static func type_label(type: String) -> String:
	return str(TYPE_LABELS.get(type, type))


static func type_mark(type: String) -> String:
	return str(TYPE_MARKS.get(type, "?"))


static func all_nodes(cells: Array) -> Array:
	## 兼容旧调用点的别名（旧版是 columns 的扁平化）。返回全部 cell。
	return cells
