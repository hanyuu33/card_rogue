class_name TrapRepo
extends RefCounted
## R663：陷阱库（与 RelicRepo 同风格）。真源 = res://traps.json。

var _traps := {}  # id -> TrapData


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
	## R743：**可随机获得**的工具（战斗 10% 掉落 / 商店货架）。
	## `rest_only` 的那些（烤肉 7007）只能从休息处烤出来 —— 混进随机池，
	## 「篝火专属」就成了「哪儿都能捡」，烤肉的稀缺感连同休息处的选择一起作废。
	var out: Array[TrapData] = []
	for t: TrapData in all_traps():
		if not t.rest_only:
			out.append(t)
	return out


func size() -> int:
	return _traps.size()
