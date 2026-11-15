class_name TrapRepo
extends RefCounted
## R663：陷阱库（与 RelicRepo 同风格）。真源 = res://traps.json。

var _traps := {}  # id -> TrapData

## R746：同 `RelicRepo.shared()` —— 绘制路径不许反复读盘 + 解析 traps.json。
static var _shared = null          # 无类型注解：写成自身 class_name 会触发解析器自引用错误


static func shared() -> TrapRepo:
	if _shared == null:
		_shared = load_json()
	return _shared


static func load_json(path: String = "res://traps.json") -> TrapRepo:
	var repo := TrapRepo.new()
	if not FileAccess.file_exists(path):
		push_error("traps.json 不存在")
		return repo
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("traps.json 解析失败")
		return repo
	var list: Array = data if data is Array else data.get("traps", [])
	for d: Dictionary in list:
		var t := TrapData.from_dict(d)
		repo._traps[t.id] = t
	return repo


func get_trap(id: int) -> TrapData:
	return _traps.get(id)


func all_traps() -> Array[TrapData]:
	var out: Array[TrapData] = []
	for id: int in _traps.keys():
		out.append(_traps[id])
	out.sort_custom(func(a: TrapData, b: TrapData): return a.id < b.id)
	return out


func random_traps() -> Array[TrapData]:
	## R743：**可随机获得**的工具（战斗 10% 掉落 / 工具箱 6068）。
	## `rest_only` 的那些（烤肉 7007）只能从休息处烤出来 —— 混进随机池，
	## 「篝火专属」就成了「哪儿都能捡」，烤肉的稀缺感连同休息处的选择一起作废。
	## ⚠️ R752：这条口径**只管「拿得到」**，不再代表货架。商店走 `shop_traps()` ——
	##    万能牌 / 快送鸭 / 神秘牌没有售价，能掉落但不能买（用户口径「没有售价的则不计入商店」）。
	## ⚠️ R754：`no_drop` 的（石头 7012）连「拿得到」都不算 —— 它只从事件「奇异雕像」拿。
	var out: Array[TrapData] = []
	for t: TrapData in all_traps():
		if not t.rest_only and not t.no_drop:
			out.append(t)
	return out


func shop_traps() -> Array[TrapData]:
	## R752：**商店货架**的唯一取池口（`shop_scene` 与快送鸭 7010 共用）。
	## 判据收在 `TrapData.in_shop()` 里（`price > 0`），这里只做筛选 —— 别再各写一份。
	var out: Array[TrapData] = []
	for t: TrapData in all_traps():
		if t.in_shop():
			out.append(t)
	return out


func size() -> int:
	return _traps.size()
