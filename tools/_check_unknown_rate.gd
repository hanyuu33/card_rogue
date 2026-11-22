extends SceneTree
## 探针：统计「?」格（hidden）的出现率 —— 单格概率 + 每图平均个数 + 「?」房实际类型分布。

func _initialize() -> void:
	GameSettings.ensure_loaded()
	var seeds_n := 2000
	var tot_cells := 0
	var tot_hidden := 0
	var hist := {}
	var type_in_hidden := {}
	var type_visible := {}
	var min_h := 99
	var max_h := -1
	for s in seeds_n:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100000 + s
		var cells: Array = RogueMap.generate(rng, GameLayers.LAYER_DEFAULT)
		var h := 0
		for c in cells:
			var cell: Dictionary = c
			if cell.get("void", false):
				continue
			tot_cells += 1
			if cell.get("hidden", false):
				h += 1
				tot_hidden += 1
				var t := str(cell.get("type", ""))
				type_in_hidden[t] = int(type_in_hidden.get(t, 0)) + 1
			else:
				var t2 := str(cell.get("type", ""))
				type_visible[t2] = int(type_visible.get(t2, 0)) + 1
		hist[h] = int(hist.get(h, 0)) + 1
		min_h = mini(min_h, h)
		max_h = maxi(max_h, h)
	print("样本 %d 张图，通用格总数 %d" % [seeds_n, tot_cells])
	print("单格成为「?」的概率 = %.2f%%" % (100.0 * float(tot_hidden) / float(tot_cells)))
	print("每图「?」个数：均值 %.2f，范围 %d~%d" % [float(tot_hidden) / float(seeds_n), min_h, max_h])
	var ks := hist.keys()
	ks.sort()
	var line := ""
	for k in ks:
		line += "%d:%d  " % [int(k), int(hist[k])]
	print("分布 → " + line)
	print("--- 「?」房实际内容占比 ---")
	var hk := type_in_hidden.keys()
	hk.sort()
	for k in hk:
		print("  %-8s %6d  %5.1f%%" % [str(k), int(type_in_hidden[k]), 100.0 * float(type_in_hidden[k]) / float(tot_hidden)])
	print("--- 明房类型占比（对照） ---")
	var vk := type_visible.keys()
	vk.sort()
	for k in vk:
		print("  %-8s %6d  %5.1f%%" % [str(k), int(type_visible[k]), 100.0 * float(type_visible[k]) / float(tot_cells - tot_hidden)])
	quit(0)
