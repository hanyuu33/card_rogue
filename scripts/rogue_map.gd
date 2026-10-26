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
## 固定格（R243）：起点 (3,4)；**左上 (0,0) 固定为大宝箱**、**右上 (6,0) 固定为商店**。
## 普通宝箱（chest）**不再出现在明格**：只有「?」房里有概率藏一个（见 `WEIGHTS_UNKNOWN`）。
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
##   4) 校验（结构层，`_validate`）：度数区间 / 全连通 /
##      起点到两个大宝箱都不超过 MAX_STEPS 步；
##   5) 校验（内容层，`exits_reach_chest`，R142）：**起点的每一个邻居都必须
##      「不经过起点也能走到某个宝箱房」** —— 否则玩家第一步拐进那条路，
##      之后就只能原路折返才能到宝箱（用户口径：无论第一步走哪格，
##      都应该能一路向前走到宝箱）。宝箱房 = chest / bigchest，
##      「?」房按它生成时定好的真实类型算。
##      任一项不过 → 整张重摇（最多 MAX_ATTEMPTS 次）。
##   内容层的校验必须**等类型摇完**才判得出来（宝箱是一种「类型」）→ 第 5 步只能
##   放在 `_make_cells` 之后，重摇的单位因此是「结构 + 类型」一整轮。
##
## 「12 步内不可能同时进两个大宝箱」是**几何必然**，不用额外控制：
##   起点→上角曼哈顿距离 ≥ 3+4 = 7，两个上角之间 ≥ 6，所以
##   「先到任一大宝箱再赶去另一个」最少 13 步 > 12 步。生成时只需保证
##   **两个大宝箱各自 ≤ 12 步可达**（见 _validate）。

const COLS := 7                      # 横向格数
const ROWS := 5                      # 纵向格数
const CELLS := COLS * ROWS           # 35
const MAX_STEPS := 12                # 每层的巧克力块数 = 可探索的新房间数

## ── R356：第三层 = 一条**一字型直道**（不是随机网格）──
## 用户口径：一共 5 格，起点在左边 —— 起点 → 精英战斗（沿用第二层）→ 商店 → 篝火 → Boss。
## 实现方式：**仍然返回 35 个 cell**（`CELLS` 是地图 / 存档 / 战斗内总览共用的契约），
## 把这条道摆在第 `LINE_ROW` 行（正中一行）的第 1~5 列 —— 横向居中、纵向居中；
## 其余 30 格一律标 `void = true`：
##   * `void` 格**不画、不可点、不可达**（渲染与点击都先问 `is_void()`）；
##   * 直道上的 id 与 `idx(col, row)` 完全一致（15~19）→ `cell_of()` / 存档 / 回放不必换口径。
## 这一层**不掷骰子**：不随机生成、不重摇（水晶骰子也不生效 —— 房型是设计定的）。
const LINE_ROW := 2
const LINE_COLS := [1, 2, 3, 4, 5]                 # 起点在最左
const LINE_TYPES := ["start", "elite", "shop", "rest", "boss"]

## ⚠️ 门的存储口径：`cell["doors"]` 是**邻居房间的 id 列表**（不是方向索引）。
## 生成时邻接表就是按 id 建的，直接沿用最不容易出错；
## 需要「哪条边」时用 `dir_between(a_id, b_id)` 从两格坐标反算（只有画门用到）。

const START_COL := 3
const START_ROW := 4                                        # 最下一行
const START_POS := Vector2i(START_COL, START_ROW)
## R243：左上角固定大宝箱（原先是左上 + 右上两个）。
const BIGCHEST_POS := [Vector2i(0, 0)]
## R243：右上角固定商店 —— 每一层都保证有一间商店可去（原先是 1~2 间纯随机商店）。
const SHOP_POS := [Vector2i(6, 0)]

const TYPE_LABELS := {
	"start": "起点", "battle": "战斗", "elite": "精英", "rest": "休息",
	"event": "事件", "chest": "宝箱", "bigchest": "大宝箱", "shop": "商店",
	"unknown": "未知", "boss": "首领",
}
## 格子正中间的短标记（没有对应图标素材时用）。
const TYPE_MARKS := {
	"start": "起", "battle": "战", "elite": "英", "rest": "息",
	"event": "事", "chest": "箱", "bigchest": "大", "shop": "商",
	"unknown": "?", "boss": "王",
}

