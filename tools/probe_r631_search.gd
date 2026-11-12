extends SceneTree
## R631 探针：真实加载图鉴场景，往搜索框里填词，打印命中卡与命中口径。
## 用法：godot --headless --path . --script res://tools/probe_r631_search.gd -- 聚能炮击 机械

func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	var words: Array = OS.get_cmdline_user_args()
	if words.is_empty():
		words = ["聚能炮击"]
	var g = load("res://scenes/gallery.tscn").instantiate()
	root.add_child(g)
	await process_frame
	await process_frame
	for w in words:
		var q := str(w)
		g.search_edit.text = q
		g._on_search_changed(q)   # 程序赋值不保证发 text_changed → 显式调一次（幂等）
		await process_frame
		var shown: Array = g._shown
		print("[R631] 查询「%s」→ 命中 %d 张，其中卡名不含 %d 张" % [q, shown.size(), g._text_only_hits])
		for c in shown:
			var tag := "卡名"
			if not c.card_name.to_lower().contains(q.to_lower()):
				if c.effect_text.to_lower().contains(q.to_lower()):
					tag = "效果文"
				elif c.affixes.has(q) or c.traits.has(q):
					tag = "特性/字段"
				elif c.kind == q or c.card_class == q:
					tag = "种类/职业"
				else:
					tag = "其他"
			print("    #%d %s [%s] %s" % [c.id, c.card_name, tag, c.effect_text.substr(0, 36)])
	# 清空搜索 → 应恢复全量（证明不会把上一次的结果留在索引里）
	g.search_edit.text = ""
	g._on_search_changed("")
	await process_frame
	print("[R631] 清空后 → %d 张" % g._shown.size())
	print("PROBE_DONE")
	quit()
