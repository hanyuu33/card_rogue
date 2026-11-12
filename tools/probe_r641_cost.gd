extends SceneTree
## R641 探针：真实加载图鉴场景，逐个费用档位核对命中集合。
## 用法：godot --headless --path . --script res://tools/probe_r641_cost.gd
## 判据（与 gallery_scene.COST_OPTIONS / _cost_match 对齐）：
##   0 = 不限（含 X 费卡）；1..5 = 0..4 费精确；6 = 5 费以上。

var fails := 0


func _initialize() -> void:
	_main.call_deferred()


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✓ ", msg)
	else:
		fails += 1
		printerr("  ✗ ", msg)


func _main() -> void:
	var g = load("res://scenes/gallery.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame

	check(g.cost_opt.item_count == 7, "费用下拉框 7 档（实际 %d）" % g.cost_opt.item_count)
	var labels: Array[String] = []
	for i in g.cost_opt.item_count:
		labels.append(g.cost_opt.get_item_text(i))
	check(labels == ["费用不限", "0 费", "1 费", "2 费", "3 费", "4 费", "5 费+"],
			"档位文案与顺序正确：%s" % [labels])

	# 各档逐项核对：每一档里显示的卡必须真的符合该档口径，且不许有 X 费卡混进来
	var totals: Array[int] = []
	for idx in g.cost_opt.item_count:
		g._on_cost_changed(idx)
		await process_frame
		var shown: Array = g._shown
		totals.append(shown.size())
		var bad: Array[String] = []
		for c in shown:
			var ok := false
			if idx == 0:
				ok = true
			elif c.x_cost:
				ok = false
			elif idx == 6:
				ok = c.cost >= 5
			else:
				ok = c.cost == idx - 1
			if not ok:
				bad.append("#%d %s cost=%d x=%s" % [c.id, c.card_name, c.cost, c.x_cost])
		print("[R641] 第 %d 档「%s」→ %d 张" % [idx, g.cost_opt.get_item_text(idx), shown.size()])
		check(bad.is_empty(), "第 %d 档无越界卡%s" % [idx, "" if bad.is_empty() else "：%s" % [bad.slice(0, 5)]])

	# 0 费档必须真的查得到东西（这就是本轮要修的那个洞）
	check(totals[1] > 0, "「0 费」档能查到卡（%d 张）" % totals[1])
	# 0 费档里点名两张现成卡
	g._on_cost_changed(1)
	await process_frame
	var names: Array[String] = []
	for c in g._shown:
		names.append(c.card_name)
	check(names.has("哈气") or names.has("生命循环"),
			"「0 费」档包含 0 费代表卡（哈气 9024 / 生命循环 9150）：%s" % [names.slice(0, 12)])

	# 各档之和 + X 费卡 = 不限档（证明「没人被漏掉、也没人被重复算」）
	var sum := 0
	for i in range(1, 7):
		sum += totals[i]
	g._on_cost_changed(0)
	await process_frame
	var x_cnt := 0
	for c in g._shown:
		if c.x_cost:
			x_cnt += 1
	check(sum + x_cnt == totals[0],
			"各档之和 + X 费卡(%d) = 不限档(%d)（实际 %d）" % [x_cnt, totals[0], sum + x_cnt])

	# 敌人图鉴同样适用（那条分支共用同一判据）
	g._on_group_toggled(true, "enemy")
	g._on_cost_changed(1)
	await process_frame
	var e_bad := 0
	for c in g._shown:
		if c.cost != 0 or c.x_cost:
			e_bad += 1
	check(e_bad == 0, "敌人图鉴「0 费」档同样只出 0 费（越界 %d 张）" % e_bad)

	print("PROBE_DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
