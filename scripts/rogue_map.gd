class_name RogueMap
extends RefCounted
## 肉鸽地图生成（参考杀戮尖塔）：起点 + 12 个普通层 + Boss，共 14 层，
## 自下而上推进，最上层为 Boss。
## 节点类型七种：起点 start / 普通战斗 battle / 精英战斗 elite / 休息 rest /
## 事件 event / 宝箱层 chest / Boss boss。
##
## 分层（layer）：一张地图属于某一层（generate 的 layer 参数，默认第一层），
## 每个节点都带 `layer` 字段。节点类型不变，但「事件子类型」与「宝箱层所在列」
## 都按层从 GameLayers 取 —— 所以第一层地图只会出现第一层的事件，
## 日后新增的层可以有完全不同的事件池 / 宝箱层配置。
##
## 结构规则：
##   * 第 0 层（起点）1 个起点节点（非战斗，玩家从这里出发）；
##     最后一层 1 个 Boss 节点；中间 12 层各 2~5 个节点
##     （除起点/Boss 外每层至少 2 个节点，不留只有 1 个节点的孤单层）；
##   * **第 REST_COL（9）层整层固定为休息**（R69）：所有路线都会经过这一层，
##     且这一层必定能休息回血。它前后的两层（第 8、10 层）**禁止出休息**，
##     否则会与固定休息层连成两连休（见 _assign_types 里的 rest_blocked_by_fixed_layer）；
##   * 宝箱层固定在 GameLayers.treasure_col(layer) 指定的那一列
##     （第一层 = 第 6 层）：该层节点全部是宝箱，开箱即得 1 个随机奖励道具
##     （不与已拥有的重复），不参与普通类型抽取；配置为 -1 时本层没有宝箱层；
##   * 严格逐层推进：N 层只能连到 N+1 层（不跳跃、不返回）；
##   * 连边为直线且互不交叉：层内节点按 slot 排序（row = slot 的名次），
##     目标节点按比例单调映射到源节点（单调 ⇒ 直线不交叉），
##     额外边只允许「共享相邻源的边界目标」，同样不交叉；
##   * 每个节点至少 1 条出边（无死路）、每个目标至少 1 条入边（全部可达）；
##   * 每层节点随机分布到 5 个横向槽位（slot 0~4，同层不重复），
##     起点与 Boss 固定居中（slot 2）；
##   * 类型按层加权抽取：休息/精英出现概率较低，且沿任意一条路线
##     （起点 → Boss 的路径）最多 REST_CAP 个休息、最多 ELITE_CAP 个精英；
##     **固定休息层必然占用 1 个休息额度**（rest_cnt 从它开始至少为 1）；
##   * 休息点不出现在第一层（col == 1），且**不会连续出现**——
##     只要有一个前驱是休息，该节点就不能再是休息（见 _assign_types）；
##   * 战斗关卡不在生成时分配——由 RunState.next_level 在进入节点时
##     按「本局已胜利的战斗数」动态决定难度（前 2 场简单，之后困难）。
##
## 节点结构：{id, col, row, slot, type, layer, next: [下节点 id],
##            event_kind（type=event 时：本层事件池里的一个子类型，见 GameLayers）,
##            rest_cnt/elite_cnt（内部：起点到此的路径最大累计数）}

const COLS := 14                 # 起点 + 12 个普通层（含第 6 层宝箱层 + 第 9 层固定休息层）+ Boss
const REST_COL := 9              # 固定休息层（R69）：整层都是休息，所有路线必经
const TREASURE_COL := 6          # 第一层宝箱层的列号（= GameLayers.treasure_col(1)，仅作引用兼容）
const MIN_NODES := 2             # 中间层最少节点数（除起点/Boss，不留单节点层）
const MAX_NODES := 5             # 中间层最多节点数
const REST_CAP := 3              # 任意一条路线上最多 3 个休息（含固定休息层那 1 个）
const ELITE_CAP := 3             # 任意一条路线上最多 3 个精英

const TYPE_LABELS := {
	"start": "起点", "battle": "战斗", "elite": "精英",
	"rest": "休息", "event": "事件", "chest": "宝箱层", "boss": "Boss",
}


static func generate(rng: RandomNumberGenerator,
		layer := GameLayers.LAYER_DEFAULT) -> Array:
	## 生成整张地图：columns[col] = [node, ...]（node.row 按 slot 升序编号）。
	## layer = 本张地图所属的层（决定事件池与宝箱层位置，默认第一层）；
	## 生成的每个节点都带上该 layer，关卡/事件在进入节点时按层取。
	var columns: Array = []
	var nid := 0
	for col in COLS:
		var count := 1 if (col == 0 or col == COLS - 1) \
				else rng.randi_range(MIN_NODES, MAX_NODES)
		var slots := _slots_for(count, rng)
		var col_nodes: Array = []
		for i in count:
			var node := {
				"id": nid, "col": col, "row": i, "slot": slots[i],
				"type": "start" if col == 0 else "boss" if col == COLS - 1 else "battle",
				"layer": layer, "level": {}, "next": [],
			}
			nid += 1
			col_nodes.append(node)
		columns.append(col_nodes)
	_connect(columns, rng)
	# 不变量：固定休息层不能与本层宝箱层撞列（两者都是「整层强制类型」，
	# 撞列时谁生效取决于 _assign_types 里的分支先后，太脆）。源头挡掉 + 交给回归锁。
	var tcol := GameLayers.treasure_col(layer)
	if tcol == REST_COL:
		push_error("RogueMap：宝箱层列号 %d 与固定休息层 REST_COL 撞列，本层地图不可用" % tcol)
	_assign_types(columns, rng, layer)
	return columns