const P_UNKNOWN := 0.34              # 「?」房占比（其余格直接写明类型）
## R369：篝火**保底 2 间**（用户口径复述，原本就是这个值；实测 8000 张图 100% 达成，
## 由 test_engine 的 R369 段钉住）。
const REST_MIN := 2                  # 每张地图的休息点数量区间
const REST_MAX := 4
## R181：商店节点。数量区间与休息点相当（「概率和篝火相当」）—— 独立先定（像 rest 一样
## 不从权重里抽），约束同样是「不与起点 / 宝箱 / 休息点 / 另一个商店相邻」。
## R369（用户口径）：「除了右上角的商店，商店保底有 2 个」—— 随机商店由 0~1 间改成
## **恒 2 间**，于是每层至少 1（固定角）+ 2（保底）= 3 间，再叠「?」房自己摇出来的那些。
## ⚠️ 上限同样写 2：保底只是**下限**，不该顺手把随机区间的上半段也拉长（会临场再造
##    一倍商店）。权重表一个字没动 —— 保底靠「独立先定」实现，不靠调概率。
const SHOP_MIN := 2
const SHOP_MAX := 2
## 普通格（明房）的类型权重。R192：事件明房权重降到与其他齐平（2），战斗仍是明房最大宗。
## ⚠️ R243：明格**没有 chest / shop** ——
##   * 普通宝箱：只在「?」房里出（见 `WEIGHTS_UNKNOWN`）；
##   * 商店：由「右上角固定 1 间 + `shop_set` 随机 0~1 间」保证，不再靠权重刷 ——
##     否则 35 格 × 权重会刷出 5 间以上，右上那间就没有意义了。
## 要放宽就把对应键加回来。
const WEIGHTS := {"battle": 7, "event": 2, "elite": 2}
## 「?」房的实际类型权重。R192：战斗中签概率砍半（50%→25%），省下的比例按
## 事件:精英:宝箱:商店 = 4:1:1:1 原比例分给其他类型（战斗仍是明房最大宗）。
## R304（用户口径「进一步降低「?」出精英的几率」）：elite 3 → **2**
## （? 房里精英占比 10.7% → 7.4%，约降三成）。
## R371（用户口径「把事件出商店的权重降低到 2，常规出商店的概率也降低大约 30%」）：
## shop 3 → **2**。「?」房就是玩家眼里的「事件房」，这是**除保底（固定角 + shop_set）
## 之外唯一的商店来源**，所以两句话落在同一处：
##   * 权重 3 → 2 是「降到 2」；
##   * 「?」房总数 26 → 25（7+12+2+3+2），商店占比 3/26 = 11.5% → 2/25 = 8.0%，
##     正好降 **30.4%** ≈ 用户要的「大约 30%」。
## 其余四项权重一个字没动 → 其它房间类型之间的相对比例不变。
const WEIGHTS_UNKNOWN := {"battle": 7, "event": 12, "elite": 2, "chest": 3, "shop": 2}
## R380（难度 10「精英出现增多」）：10 档起「?」房**不再刷商店**（shop 键被裁掉 →
## 每层商店固定 2 间 + 右上角 1 间），精英出现概率统一 ×1.3。裁剪后的表见 `_unknown_table()`
## —— **别再直接读 `WEIGHTS_UNKNOWN`**（那会绕过难度 10 的口径）。

## R304（用户口径）：**精英越远离起点越容易遇到** —— 距离系数线性 0.8（起点旁）→ 1.5（最远）。
## 距离用曼哈顿步数（与战斗里的距离口径一致）。
## ⚠️ 系数只在候选格上按**全图平均**归一化之后才乘进权重（见 `generate()` 的 `far_norm`），
##    所以它只是把精英**重新分布**，**总期望不变**。
const ELITE_FAR_MIN := 0.8
const ELITE_FAR_MAX := 1.5

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


