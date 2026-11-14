extends SceneTree
## R693 校验：两个上角都是大宝箱 + 商店「开局随机标记一处」+ 存档往返后标记不变。
##
## 用法（headless 即可）：
##   Godot_v4.3-stable_win64_console.exe --headless --path . --script res://tools/_t_r693_mark.gd
## 退出码 0 = 全过，1 = 有失败。
##
## 为什么单独写这一个脚本：`test_engine` 只钉住「生成出来的图长什么样」，
## 而这次改动的另一半风险在**存档**上 —— `shop_mark` 是新加的字段，
## 老档没有它、读档时还得按旧位置补回来。这条链只在真存 / 真读里才走得到。

var _fails := 0


func _initialize() -> void:
	ProfileData.set_test_mode()
	RunSave.set_test_mode()
	RunState.end_run()
	_run()
	print("== R693 结果：%s ==" % ("全部通过" if _fails == 0 else "%d 项失败" % _fails))
	quit(1 if _fails > 0 else 0)


func _ck(ok: bool, msg: String) -> void:
	if ok:
		print("  ✓ ", msg)
	else:
		_fails += 1
		print("  ✗ ", msg)


func _run() -> void:
	_check_generation()
	_check_save_roundtrip()
	_check_legacy_migration()


func _check_generation() -> void:
	print("[1] 生成：两层各 200 张")
	for layer in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261114 + layer
		var corner_ok := true
		var mark_ok := true
		var mark_visible := true
		var mark_reach := true
		var no_corner_mark := true
		var sample_id := -1
		for trial in 200:
			var cells: Array = RogueMap.generate(rng, layer)
			if cells.size() != RogueMap.CELLS:
				corner_ok = false
				break
			# 两个上角必须都是大宝箱
			if str((cells[RogueMap.idx(0, 0)] as Dictionary).get("type", "")) != "bigchest" \
					or str((cells[RogueMap.idx(6, 0)] as Dictionary).get("type", "")) != "bigchest":
				corner_ok = false
			# 恰好一间 shop_mark
			var marks: Array = []
			for c: Dictionary in cells:
				if bool(c.get("shop_mark", false)):
					marks.append(int(c["id"]))
			if marks.size() != 1:
				mark_ok = false
				continue
			var mi := int(marks[0])
			sample_id = mi
			var mc: Dictionary = cells[mi]
			if str(mc.get("type", "")) != "shop" or bool(mc.get("hidden", false)):
				mark_visible = false
			if mi == RogueMap.idx(0, 0) or mi == RogueMap.idx(6, 0) \
					or mi == RogueMap.idx(RogueMap.START_COL, RogueMap.START_ROW):
				no_corner_mark = false
			# 12 步巧克力内走得到（走不到的商店等于没有）
			var steps: Dictionary = RogueMap.steps_from(cells, RogueMap.idx(
					RogueMap.START_COL, RogueMap.START_ROW))
			if int(steps.get(mi, 9999)) > RogueMap.MAX_STEPS:
				mark_reach = false
		var tag := "第一层" if layer == GameLayers.LAYER_DEFAULT else "第二层"
		_ck(corner_ok, "%s：200 张图左上 / 右上都是大宝箱" % tag)
		_ck(mark_ok, "%s：每张图**恰好**标记一间商店" % tag)
		_ck(mark_visible, "%s：标记的那间是可见的 shop（不藏在「?」里）" % tag)
		_ck(no_corner_mark, "%s：标记商店不落在起点 / 两个大宝箱上" % tag)
		_ck(mark_reach, "%s：标记商店都在 %d 步内可达（末张 id=%d）"
				% [tag, RogueMap.MAX_STEPS, sample_id])
	# 第三层是设计死的直道，不能被这一轮改动波及
	var line: Array = RogueMap.generate(RandomNumberGenerator.new(), GameLayers.LAYER_THREE)
	var line_ok := true
	for c2: Dictionary in line:
		if bool(c2.get("shop_mark", false)):
			line_ok = false
	var line_shop := 0
	for c3: Dictionary in line:
		if str(c3.get("type", "")) == "shop":
			line_shop += 1
	_ck(line_ok and line_shop == 1, "第三层直道：没有 shop_mark，商店仍是设计定的那 1 间")


