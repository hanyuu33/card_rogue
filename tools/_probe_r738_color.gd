extends SceneTree
## R738 探针：新卡色 → 元素族 → 通用施法图。跑法：
##   godot --headless --path . --script res://tools/_probe_r738_color.gd

func _init() -> void:
	var repo := CardRepo.load_json()
	var atk := repo.get_card(8002)
	print("8002 color=[%s] 森林=%s(%s) 暗影=%s 机械=%s"
			% [atk.color, FxArt.family_of(atk, "森林精魄"),
			FxArt.skill_name_for(atk, "森林精魄"),
			FxArt.family_of(atk, "暗影刺客"), FxArt.family_of(atk, "机械之心")])
	var cases := [9007, 1031, 8028, 8082, 9005, 1053, 9210, 9145, 9169, 9217]
	for cid: int in cases:
		var c := repo.get_card(cid)
		print("%d %s color=[%s] → %s / %s"
				% [cid, c.card_name, c.color, FxArt.family_of(c),
				FxArt.art_of_family(FxArt.family_of(c))])
	var bad: Array[String] = []
	for c: CardData in repo.all_cards():
		if str(c.color) != "" and not FxArt.FAMILIES.has(str(c.color)):
			bad.append("%d=%s" % [c.id, c.color])
	print("非法色值 %d 个：%s" % [bad.size(), ", ".join(bad)])
	quit()