static func elite_far_factor(col: int, row: int) -> float:
	## R304：这一格的「精英距离系数」—— 起点旁 0.8、最远 1.5（线性）。
	var d := absi(col - START_COL) + absi(row - START_ROW)
	var dmax := maxi(START_COL, COLS - 1 - START_COL) \
			+ maxi(START_ROW, ROWS - 1 - START_ROW)
	if dmax <= 0:
		return 1.0
	return ELITE_FAR_MIN + (ELITE_FAR_MAX - ELITE_FAR_MIN) * float(d) / float(dmax)


static func elite_weight_scaled(base: int, col: int, row: int, norm: float) -> float:
	## 归一化之后的精英权重（`norm` = 候选格的平均系数）。测试与 `_weighted_far()` 共用。
	return float(base) * elite_far_factor(col, row) / maxf(0.01, norm)


static func is_void(cell) -> bool:
	## R356：这一格是不是「直道之外、不存在的地面」（第三层专用标记）。
	## 渲染（格子底 / 图标 / 迷雾 / 占位）与点击命中都要先过这一关 ——
	## 漏一处的表现是「空白处凭空多出一块可以点的迷雾格」。
	if not (cell is Dictionary):
		return false
	return bool((cell as Dictionary).get("void", false))


static func line_cells(layer := GameLayers.LAYER_THREE) -> Array:
	## R356：第三层的直道（5 格，一字排开，起点在最左）。
	## 返回**完整 35 格**：`LINE_COLS` 上那 5 格是真的房间，其余全 `void`。
	## 不消耗任何随机数 —— 这一层的房型与顺序都是设计定的。
	var cells: Array = []
	for i in CELLS:
		cells.append({
			"id": i, "col": col_of(i), "row": row_of(i),
			"type": "", "hidden": false, "revealed": true, "doors": [],
			"layer": layer, "event_kind": "",
			"void": true,
		})
	for k in LINE_COLS.size():
		var c: Dictionary = cells[idx(int(LINE_COLS[k]), LINE_ROW)]
		c["void"] = false
		c["type"] = str(LINE_TYPES[k])
	# 门：相邻两格互连（双向），于是直道是可以原路返回的一条链。
	for k in range(1, LINE_COLS.size()):
		var a := idx(int(LINE_COLS[k - 1]), LINE_ROW)
		var b := idx(int(LINE_COLS[k]), LINE_ROW)
		(cells[a]["doors"] as Array).append(b)
		(cells[b]["doors"] as Array).append(a)
	return cells


static func is_fixed_shop(i: int) -> bool:
	## R243：右上角那间**固定商店**（每层都有，不参与随机摆位）。
	for p in SHOP_POS:
		if idx(p.x, p.y) == i:
			return true
	return false


# ------------------------------------------------------------ 生成

