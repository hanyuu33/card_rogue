extends SceneTree
## R595d 只读探针：逐张调 `CardFace.art_for()` 校验卡图真能加载。
## 用法：Godot --headless --path . --script res://tools/probe_all_art.gd
## 「文件存在」不等于「resource 能加载」—— 坏图 / 未导入 / 尺寸错都在这一步暴露。

const CardFaceScript = preload("res://scripts/card_face.gd")


func _init() -> void:
	var repo := CardRepo.load_json()
	var all: Array = repo.all_cards()
	var miss: Array = []
	var ok := 0
	for c: CardData in all:
		var tex: Texture2D = CardFaceScript.art_for(c.id)
		if tex == null:
			miss.append(c.id)
			continue
		var sz: Vector2 = tex.get_size()
		if sz.x < 400.0 or sz.y < 360.0:
			print("SMALL ", c.id, " ", sz)
		ok += 1
	print("ART_TOTAL n=", all.size(), " ok=", ok, " missing=", miss.size())
	if not miss.is_empty():
		print("ART_MISSING ", miss)
	# 沉睡图 / 阶段图这类可选件单列（缺了会回退，不算错）
	print("ART_NULL_OK ", ok == all.size())
	quit()
