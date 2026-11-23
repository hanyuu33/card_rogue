extends SceneTree
## R813b 体检：水晶骰子 6040「把非固定房间变成 ?」的边界核对。
##
## 三问（店长口径）：
##   ① 非「?」格有没有被改成「?」        → 预期：有（这是骰子的效果）
##   ② 固定格（起点 / 大宝箱 / 标记商店 / 篝火）有没有被改成「?」 → 预期：没有
##   ③ 顺带查：第一层起点后第一格（R192 明确写死 hidden=false）会不会被重摇成「?」
##
## 判定「显示成 ?」的唯一口径与 UI 一致：`hidden && !revealed`（见 rogue_map.gd:951）。
##
## 用法：
##   Godot_v4.3-stable_win64_console.exe --headless --path . \
##     --script res://tools/_check_r813b_dice.gd

const SEEDS := 24


func _initialize() -> void:
	_run()
	quit()


func _shown_q(cell: Dictionary) -> bool:
	return bool(cell.get("hidden", false)) and not bool(cell.get("revealed", false))


func _run() -> void:
	var total := 0
	var fixed_n := 0
	var fixed_bad := 0
	var fixed_bad_samples: Array = []
	var unfixed_n := 0
	var unfixed_q := 0
	var nb_n := 0
	var nb_q := 0
	var nb_bad_type := 0
	var nb_types := {}
	var first_bad := []

	for layer in [1, 2]:
		for s in SEEDS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900001 + s
			var dice := RandomNumberGenerator.new()
			dice.seed = 770001 + s
			var cells: Array = RogueMap.generate(rng, layer, dice, {})
			if cells.is_empty():
				print("[!] layer=%d seed=%d 生成失败" % [layer, s])
				continue
			var start_i := RogueMap.idx(RogueMap.START_COL, RogueMap.START_ROW)
			var nbs := {}
			if start_i >= 0 and start_i < cells.size():
				for nb in (cells[start_i].get("doors", []) as Array):
					nbs[int(nb)] = true
			for cell: Dictionary in cells:
				total += 1
				var i := int(cell.get("id", -1))
				var fixed := RogueMap.is_fixed_open(cell)
				if fixed:
					fixed_n += 1
					if _shown_q(cell):
						fixed_bad += 1
						if fixed_bad_samples.size() < 6:
							fixed_bad_samples.append("L%d#%d type=%s hidden=%s rev=%s" % [
									layer, i, str(cell.get("type", "")),
									str(cell.get("hidden", false)), str(cell.get("revealed", true))])
				else:
					unfixed_n += 1
					if _shown_q(cell):
						unfixed_q += 1
				if nbs.has(i) and layer == 1:
					nb_n += 1
					if _shown_q(cell):
						nb_q += 1
					var t := str(cell.get("type", ""))
					nb_types[t] = int(nb_types.get(t, 0)) + 1
					if not (t == "battle" or t == "event"):
						nb_bad_type += 1
						if first_bad.size() < 6:
							first_bad.append("L1 seed=%d #%d type=%s" % [s, i, t])

	# 第三层：一条直道，骰子必须完全不生效
	var r3_rng := RandomNumberGenerator.new()
	r3_rng.seed = 555
	var d3 := RandomNumberGenerator.new()
	d3.seed = 556
	var c3: Array = RogueMap.generate(r3_rng, 3, d3, {})
	var l3_types: Array = []
	for c: Dictionary in c3:
		l3_types.append(str(c.get("type", "")))
	var l3_q := 0
	for c: Dictionary in c3:
		if _shown_q(c):
			l3_q += 1

	print("=== 骰子地图体检（第一/二层各 %d 张）===" % SEEDS)
	print("总格数 %d" % total)
	print("① 非固定格 %d 个 → 显示为 ? 的 %d 个（%.1f%%）"
			% [unfixed_n, unfixed_q, 100.0 * float(unfixed_q) / maxi(1, unfixed_n)])
	print("② 固定格 %d 个 → 显示为 ? 的 %d 个  ← 必须为 0" % [fixed_n, fixed_bad])
	for b in fixed_bad_samples:
		print("     固定格异常: %s" % b)
	print("③ 第一层起点邻居 %d 个 → 显示为 ? 的 %d 个；type 分布 %s；非 战斗/事件 的 %d 个"
			% [nb_n, nb_q, str(nb_types), nb_bad_type])
	for b in first_bad:
		print("     起点邻居类型异常: %s" % b)
	print("④ 第三层直道 %d 格 / 类型 %s / 显示为 ? 的 %d 个  ← 必须 0"
			% [c3.size(), str(l3_types), l3_q])
	print("[DONE]")