static func generate(rng: RandomNumberGenerator,
		layer := GameLayers.LAYER_DEFAULT,
		dice_rng: RandomNumberGenerator = null,
		used_bank: Dictionary = {}) -> Array:
	## 生成一整张 5×7 地图（返回 35 个 cell 的数组，下标即 id）。
	## 完全确定：同一 rng 状态必然得到同一张图（重试次数也确定）。
	## ⚠️ R142：内容层校验（每个起点邻居都能不回头走到宝箱）**必须等类型摇完**才判 ——
	##    宝箱是一种「类型」，而类型在 `_make_cells` 里才摇。所以一次重摇 =
	##    「重新连边 + 重新定类型」，不是只重摇结构。
	## R312（用户口径）：`dice_rng != null`（持有「水晶骰子」6040）→ 生成完之后调用
	##    `reroll_as_unknown()`：**本来不是「?」的房间要重摇内容**。变成「?」意味着
	##    「它现在装的是一个「?」房该装的东西」，不能只把门牌遮起来、里面还留着原来那间。
	## ⚠️ 重摇走**独立**随机流（`dice_rng`），不借 `rng` 用 —— 这样「要不要重摇」本身
	##    **一个随机数都不多花**在 `rng` 上，主链位置与「没拿这件道具」时完全相同。
	## ⚠️ 唯一例外：重摇换掉了房型（可能把唯一可达的宝箱摇没）→ `exits_reach_chest()`
	##    判不过 → 像正常生成一样**重摇结构**（这一步会动 `rng`）。它同样是确定性的
	##    （同输入必然同样重试），回放不受影响，只是「有 / 无道具」的主链位置可能错开。
	## ⚠️ 可达性校验放在重摇**之后**：门没动，但房型（含宝箱）变了，得按新内容判。
	# R356：第三层固定是一字型直道（`line_cells`）—— 不生成、不重摇、不掷骰子。
	# ⚠️ 水晶骰子（6040）在这一层不生效：它会把「本来不是 ? 的房间」重摇成 ?，
	#    而这条道的 5 个房型是设计定的（精英 / 商店 / 篝火 / Boss 缺一不可）。
	if layer == GameLayers.LAYER_THREE:
		last_attempts = 1
		return line_cells(layer)
	# R374：`used_bank` = **本局**已出过的事件子类型（`RunState.event_kinds_used`）。
	# 传空表（默认）= 老行为：只在「这一张图」内不重复。
	# ⚠️ 重试循环里每轮都从 `used_bank` **重新拷一份**：失败的那几次尝试不许污染账本，
	#    否则「同一局重试三次」会把三次的临时事件都记成已出过，池子白白被吃空。
	for attempt in MAX_ATTEMPTS:
		var used := used_bank.duplicate()
		var adj := _build_adjacency(rng)
		if adj.is_empty():
			continue
		var cells := _make_cells(adj, rng, layer, used)
		if dice_rng != null:
			reroll_as_unknown(cells, dice_rng, layer, used)
		if not exits_reach_chest(cells):
			continue
		used_bank.clear()
		used_bank.merge(used)
		last_attempts = attempt + 1
		return cells
	push_error("RogueMap：%d 次尝试仍未生成满足约束的 5×7 地图" % MAX_ATTEMPTS)
	return []


static func is_fixed_open(cell: Dictionary) -> bool:
	## R311：这格是不是「水晶骰子**管不到**的固定房间」—— 用户口径明确只有四类：
	## **起点 / 大宝箱 / 右上角的商店 / 篝火（休息处）**。
	## 判据**按 cell 内容**（不是按坐标猜）：随机商店也带 `type == "shop"`，但它是随机刷的，
	## 不在豁免名单里 —— 所以「固定商店」只能靠坐标认（`is_fixed_shop`）。
	if cell.is_empty():
		return false
	var i := int(cell.get("id", -1))
	if i < 0:
		return false
	if i == idx(START_COL, START_ROW):
		return true
	if is_bigchest(i) or is_fixed_shop(i):
		return true
	return str(cell.get("type", "")) == "rest"


static func _unknown_table() -> Dictionary:
	## 当前难度下「?」房该用的权重表。
	## R380：难度 10 起去掉 `shop` —— 商店只剩「右上角固定 1 间 + `shop_set` 恒定 2 间」，
	## 不再由「?」房额外贡献（用户口径「每层商店数量调整为固定 2 个，不算右上角」）。
	## ⚠️ 生成期（`_make_cells`）与水晶骰子的重摇（`_unknown_weights`）都必须走这里，
	##    否则两条路会给出不同的商店 / 精英分布。
	if not RunState.unknown_shop_allowed():
		var w: Dictionary = WEIGHTS_UNKNOWN.duplicate()
		w.erase("shop")
		return w
	return WEIGHTS_UNKNOWN


static func _unknown_weights(cell: Dictionary, layer: int, start_nbs: Dictionary) -> Dictionary:
	## R312：这一格「按「?」房的权重」该用哪张表 —— 与 `_make_cells` 里的分支**同一口径**。
	##   * 起点后第一格（第一层）：只可能是战斗 / 事件（R192 的约束，重摇也要守）；
	##   * 起点后第一格（其它层）：`WEIGHTS_UNKNOWN` 但去掉精英；
	##   * 其余：完整 `WEIGHTS_UNKNOWN`。
	var i := int(cell.get("id", -1))
	if start_nbs.has(i):
		if layer == GameLayers.LAYER_DEFAULT:
			return {"battle": 7, "event": 2}
		var nb_w: Dictionary = _unknown_table().duplicate()
		nb_w.erase("elite")
		return nb_w
	return _unknown_table()


