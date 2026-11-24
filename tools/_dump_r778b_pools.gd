extends SceneTree

## R778b：打印各层池子数量与新档位分布（一次性核对工具）。

func _init() -> void:
	print("ALL=", GameLevels.builtin_levels().size())
	for layer in [GameLayers.LAYER_DEFAULT, GameLayers.LAYER_TWO, GameLayers.LAYER_THREE]:
		print("--- layer ", layer, " content=", GameLayers.content_layers(layer))
		print("  layer_total=", GameLevels.levels_of_layer(layer).size())
		print("  normal=", GameLevels.normal_pool(layer).size())
		print("  elite=", GameLevels.elite_pool(layer).size())
		var cnt := {}
		for lv in GameLevels.levels_of_layer(layer):
			var t := int(lv["tier"])
			cnt[t] = int(cnt.get(t, 0)) + 1
		print("  tier_counts=", cnt)
	print("third_elite_pool=", GameLevels.third_elite_pool().size())
	for lv in GameLevels.third_elite_pool():
		print("   ", lv["key"])
	var l3 := GameLevels.levels_of_tier(
			[GameLevels.TIER_ELITE_EASY, GameLevels.TIER_ELITE_HARD], GameLayers.LAYER_THREE)
	print("l3_elite_via_content=", l3.size())
	quit()
