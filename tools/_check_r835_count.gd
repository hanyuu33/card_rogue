extends SceneTree
## 一次性实测：R835 空故事书 6089 的「页数」在**真实地图 / 真实换层**下算得对不对。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --headless --path . \
##     --script res://tools/_probe_r835_count.gd
##
## 走的全是真实入口：
##   * 事件房 → `RunState.complete_current()`（事件场景十余处的唯一收口）
##   * 首领战 → `pending_node = {"type":"boss"}` + `on_battle_won("boss")`
##              + `complete_current()`（map_scene._start_boss_battle 与 battle_scene 的真实两跳）
##   * 一般战斗 / 精英 → `on_battle_won(type)` + `complete_current()`
##   * 换层 → `RunState.advance_layer(layer)`
## 判据：页数恒等于「累计事件房数 + 累计首领数」。
## 多跑几个种子 —— 每层的节点 id 都是 0..34 重号，跨层撞车要看得出来。

const SEEDS := [20261120, 1, 2, 3, 7, 11, 42, 99, 123, 777, 2026, 8888]


func _initialize() -> void:
	var bad := 0
	for seed_v: int in SEEDS:
		RunState.start_run([], GameLayers.LAYER_DEFAULT, PlayerClass.default_id(), seed_v)
		RunState.gain_relic(6089)
		var ev_all := 0
		var boss_all := 0
		var detail: Array[String] = []
		var ev_ids: Array = []
		for layer: int in [1, 2, 3]:
			if layer > 1:
				RunState.advance_layer(layer)
			var cells: Array = RunState.map_cells
			var hist := {}
			var ev := 0
			var this_ids: Array = []
			for cell: Dictionary in cells:
				var nid := int(cell.get("id", -1))
				RunState.current_node_id = nid
				RunState.pending_node = cell
				var t := str(cell.get("type", ""))
				hist[t] = int(hist.get(t, 0)) + 1
				match t:
					"event":
						ev += 1
						this_ids.append(nid)
						RunState.complete_current()
					"battle", "elite":
						RunState.on_battle_won(t)
						RunState.complete_current()
					_:
						RunState.complete_current()
			# 本层 Boss（不在地图格子上：map_scene 进 Boss 前写 {"type":"boss"}）
			RunState.pending_node = {"type": "boss"}
			RunState.on_battle_won("boss")
			RunState.complete_current()
			ev_all += ev
			boss_all += 1
			ev_ids.append(this_ids)
			detail.append("L%d ev=%d hist=%s" % [layer, ev, str(hist)])
		var want := ev_all + boss_all
		var got := RunState.story_book_pages
		var flag := "PASS" if got == want else "FAIL"
		if got != want:
			bad += 1
		print("[seed %-8d] %s 理论=%d 实际=%d | %s | ev_ids=%s"
				% [seed_v, flag, want, got, "; ".join(detail), str(ev_ids)])
	print("[汇总] %d 个种子，%d 个不符" % [SEEDS.size(), bad])
	quit()