static func reroll_as_unknown(cells: Array, rng: RandomNumberGenerator, layer: int,
		used: Dictionary = {}) -> int:
	## R312（用户口径）：**本来不是「?」的房间，一变成「?」就重摇内容** —— 返回重摇格数。
	##
	## 口径：
	##   * 已经**是**「?」的格子**不动**：它们本来就是按「?」权重摇出来的，重摇只会白折腾；
	##   * **固定房间**（起点 / 大宝箱 / 右上角商店 / 篝火）不动 —— 见 `is_fixed_open()`；
	##   * 其余格子：按「?」权重重定 `type`，并把 `hidden` / `revealed` 一起翻成「未揭晓」；
	##   * 事件子类型（`event_kind`）与「宝箱里是不是道具」跟着重摇，且**不与图上已有事件重名**；
	##   * 精英仍按距离系数分布（`_weighted_far`，与生成期同一套）。
	##
	## ⚠️ 幂等：重摇过的格子已经 `hidden`，再调一次不会重摇（所以「拿到当刻」与「换层」
	##    两条路可以安全地都调）。
	## ⚠️ 随机流由调用方给（`RunState.dice_map_rng()`）—— 本函数不碰全局 `run_rng`。
	if cells.is_empty():
		return 0
	var start_i := idx(START_COL, START_ROW)
	var start_nbs := {}
	if start_i >= 0 and start_i < cells.size():
		for nb in (cells[start_i].get("doors", []) as Array):
			start_nbs[int(nb)] = true
	# ① 先算「参与重摇的格子」的平均距离系数（与生成期同一口径，总期望不变）
	var far_sum := 0.0
	var far_n := 0
	for cell: Dictionary in cells:
		var i := int(cell.get("id", -1))
		if i < 0 or is_fixed_open(cell) or bool(cell.get("hidden", false)):
			continue
		if start_nbs.has(i) and layer == GameLayers.LAYER_DEFAULT:
			continue
		far_sum += elite_far_factor(col_of(i), row_of(i))
		far_n += 1
	var far_norm: float = (far_sum / float(far_n)) if far_n > 0 else 1.0
	# ② 事件子类型：从**本局账本**（`used`）出发，再把「仍然留在图上」的事件登记进去
	# （含没被重摇的 ? 房）。R374：`used` 就是全局账本本身（就地写回），
	# 所以重摇出来的新事件同样受「一局只出一次」约束。
	var used_events: Dictionary = used
	for cell2: Dictionary in cells:
		var ek := str(cell2.get("event_kind", ""))
		if str(cell2.get("type", "")) == "event" and ek != "":
			used_events[ek] = true
	var n := 0
	for cell3: Dictionary in cells:
		var i3 := int(cell3.get("id", -1))
		if i3 < 0 or is_fixed_open(cell3) or bool(cell3.get("hidden", false)):
			continue
		var w := _unknown_weights(cell3, layer, start_nbs)
		var t := ""
		if start_nbs.has(i3) and layer == GameLayers.LAYER_DEFAULT:
			t = _weighted(w, rng)
		else:
			t = _weighted_far(w, rng, col_of(i3), row_of(i3), far_norm)
		cell3["type"] = t
		cell3["hidden"] = true
		cell3["revealed"] = false
		cell3["event_kind"] = ""
		if t == "event":
			var ek3 := GameLayers.roll_event_kind(layer, rng, used_events)
			if ek3 == "":
				cell3["type"] = "battle"   # R374：本局事件池用尽 → 这格是一场普通战斗
			else:
				cell3["event_kind"] = ek3
		n += 1
	return n


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	## ⚠️ 只能用这个，**不要用 `Array.shuffle()`** —— 后者走全局随机源，
	## 同一种子重跑也会得到不同的地图。Fisher-Yates 手工版走传入的 rng。
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
	# R243：固定格（左上大宝箱 + 右上商店）都必须在 12 步巧克力内可达 ——
	# 右上角改成商店之后，它和宝箱一样是「每层必去」的目标格，
	# 走不到就等于这一层没商店（实测有些图会是 13 步，必须靠重摇挡掉）。
	for p in (BIGCHEST_POS + SHOP_POS):
		if int(dist.get(idx(p.x, p.y), 9999)) > MAX_STEPS:
			return []
	return adj


