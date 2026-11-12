extends SceneTree
## R631 只读探针：核对「文本进 Label / 进绘制」之前到底被改成了什么。
## 用法：Godot --headless --path . --script res://tools/probe_r631_text.gd

const CardRepo = preload("res://scripts/card_repo.gd")
const CardText = preload("res://scripts/card_text.gd")
const RelicRepo = preload("res://scripts/relic_repo.gd")


func _initialize() -> void:
	var repo := CardRepo.load_json()
	for want in [9241, 8037, 9036]:
		var c = null
		for x in repo.all_cards():
			if x.id == want:
				c = x
				break
		if c == null:
			print("[card] %d 未找到" % want)
			continue
		print("=== %d %s ===" % [want, c.card_name])
		print("  原文   : ", _repr(c.effect_text))
		print("  naturalize: ", _repr(CardText.naturalize(c.effect_text)))
		print("  长度 原文 %d → 显示 %d" % [c.effect_text.length(),
				CardText.naturalize(c.effect_text).length()])
	# 道具提示文案（battle_scene 的拼法）
	var rrepo := RelicRepo.load_json()
	for rid in [6023, 6013]:
		var rel = rrepo.get_relic(rid)
		if rel == null:
			continue
		print("=== relic %d %s ===" % [rid, rel.relic_name])
		print("  desc : ", _repr(rel.desc))
		print("  tip  : ", _repr("「%s」（%s）%s" % [rel.relic_name, rel.tag_line(), rel.desc]))
	quit()


func _repr(s: String) -> String:
	## 把不可见字符（换行 / 全角空格）显形，便于比对。
	var out := ""
	for i in s.length():
		var ch := s[i]
		if ch == "\n":
			out += "\\n"
		elif ch == "\r":
			out += "\\r"
		elif ch == "\t":
			out += "\\t"
		elif ch == " ":
			out += "·"
		else:
			out += ch
	return out
