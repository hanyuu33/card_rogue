extends SceneTree
## R871 探针：**真实走一遍 run 开局 → 进战斗场景**，确认战斗种子是从战斗链来的。
## 单元测试（test_rng_split）钉的是「关系」，这里钉的是「接缝真的接上了」：
## `battle_scene._load_entry_level → load_level` 的 run 分支必须调 `next_battle_seed()`，
## 而且引擎拿到的那颗种子必须与它一致。
##
## ⚠️ `_ready` 不是 add_child 当帧就跑完的（本场景里要建一堆子节点 / 读盘），
##    所以这里不在 `_init` 里断言，而是等几帧再查 —— 否则量到的是「还没开局」的 0。

var _frames := 0
var _node: Node = null
var _before_state := 0


func _init() -> void:
	var seed_i := 424242
	RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.DRUID, seed_i)
	print("[R871] 开局后 battle_seq =", RunState.battle_seq)

	RunState.pending_level = GameLevels.builtin_levels()[0]
	_before_state = RunState.run_rng.state
	var packed: PackedScene = load("res://scenes/battle.tscn")
	if packed == null:
		print("[R871] FAIL：battle.tscn 读不到")
		quit(1)
		return
	_node = packed.instantiate()
	root.add_child(_node)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var seq_after: int = RunState.battle_seq
	var seed_after: int = RunState.battle_seed
	print("[R871] 进战斗后 battle_seq =", seq_after, " battle_seed =", seed_after)
	var ok := true
	if seq_after != 1:
		print("[R871] FAIL：run 分支应推进到 seq 1（实际 %d）" % seq_after)
		ok = false
	var eng = _node.get("engine")
	if eng == null:
		print("[R871] FAIL：引擎没建起来")
		ok = false
	else:
		var eseed: int = eng.rng.seed
		print("[R871] engine.rng.seed =", eseed)
		if eseed != seed_after:
			print("[R871] FAIL：引擎种子（%d）应等于战斗链种子（%d）" % [eseed, seed_after])
			ok = false
	# 开打本身不该再抽非战斗链
	print("[R871] run_rng.state 变化 =", RunState.run_rng.state - _before_state)
	print("[R871] ", "OK" if ok else "FAIL")
	quit(0 if ok else 1)
	return true