static func exits_reach_chest(cells: Array) -> bool:
	## R142：**起点的每一个邻居都必须能「不往回走」走到一个宝箱。**
	##
	## 为什么要有这一条：地图上走过的房间可以零消耗返回（「原路返回」什么都不发生），
	## 但每层只有 MAX_STEPS 块巧克力。如果起点的某个邻居属于一条
	## 「只能经过起点才连得回主路」的死胡同，玩家第一步走进去就注定要白花步数折返。
	## 用户口径：无论第一步走哪一格，都应该能一路向前走到宝箱。
	##
	## 形式化：「不往回走」= 不重复经过任何房间 = 存在一条**简单路径**；
	## 于是它等价于「**把起点从图里摘掉**之后，该邻居仍能到达某个宝箱房」。
	## 宝箱房 = chest / bigchest（「?」房按它生成时定好的真实类型算）。
	if cells.size() != CELLS:
		return false
	var start_i := idx(START_COL, START_ROW)
	var nbs: Array = (cells[start_i] as Dictionary).get("doors", [])
	if nbs.is_empty():
		return false
	for n: int in nbs:
		if not _reaches_chest_without(cells, int(n), start_i):
			return false
	return true


static func _reaches_chest_without(cells: Array, src: int, banned: int) -> bool:
	## 从 src 出发能否走到宝箱房（**绝不经过 banned**）。src 自己就是宝箱也算命中。
	var seen := {src: true, banned: true}
	var queue: Array = [src]
	while not queue.is_empty():
		var u: int = queue.pop_front()
		if is_chest_cell(cells[u]):
			return true
		for v in (cells[u] as Dictionary)["doors"]:
			if not seen.has(int(v)):
				seen[int(v)] = true
				queue.append(int(v))
	return false


static func is_chest_cell(cell: Dictionary) -> bool:
	## 宝箱房 = 普通宝箱 / 大宝箱（「?」房按生成时定好的真实类型算）。
	var t := str(cell.get("type", ""))
	return t == "chest" or t == "bigchest"


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