func _check_save_roundtrip() -> void:
	print("[2] 存档往返：开局标记 → 存档 → 读档 → 还是同一格")
	RunState.end_run()
	var srng := RandomNumberGenerator.new()
	srng.seed = 20261114
	var seed_map: Array = RogueMap.generate(srng, GameLayers.LAYER_DEFAULT)
	RunState.start_run(seed_map, GameLayers.LAYER_DEFAULT, "", 20261114)
	var cells: Array = RunState.map_cells
	var mark_before := _find_mark(cells)
	_ck(mark_before >= 0, "开局生成了标记商店（id=%d）" % mark_before)
	var d: Dictionary = RunSave.snapshot()
	var raw: Array = d.get("map_cells", [])
	var persisted := -1
	for c: Variant in raw:
		if c is Dictionary and bool((c as Dictionary).get("shop_mark", false)):
			persisted = int((c as Dictionary).get("id", -1))
	_ck(persisted == mark_before, "快照里带着 shop_mark（id=%d）" % persisted)
	# 模拟「重开进程」：先把内存清干净，再喂回快照
	RunState.end_run()
	RunState.map_cells = []
	var ok: bool = RunSave.apply(d)
	_ck(ok, "读档成功")
	var mark_after := _find_mark(RunState.map_cells)
	_ck(mark_after == mark_before, "读档后标记还在同一格（%d → %d）" % [mark_before, mark_after])
	_ck(mark_after >= 0 and RogueMap.is_fixed_shop(mark_after),
			"读档后 is_fixed_shop() 仍认得出它（不是靠坐标猜的）")
	# 「每层永远在」的含义：道具不能把这间改成宝箱
	var changed: int = RunState.note_reveal_bigchest()
	_ck(changed >= 0 and changed != mark_after,
			"笔记改宝箱不会压到标记商店（改到 %d，标记在 %d）" % [changed, mark_after])
	_ck(mark_after >= 0 and RogueMap.is_fixed_shop(mark_after), "改完之后标记商店原地不动")
	RunState.end_run()


func _check_legacy_migration() -> void:
	print("[3] 老档迁移：R693 之前的存档没有 shop_mark")
	RunState.end_run()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var cells: Array = RogueMap.generate(rng, GameLayers.LAYER_DEFAULT)
	# 把图还原成「老档」的样子：没有任何 shop_mark，右上角那格是商店
	for c: Dictionary in cells:
		c.erase("shop_mark")
		if str(c.get("type", "")) == "shop":
			c["type"] = "battle"
	var corner := RogueMap.idx(6, 0)
	(cells[corner] as Dictionary)["type"] = "shop"
	RunState.map_cells = cells
	var got: int = RunState.ensure_shop_mark()
	_ck(got == corner, "老档补标记：认回右上角 (6,0)（补到 %d）" % got)
	_ck(RogueMap.is_fixed_shop(corner), "补完之后 is_fixed_shop(6,0) 为真")
	# 幂等：再补一次不该动
	var again: int = RunState.ensure_shop_mark()
	_ck(again == -1, "重复调用不重复补（返回 %d）" % again)
	# 老档里连商店都没有 → 不凭空造一间
	RunState.end_run()
	var cells2: Array = RogueMap.generate(RandomNumberGenerator.new(), GameLayers.LAYER_DEFAULT)
	for c2: Dictionary in cells2:
		c2.erase("shop_mark")
		if str(c2.get("type", "")) == "shop":
			c2["type"] = "battle"
	RunState.map_cells = cells2
	var none_id: int = RunState.ensure_shop_mark()
	_ck(none_id == -1, "老档没有商店时不凭空补一间（返回 %d）" % none_id)
	RunState.end_run()


func _find_mark(cells: Array) -> int:
	for c: Variant in cells:
		if c is Dictionary and bool((c as Dictionary).get("shop_mark", false)):
			return int((c as Dictionary).get("id", -1))
	return -1
