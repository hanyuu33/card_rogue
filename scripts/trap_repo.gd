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


func size() -> int:
	return _traps.size()