static func _make_cells(adj: Array, rng: RandomNumberGenerator, layer: int,
		used_events: Dictionary = {}) -> Array:
	## 把邻接表定型成 35 个 cell 字典。
	var start_i := idx(START_COL, START_ROW)

	# --- 休息点位置：全局先定（起点与两个大宝箱不参与）
	var rest_set := {}
	var cands: Array = []
	for i in CELLS:
		if i == start_i or is_bigchest(i) or is_fixed_shop(i):
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

	# --- 商店点位置（R181）：与休息点同口径独立先定 —— 概率和篝火相当。
	# 约束：不与起点 / 宝箱 / 休息点 / 另一个商店相邻（避免三连强功能房扎堆）。
	var shop_set := {}
	var shop_cands: Array = []
	for i in CELLS:
		if i == start_i or is_bigchest(i) or is_fixed_shop(i) or rest_set.has(i):
			continue
		shop_cands.append(i)
	_shuffle(shop_cands, rng)
	var want_shop: int = rng.randi_range(SHOP_MIN, SHOP_MAX)
	for i: int in shop_cands:
		if shop_set.size() >= want_shop:
			break
		var sok := true
		for nb: int in adj[i]:
			if nb == start_i or rest_set.has(nb) or shop_set.has(nb) or is_fixed_shop(nb):
				sok = false
				break
		if sok:
			shop_set[i] = true
	# R369 保底：上面的严格约束（不与宝箱 / 休息点 / 彼此相邻）在休息点扎堆时可能把候选
	# 吃光 → 一间都摆不下。这里**再补一遍**，放宽到「只避开起点 / 固定商店 / 彼此」：
	#   * 用同一份已打乱的 `shop_cands`，**不额外摇随机数** → 同种子的其它随机结果不变；
	#   * `shop_cands` 本来就剔掉了起点 / 大宝箱 / 固定商店 / 休息点，所以不会压到它们身上。
	# 严格轮次已经摆够时这段**一次都不进**，所以对现有地图零影响。
	if shop_set.size() < want_shop:
		for i2: int in shop_cands:
			if shop_set.size() >= want_shop:
				break
			if shop_set.has(i2):
				continue
			var sok2 := true
			for nb2: int in adj[i2]:
				if nb2 == start_i or shop_set.has(nb2) or is_fixed_shop(nb2):
					sok2 = false
					break
			if sok2:
				shop_set[i2] = true

	# --- 逐格定类型
	var cells: Array = []
	var start_nbs := {}          # R192：起点后第一格（起点的每一个邻居）类型约束用
	for nb in adj[start_i]:
		start_nbs[int(nb)] = true
	# R304：**精英越远越多** —— 先算「真正参与权重抽取」的候选格平均距离系数。
	# 起点 / 大宝箱 / 固定商店 / 休息 / 随机商店都是直接定类型的，不参与；
	# 第一层起点后第一格固定「战斗或事件」，也不参与。
	# 精英权重除以这个平均值再乘距离系数 → 分布变了，**总期望不变**。
	var far_sum := 0.0
	var far_n := 0
	for fi in CELLS:
		if fi == start_i or is_bigchest(fi) or is_fixed_shop(fi) \
				or rest_set.has(fi) or shop_set.has(fi):
			continue
		if start_nbs.has(fi) and layer == GameLayers.LAYER_DEFAULT:
			continue
		far_sum += elite_far_factor(col_of(fi), row_of(fi))
		far_n += 1
	var far_norm: float = (far_sum / float(far_n)) if far_n > 0 else 1.0
	for i in CELLS:
		var type := "battle"
		var hidden := false
		if i == start_i:
			type = "start"
		elif is_bigchest(i):
			type = "bigchest"
		elif is_fixed_shop(i):
			type = "shop"          # R243：右上角固定商店（每层都有）
		elif rest_set.has(i):
			type = "rest"
		elif shop_set.has(i):
			type = "shop"
		else:
			# 「?」房的实际类型在生成时就定（约束才对隐藏房生效），
			# 只是**先不告诉玩家**，走进才揭晓。
			if start_nbs.has(i):
				# R192：起点后第一格约束 —— 所有层都不是精英/篝火（篝火已被 rest_set 排除）；
				# 第一层更进一步：只可能是事件或一般战斗（不是?/商店/精英/篝火）。
				if layer == GameLayers.LAYER_DEFAULT:
					hidden = false
					type = _weighted({"battle": 7, "event": 2}, rng)
				else:
					hidden = rng.randf() < P_UNKNOWN
					var nb_w: Dictionary = (_unknown_table() if hidden else WEIGHTS).duplicate()
					nb_w.erase("elite")
					type = _weighted(nb_w, rng)
			else:
				hidden = rng.randf() < P_UNKNOWN
				type = _weighted_far(_unknown_table() if hidden else WEIGHTS, rng,
						col_of(i), row_of(i), far_norm)
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
			# R374（用户口径）：**一个事件在一局里只被抽出一次** —— `used_events` 是整局账本
			# （`RunState.event_kinds_used`，跨层共用），抽空了不重开。
			# 用尽时 `roll_event_kind` 返回空串 → **这一格降级成一般战斗**。
			# 「?」房对玩家本来就是未知的，走进去打一场，看不出「少了一个事件」。
			# ⚠️ 事件格数量（实测均值 7.3 / 峰值 13）本来就可能大于单层事件池（9~10 种），
			#    所以「用尽」是正常路径，不是异常 —— 别当成错误去 push_error。
			# R372：小宝箱统一「免费开 + 只给卡牌」，不再有「箱子里装道具」的旗标
			# （原来那一半道具的概率连随机数一起吃掉了）。
			var ek := GameLayers.roll_event_kind(layer, rng, used_events)
			if ek == "":
				cell["type"] = "battle"
			else:
				cell["event_kind"] = ek
		cells.append(cell)
	return cells


