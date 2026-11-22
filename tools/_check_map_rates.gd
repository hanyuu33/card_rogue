extends SceneTree
## R852 探针：各类型格子的出现概率（按难度 0 / 10，分层统计）。
## 口径：分母 = 该层「非 void 的通用格」（一层 35 格，第三层直道 5 格另算）。

const SEEDS := 600

func _rate_for(diff: int, layer: int) -> Dictionary:
	RunState.set_difficulty(diff)
	var tot := 0
	var cnt := {}
	var hidden_total := 0
	var shops := 0.0
	var maps := 0
	for s in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 852000 + s * 7919 + layer * 13 + diff * 101
		var cells: Array = RogueMap.generate(rng, layer)
		maps += 1
		var ns := 0
		for c: Dictionary in cells:
			if RogueMap.is_void(c):
				continue
			tot += 1
			var t := str(c.get("type", ""))
			cnt[t] = int(cnt.get(t, 0)) + 1
			if bool(c.get("hidden", false)):
				hidden_total += 1
			if t == "shop":
				ns += 1
		shops += float(ns)
	return {"tot": tot, "cnt": cnt, "hidden": hidden_total,
			"shop_avg": shops / float(maps), "maps": maps}

func _dump(tag: String, r: Dictionary) -> void:
	var tot := int(r["tot"])
	print("===== %s（%d 张图 / %d 格）=====" % [tag, int(r["maps"]), tot])
	var order := ["battle", "event", "elite", "chest", "shop", "rest", "bigchest", "start", "boss"]
	var cnt: Dictionary = r["cnt"]
	var acc := 0
	for k in order:
		if not cnt.has(k):
			continue
		var n := int(cnt[k])
		acc += n
		print("  %-9s %7d  %6.2f%%" % [k, n, 100.0 * float(n) / float(tot)])
	for k in cnt.keys():
		if order.has(k):
			continue
		var n2 := int(cnt[k])
		acc += n2
		print("  %-9s %7d  %6.2f%%" % [str(k), n2, 100.0 * float(n2) / float(tot)])
	print("  「?」格    %7d  %6.2f%%   （每层平均 %.2f 间商店）"
			% [int(r["hidden"]), 100.0 * float(r["hidden"]) / float(tot), float(r["shop_avg"])])
	assert(acc == tot)

func _initialize() -> void:
	GameSettings.ensure_loaded()
	for layer: int in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO]:
		for diff: int in [0, 10]:
			var tag := "第%d层 · 难度 %d" % [layer, diff]
			_dump(tag, _rate_for(diff, layer))
	RunState.set_difficulty(0)
	print("===== 第三层（固定直道，不掷骰）=====")
	var line: Array = RogueMap.generate(RandomNumberGenerator.new(), GameLayers.LAYER_THREE)
	var s := ""
	for c: Dictionary in line:
		s += "%s " % str(c.get("type", ""))
	print("  " + s.strip_edges())
	quit(0)
