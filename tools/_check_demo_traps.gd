extends SceneTree
## R841c 验收：润滑油 7019（+ 锤子 7018）在**试玩档**里是否真的发得出来。
## R834 的教训：进了 `demo_scope` 基线表 ≠ 试玩发得出来 —— 池子会被闸门裁掉，
## 所以要按「真实发放池」再核一遍（all_traps / random_traps / shop_traps 三个口）。
##
## 用法：Godot_v4.3-stable_win64_console.exe --headless --path . \
##         --script res://tools/_check_demo_traps.gd

func _initialize() -> void:
	GameBuild.set_test_demo(1)
	print("is_demo=", GameBuild.is_demo(), " is_release=", GameBuild.is_release())

	var all_ids: Array = []
	for t in TrapRepo.shared().all_traps():
		all_ids.append(t.id)
	var rnd_ids: Array = []
	for t in TrapRepo.shared().random_traps():
		rnd_ids.append(t.id)
	var shop_ids: Array = []
	for t in TrapRepo.shared().shop_traps():
		shop_ids.append(t.id)

	print("all_traps   n=%d  %s" % [all_ids.size(), str(all_ids)])
	print("random      n=%d  %s" % [rnd_ids.size(), str(rnd_ids)])
	print("shop        n=%d  %s" % [shop_ids.size(), str(shop_ids)])
	print("2017 garlic all=%s random=%s shop=%s" % [
			str(all_ids.has(7017)), str(rnd_ids.has(7017)), str(shop_ids.has(7017))])
	print("2018 hammer all=%s random=%s shop=%s" % [
			str(all_ids.has(7018)), str(rnd_ids.has(7018)), str(shop_ids.has(7018))])
	print("2019 oil    all=%s random=%s shop=%s" % [
			str(all_ids.has(7019)), str(rnd_ids.has(7019)), str(shop_ids.has(7019))])
	print("allows_trap 7018=%s 7019=%s 7017=%s" % [
			str(DemoScope.allows_trap(7018)), str(DemoScope.allows_trap(7019)),
			str(DemoScope.allows_trap(7017))])
	print("baseline traps=%d" % DemoScope.baseline_count("traps"))

	# 真机路径：试玩档开一局，一层商店 / 宝箱实际给的池子必须落在允许集内
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	RunState.reset()
	RunState.start_run(RogueMap.generate(rng))
	var pool: Array = []
	for t in TrapRepo.shared().shop_traps():
		pool.append(t.id)
	print("demo run started, traps=%s" % str(RunState.traps))
	GameBuild.set_test_demo(-1)
	print("== RESET demo flag -> is_demo=%s ==" % str(GameBuild.is_demo()))
	quit()
