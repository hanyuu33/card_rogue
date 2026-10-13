class_name RunSave
extends RefCounted
## 肉鸽 run 的本地存档 / 续档（"继续游戏"）—— 关掉 app 也能从本地数据接着当前局。
##
## 存档内容 = RunState 的全部**持久字段**（血量 / 卡组 / 地图 / 位置 / 道具 / 种子 / 随机源状态 /
## 待领奖励队列……）。地图格子里没有小数、关卡字典里有 Vector2i（敌人站位），所以用
## **var_to_str / str_to_var** 序列化（int / bool / Vector2i / 嵌套字典数组原样 round-trip），
## 不走 JSON（JSON 存不了 Vector2i，且数字会被统一成 float）。
##
## 随机源：只存 `run_rng.seed + run_rng.state` 两个整数即可**精确续上**随机链条 ——
## 地图/关卡/掉落早已从这条链上摇过，续档后下一次摇点和关掉 app 前完全一致（不影响已生成的局面）。
##
## 存档时机 / 生命周期：
##   * **存**：map_scene 每次稳定停留在地图时（每个节点结算完的检查点）自动存一份；
##   * **清**：① 标题点「开始」开新局（弃旧档）；② RunState.end_run()（通关/失败/放弃）——
##     end_run 里加了 `if not ReplayLog.playing` 保护：**看录像时不清**，免得回放末尾的
##     end_run 把玩家真实的存档删掉；
##   * **读**：标题「继续游戏」→ load_run() → 进地图。
##
## ⚠️ 续档只恢复到**地图层**：战斗中关掉 app，下次从"这场之前"的地图检查点接着来
##   （那场重打）—— 与杀戮尖塔等同类肉鸽一致，避免存半场战斗导致"已走过的战斗房卡死"。

const SAVE_PATH := "user://run_save.sav"
const FORMAT := 1


# ------------------------------------------------------------ 查询

static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# ------------------------------------------------------------ 写入

static func save_run() -> bool:
	## 把当前 run 写入本地存档。非 run 中 / 写盘失败返回 false。
	if not RunState.run_active:
		return false
	var rng: RandomNumberGenerator = RunState.run_rng
	var d := {
		"max_hp": RunState.max_hp,
		"hp": RunState.hp,
		"deck_ids": RunState.deck_ids,
		"map_cells": RunState.map_cells,
		"current_layer": RunState.current_layer,
		"current_node_id": RunState.current_node_id,
		"cleared_ids": RunState.cleared_ids,
		"chocolate": RunState.chocolate,
		"boss_pending": RunState.boss_pending,
		"player_class": RunState.player_class,
		"battle_wins": RunState.battle_wins,
		"elite_wins": RunState.elite_wins,
		"used_levels": RunState.used_levels,
		"boss_pick": RunState.boss_pick,
		"revenge_pending": RunState.revenge_pending,
		"relics": RunState.relics,
		"skipped_relics": RunState.skipped_relics,
		"duck_revive_chance": RunState.duck_revive_chance,
		"run_seed": RunState.run_seed,
		"rng_seed": rng.seed if rng != null else 0,
		"rng_state": rng.state if rng != null else 0,
		"pending_rewards": RunState.pending_rewards,
		"relic_choice": RunState.relic_choice,
		"pending_relic": RunState.pending_relic,
		"pending_relic_drop": RunState.pending_relic_drop,
		"pending_deck_edit": RunState.pending_deck_edit,
		"pending_event": RunState.pending_event,
		"reward_type": RunState.reward_type,
		"reward_context": RunState.reward_context,
		"difficulty": RunState.difficulty,
	}
	var root := {"__runsave__": FORMAT, "d": d}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("RunSave：无法写入存档 " + SAVE_PATH)
		return false
	f.store_string(var_to_str(root))
	f.close()
	return true


# ------------------------------------------------------------ 读取

static func load_run() -> bool:
	## 从本地存档恢复 run（写入 RunState 静态字段）。成功返回 true。
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var root: Variant = str_to_var(txt)
	if not (root is Dictionary) or int((root as Dictionary).get("__runsave__", 0)) != FORMAT:
		push_warning("RunSave：存档格式不兼容或已损坏")
		return false
	var d: Dictionary = (root as Dictionary).get("d", {})
	if not (d is Dictionary):
		return false

	RunState.max_hp = maxi(1, int(d.get("max_hp", 50)))
	RunState.hp = clampi(int(d.get("hp", RunState.max_hp)), 0, RunState.max_hp)
	RunState.run_active = true
	RunState.deck_ids = _int_array(d.get("deck_ids", []))
	RunState.map_cells = d.get("map_cells", []) if d.get("map_cells", []) is Array else []
	RunState.current_layer = int(d.get("current_layer", GameLayers.LAYER_DEFAULT))
	RunState.current_node_id = int(d.get("current_node_id", -1))
	RunState.cleared_ids = _int_array(d.get("cleared_ids", []))
	RunState.chocolate = int(d.get("chocolate", 0))
	RunState.boss_pending = bool(d.get("boss_pending", false))
	RunState.player_class = str(d.get("player_class", PlayerClass.default_id()))
	RunState.battle_wins = int(d.get("battle_wins", 0))
	RunState.elite_wins = int(d.get("elite_wins", 0))
	RunState.used_levels = _str_array(d.get("used_levels", []))
	RunState.boss_pick = d.get("boss_pick", {}) if d.get("boss_pick", {}) is Dictionary else {}
	RunState.revenge_pending = bool(d.get("revenge_pending", false))
	RunState.relics = _int_array(d.get("relics", []))
	RunState.skipped_relics = _int_array(d.get("skipped_relics", []))
	RunState.duck_revive_chance = int(d.get("duck_revive_chance", 100))
	RunState.run_seed = int(d.get("run_seed", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("rng_seed", 0))
	rng.state = int(d.get("rng_state", 0))
	RunState.run_rng = rng
	RunState.pending_rewards = d.get("pending_rewards", []) if d.get("pending_rewards", []) is Array else []
	RunState.relic_choice = _int_array(d.get("relic_choice", []))
	RunState.pending_relic = int(d.get("pending_relic", -1))
	RunState.pending_relic_drop = int(d.get("pending_relic_drop", -1))
	RunState.pending_deck_edit = str(d.get("pending_deck_edit", ""))
	RunState.pending_event = str(d.get("pending_event", ""))
	RunState.reward_type = str(d.get("reward_type", "normal"))
	RunState.reward_context = str(d.get("reward_context", ""))
	RunState.difficulty = clampi(int(d.get("difficulty", 0)), 0, RunState.DIFFICULTY_COUNT - 1)
	# 瞬时转换字段不存档（安全检查点上它们本就为空）：读档后复位，走地图重新触发
	RunState.pending_level = {}
	RunState.pending_node = {}
	RunState.reward_kinds = []
	RunState.battle_log = []
	return true


# ------------------------------------------------------------ 删除

static func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ------------------------------------------------------------ 工具

static func _int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v: Variant in a:
			out.append(int(v))
	return out


static func _str_array(a: Variant) -> Array:
	var out: Array = []
	if a is Array:
		for v: Variant in a:
			out.append(str(v))
	return out