static func _weighted_far(w: Dictionary, rng: RandomNumberGenerator, col: int, row: int,
		norm: float) -> String:
	## R304：与 `_weighted()` **同一套抽法**（只消耗一次 `randi_range`，随机链条不额外错位），
	## 只是把 **elite** 那一项的权重乘上 `elite_far_factor() / norm`。
	## 所有权重整体 ×100 只是为了容纳小数系数，彼此比例不变。
	## R380（难度 10「精英出现增多」）：精英权重乘 `RunState.elite_weight_mul()`，并且把
	## **多出来的那部分按比例从其他类型里扣掉**（总权重不变）—— 于是涨的是**出现概率**
	## （恰好 ×1.3），而不是「权重 ×1.3、占比只涨两成」。明房 / 「?」房共用这一个口。
	## ⚠️ 低难度 `mul = 1.0` → `drop = 0` → `f = 1`，这条分支是**恒等**的：
	##    同一个种子出图与改动前逐格一致（R380 回归里钉住这一点）。
	var ww := {}
	var total := 0
	var base_w := int(w.get("elite", 0))
	var mul := RunState.elite_weight_mul()
	var others := 0
	for k in w:
		if str(k) == "elite":
			continue
		others += int(w[k]) * 100
	var f := 1.0
	if base_w > 0:
		var e := 100.0 * elite_weight_scaled(base_w, col, row, norm)
		var e_new := e * mul
		var drop := e_new - e
		if others > 0 and drop > 0.0:
			f = maxf(0.0, (float(others) - drop) / float(others))
		ww["elite"] = maxi(1, roundi(e_new))
	for k in w:
		if str(k) == "elite":
			continue
		ww[k] = maxi(1, roundi(float(int(w[k]) * 100) * f))
		total += int(ww[k])
	total += int(ww.get("elite", 0))
	if total <= 0:
		return "battle"
	var roll := rng.randi_range(1, total)
	for k in ww:
		roll -= int(ww[k])
		if roll <= 0:
			return str(k)
	return "battle"


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
	## 起点格 = **type == "start"** 的那一格。
	## R356：第三层是直道，起点不在 (3,4)；7×5 网格里起点也永远只有一格，
	## 所以按类型找与按坐标找完全等价，而且不必再假设「size 一定是 35、位置一定在 (3,4)」。
	for c: Dictionary in cells:
		if str(c.get("type", "")) == "start":
			return c
	return {}


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


static func path_through(cells: Array, from_id: int, to_id: int,
		allowed: Dictionary) -> Array:
	## R322（用户口径）：从 `from_id` 走到 `to_id` 的**逐格路线**（不含 from，末位 = to）。
	## 中途只允许踩在 `allowed`（= **已经走过**的房间）里；**终点不受限**。
	## 走不通返回空数组 —— 调用方一律用「空 = 去不了」判。
	##
	## 为什么需要它：走过的房间可以自由穿行（`RunState.advance()` 对已走过的房间
	## 零消耗、什么都不会发生），所以「能去的地方」不只是当前房的相邻格，而是
	## **走过的连通区 + 它们的所有相邻格**。地图点击按这条口径放行。
	## 纯函数（只读 cells + allowed）→ 回归可以直接钉，不用造局状态。
	var out: Array = []
	if from_id < 0 or to_id < 0 or from_id >= cells.size() or to_id >= cells.size():
		return out
	if from_id == to_id:
		return out
	var parent := {from_id: from_id}
	var q: Array = [from_id]
	var head := 0
	var hit := -1
	while head < q.size() and hit < 0:
		var cur: int = int(q[head])
		head += 1
		for nb in neighbor_ids(cells[cur]):
			var b := int(nb)
			if b < 0 or b >= cells.size() or parent.has(b):
				continue
			# 中途只能踩「走过的」房间；终点那一步不限（它就是玩家想去的下一间）
			if b != to_id and not allowed.has(b):
				continue
			parent[b] = cur
			if b == to_id:
				hit = b
				break
			q.append(b)
	if hit < 0:
		return out
	var cur2 := hit
	while cur2 != from_id:
		out.append(cur2)
		cur2 = int(parent[cur2])
	out.reverse()
	return out


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
