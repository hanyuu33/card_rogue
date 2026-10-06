class_name RelicRepo
extends RefCounted
## 道具库：从 relics.json 加载全部道具（与 CardRepo 同风格）。

var _relics := {}  # id -> RelicData


static func load_json(path: String = "res://relics.json") -> RelicRepo:
	var repo := RelicRepo.new()
	if not FileAccess.file_exists(path):
		push_error("relics.json 不存在")
		return repo
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("relics.json 解析失败")
		return repo
	var list: Array = data if data is Array else data.get("relics", [])
	for d: Dictionary in list:
		var relic := RelicData.from_dict(d)
		repo._relics[relic.id] = relic
	return repo


func get_relic(id: int) -> RelicData:
	return _relics.get(id)


func all_relics() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for id: int in _relics.keys():
		out.append(_relics[id])
	out.sort_custom(func(a: RelicData, b: RelicData): return a.id < b.id)
	return out


func initial_ids() -> Array[int]:
	## 初始道具池（起点三选一；新道具加进 relics.json 后在此登记）。
	return [6001, 6002, 6003, 6004, 6021]


func reward_ids() -> Array[int]:
	## 奖励道具池（精英 / Boss 掉落、宝箱层开箱等途径；不进起点三选一）。
	return [6005, 6006, 6007, 6008, 6009, 6013, 6020, 6024]


func event_ids() -> Array[int]:
	## 事件道具池（事件节点给予，如鸭鸭低语、一袋米抗几楼、休息处烤肉、鸭梨；
	## 不进初始/奖励池）。
	return [6010, 6011, 6012, 6019]


func layer2_ids() -> Array[int]:
	## 第二层起始道具池（只在第二层的起始节点三选一；
	## 不进第一层初始池 / 奖励池 / 事件池）。
	return [6014, 6015, 6016, 6017, 6018]


func start_ids_for_layer(layer: int) -> Array[int]:
	## 该层「起始节点三选一」的道具池：第一层 = 初始池，第二层 = 二层起始池。
	match layer:
		2:
			return layer2_ids()
	return initial_ids()


func class_ids() -> Array[int]:
	## 角色赠品道具（选定角色时由 RunState.start_run 发放，如森林精魄的「荒野形态」6022）。
	## 这一池**不参与任何随机抽取**：起点三选一 / 奖励掉落 / 事件 / 二层起始都不含它。
	return [6022, 6023, 6025]


func roll_reward(rng: RandomNumberGenerator) -> int:
	## 从奖励池随机抽一个道具 id（奖励界面上架/掉落用）。
	var pool := reward_ids()
	if pool.is_empty():
		return -1
	return pool[rng.randi() % pool.size()]
