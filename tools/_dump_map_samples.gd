extends SceneTree
## R858：导出几张成图的 doors / type，供 Python 画示意图（验收用，不进游戏）。
## 输出：tools/_map_samples.json

func _init() -> void:
	var out: Array = []
	for k in 8:
		var rng := RandomNumberGenerator.new()
		rng.seed = 857100 + k * 37
		var cells: Array = RogueMap.generate(rng, GameLayers.LAYER_DEFAULT)
		if cells.is_empty():
			continue
		var g: Array = []
		for c: Dictionary in cells:
			g.append({
				"id": int(c["id"]), "col": int(c["col"]), "row": int(c["row"]),
				"type": str(c["type"]), "hidden": bool(c.get("hidden", false)),
				"doors": (c["doors"] as Array).duplicate(),
				"shop_mark": bool(c.get("shop_mark", false)),
			})
		out.append({"seed": 857100 + k * 37, "cells": g, "attempts": RogueMap.last_attempts})
	var f := FileAccess.open("res://tools/_map_samples.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"maps": out}, "  "))
	f.close()
	print("导出 %d 张 → tools/_map_samples.json" % out.size())
	quit()