static func _slots_for(count: int, rng: RandomNumberGenerator) -> Array:
	## 从 5 个横向槽位随机抽 count 个不重复槽位（升序返回 ⇒ row 按 slot 排序）。
	## 单节点层（起点/Boss）固定居中槽位 2。
	if count == 1:
		return [2]
	var all := [0, 1, 2, 3, 4]
	for i in range(all.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = all[i]
		all[i] = all[j]
		all[j] = tmp
	var out: Array = all.slice(0, count)
	out.sort()
	return out


static func _connect(columns: Array, rng: RandomNumberGenerator) -> void:
	## 相邻层连边：只连下一层（严格逐层推进），直线且互不交叉。
	## 构造：层内节点按 row 排序，对下一层目标 t 令 s(t) = t*m/n
	## （单调不减 ⇒ 任意两条边不交叉）；没有出边的源节点补一条
	## 「前一源的最大目标」（保持单调）；再按概率加共享边界目标的
	## 额外分叉边（max_t(i) ≤ min_t(i+1) 恒成立 ⇒ 依然不交叉）。
	for col in columns.size() - 1:
		var cur: Array = columns[col]
		var nxt: Array = columns[col + 1]
		var m := cur.size()
		var n := nxt.size()
		var tgt_of: Array = []
		for i in m:
			tgt_of.append([])
		# 主边：目标 t → 源 s(t) = t*m/n（覆盖所有目标，映射单调）
		for t in n:
			(tgt_of[mini(t * m / n, m - 1)] as Array).append(t)
		# 没有出边的源节点：补「前一个源的最大目标」（或后继源的首目标）
		for i in m:
			if (tgt_of[i] as Array).is_empty():
				for j in range(i - 1, -1, -1):
					if not (tgt_of[j] as Array).is_empty():
						(tgt_of[i] as Array).append((tgt_of[j] as Array)[-1])
						break
				if (tgt_of[i] as Array).is_empty():
					for j in range(i + 1, m):
						if not (tgt_of[j] as Array).is_empty():
							(tgt_of[i] as Array).append((tgt_of[j] as Array)[0])
							break
		# 写入主边；每个层间边界最多加一条共享边（前向/后向二选一，
		# 否则两侧扇形区间重叠会交叉），保持 max_t(i) ≤ min_t(i+1)。
		for i in m:
			for t in (tgt_of[i] as Array):
				var tid: int = int(nxt[t]["id"])
				if not cur[i]["next"].has(tid):
					cur[i]["next"].append(tid)
		for i in m - 1:
			var roll := rng.randf()
			if roll < 0.4:
				# 前向共享：源 i 额外连到源 i+1 的首目标
				if not (tgt_of[i + 1] as Array).is_empty():
					var tid2: int = int(nxt[(tgt_of[i + 1] as Array)[0]]["id"])
					if not cur[i]["next"].has(tid2):
						cur[i]["next"].append(tid2)
			elif roll < 0.6:
				# 后向共享：源 i+1 额外连到源 i 的末目标
				if not (tgt_of[i] as Array).is_empty():
					var tid3: int = int(nxt[(tgt_of[i] as Array)[-1]]["id"])
					if not cur[i + 1]["next"].has(tid3):
						cur[i + 1]["next"].append(tid3)


static func _elite_weight(col: int) -> int:
	## 精英权重随层数缓升（概率保持较低）：1-3 层 0，4-6 层 1，7-9 层 2，10 层起 3。
	## 公式按 col 算，地图加长（R69：中间层 11 → 12）不用改这里 —— 只是末档多一层。
	return clampi((col - 1) / 3, 0, 3)


static func _pick_type(col: int, rng: RandomNumberGenerator,
		allow_rest: bool, allow_elite: bool, allow_event: bool) -> String:
	## 中间层类型加权抽取：战斗为主，休息/事件低概率，精英随层数缓升。
	## allow_event = 本层是否配了事件内容（没配就不生成事件节点）。
	if col <= 0:
		return "start"
	if col >= COLS - 1:
		return "boss"
	var weights := {
		"battle": 6,
		"event": 1 if allow_event else 0,
		"rest": 1 if allow_rest else 0,
		"elite": _elite_weight(col) if allow_elite else 0,
	}
	var total := 0
	for t in weights:
		total += int(weights[t])
	var roll := rng.randi_range(1, total)
	for t in weights:
		roll -= int(weights[t])
		if roll <= 0:
			return str(t)
	return "battle"


static func _assign_types(columns: Array, rng: RandomNumberGenerator,
		layer := GameLayers.LAYER_DEFAULT) -> void:
	## 逐层确定中间层节点类型。rest_cnt/elite_cnt = 从起点到该节点的
	## 任意路径上的最大累计数；达到上限的层不再出休息/精英，
	## 从而保证任意一条完整路线 ≤ REST_CAP 个休息、≤ ELITE_CAP 个精英。
	## **休息不连续**：若本节点任一前驱是休息，则本节点禁止出休息
	##（前驱类型在上一列就已定，所以逐层向下走时判定是可靠的）。
	## **固定休息层（R69）**：第 REST_COL 层整层强制休息，且它**前后两层禁止出休息**
	##（`_adjacent_to_rest_col`）—— 否则会连成两连休，而「看前驱」那条规则管不到它。
	## 事件子类型与宝箱层位置都按 layer 从 GameLayers 取（内容按层隔离）。
	var tcol := GameLayers.treasure_col(layer)          # 本层宝箱层列号（-1 = 无）
	var layer_has_events := GameLayers.has_events(layer)  # 本层有没有事件内容
	# R68：本张地图已出过的**事件子类型**。同一张地图上一种事件只出一次，
	# 全部子类型都出过了才允许重复（规则与清空逻辑都在 GameLayers.roll_event_kind）。
	var used_event_kinds := {}
	for col in range(1, columns.size()):
		for node in columns[col]:
			if col >= columns.size() - 1:
				continue   # Boss 层固定
			var r := 0
			var e := 0
			var parent_rest := false      # 有没有前驱是休息（连续休息判定）
			for parent in columns[col - 1]:
				if (parent["next"] as Array).has(int(node["id"])):
					r = maxi(r, int(parent.get("rest_cnt", 0)))
					e = maxi(e, int(parent.get("elite_cnt", 0)))
					if str(parent.get("type", "")) == "rest":
						parent_rest = true
			# 宝箱层（本层由 GameLayers 指定的那一列）：整层都是宝箱，
			# 不参与普通类型抽取，计数原样继承（宝箱既不算休息也不算精英）。
			if col == tcol:
				node["type"] = "chest"
				node["rest_cnt"] = r
				node["elite_cnt"] = e
				continue
			# **固定休息层（R69）**：整层必定是休息，所有路线都经过它。
			# 这层不算「随机抽取」，所以也不受 allow_rest 的两种限制
			# （起步不出休息 / 前驱是休息）影响 —— 它就是设计上的必经回血点。
			# rest_cnt 从这里开始至少为 1（那 1 个额度已用掉，后面只剩 REST_CAP-1 次随机休息）。
			if col == REST_COL:
				node["type"] = "rest"
				node["rest_cnt"] = r + 1
				node["elite_cnt"] = e
				continue
			# 休息点不出现在第一层（col == 1）：起步就休息太安逸；
			# 也不允许连续休息（parent_rest）：连着两层休息太廉价。
			# **固定休息层前后两层额外禁休息**（R69）：那一层必定是休息，若它前后
			# 还随机出休息就会连成两连休，而这条规则是「逐节点看前驱」判定不出来的
			#（第 8 层的前驱在第 7 层，第 10 层的前驱才是固定休息层）。
			var rest_ok: bool = r < REST_CAP and col > 1 and not parent_rest \
					and not _adjacent_to_rest_col(col)
			var type := _pick_type(col, rng,
					rest_ok, e < ELITE_CAP,
					layer_has_events)
			node["type"] = type
			node["rest_cnt"] = r + (1 if type == "rest" else 0)
			node["elite_cnt"] = e + (1 if type == "elite" else 0)
			if type == "event":
				# 事件子类型：按本层的事件池加权抽取（第一层的事件与权重见
				# GameLayers.LAYERS；别的层可以配一套完全不同的事件）。
				# R68：传 used_event_kinds → 本张地图上不重复，全出过一遍后才重复。
				node["event_kind"] = GameLayers.roll_event_kind(layer, rng, used_event_kinds)


static func _adjacent_to_rest_col(col: int) -> bool:
	## 本层是否**紧邻固定休息层**（R69）—— 那两层禁止出休息，否则连成两连休。
	return col == REST_COL - 1 or col == REST_COL + 1


# ------------------------------------------------------------ 校验（测试用）

static func reachable_ids(columns: Array) -> Array[int]:
	## 从起点沿 next 边可达的全部节点 id（应等于全部节点）。
	var out: Array[int] = []
	if columns.is_empty() or columns[0].is_empty():
		return out
	var queue: Array = [int(columns[0][0]["id"])]
	var seen := {}
	while not queue.is_empty():
		var id: int = queue.pop_front()
		if seen.has(id):
			continue
		seen[id] = true
		out.append(id)
		for node in _all_nodes(columns):
			if int(node["id"]) == id:
				for nid in node["next"]:
					queue.append(int(nid))
				break
	return out


static func _all_nodes(columns: Array) -> Array:
	var out: Array = []
	for col_nodes in columns:
		out.append_array(col_nodes)
	return out
