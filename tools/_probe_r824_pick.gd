extends SceneTree
## R824 一次性核查：**试玩版**下，第二层起点三选一到底能不能抽到「鸭子闹钟」6085。
##
## 只调真实入口（`GameBuild.set_test_demo` + `RelicRepo.layer2_ids_for` + `RunState._roll_relic_choice`），
## 不自己拼池子 —— 拼了就测不到「demo 分支还残留短路」这类问题。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --headless --path . --script res://tools/_probe_r824_pick.gd


func _initialize() -> void:
	var seed_bak := RunState.run_seed
	var rng_seed_bak := RunState.run_rng.seed
	RunState.current_layer = GameLayers.LAYER_TWO

	for demo in [1, 0]:
		GameBuild.set_test_demo(demo)
		var duck_pool := RelicRepo.load_json().layer2_ids_for(RunState.LAYER2_HOST_DUCK)
		var bun_pool := RelicRepo.load_json().layer2_ids_for(RunState.LAYER2_HOST_BUNBUN)
		var hit := 0
		var duck_hosts := 0
		for s in 40:
			RunState.run_seed = s
			RunState.run_rng.seed = s
			if RunState.layer2_host() == RunState.LAYER2_HOST_DUCK:
				duck_hosts += 1
			RunState.relic_choice = []
			var pick: Array[int] = RunState._roll_relic_choice()
			if pick.has(6085):
				hit += 1
		print("[demo=%d] 鸭绅士池 %s / 卷卷池 %s" % [demo, str(duck_pool), str(bun_pool)])
		print("[demo=%d] 40 个种子里 遇到鸭绅士 %d 次 · 三选一出「鸭子闹钟」%d 次"
				% [demo, duck_hosts, hit])

	GameBuild.set_test_demo(-1)
	RunState.run_seed = seed_bak
	RunState.run_rng.seed = rng_seed_bak
	quit()
