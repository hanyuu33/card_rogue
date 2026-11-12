extends SceneTree

const UiTheme = preload("res://scripts/ui_theme.gd")
const TextWrap = preload("res://scripts/text_wrap.gd")
const RelicRepo = preload("res://scripts/relic_repo.gd")
## R631 只读探针：道具悬停提示的折行结果（复现「幻影斗篷看不到力量 -1」）。
## 用法：Godot --headless --path . --script res://tools/probe_r631_tipwrap.gd


func _initialize() -> void:
	var f := UiTheme.font()
	var txt := "「幻影斗篷」（角色道具·战斗）：你每使用两张牌，随机一个敌方单位力量 -1（持续到你的下个回合开始）。"
	print("[tip] 原文长度 ", txt.length())
	var lines := TextWrap.wrap_plain(f, txt, 456.0, 13)
	print("[tip] 折行数 ", lines.size())
	for i in lines.size():
		print("  L%d [%s] 宽=%.1f" % [i, lines[i],
				f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x])
	# 逐字回拼，看有没有丢字
	var joined := ""
	for l in lines:
		joined += l
	print("[tip] 丢字? ", joined != txt, "  回拼长度 ", joined.length())
	if joined != txt:
		for i in mini(joined.length(), txt.length()):
			if joined[i] != txt[i]:
				print("  首个差异 @", i, " 原=", txt.substr(maxi(0, i - 6), 16),
						" 折=", joined.substr(maxi(0, i - 6), 16))
				break
	# 二、真实 desc（relics.json 6023）
	var repo := RelicRepo.load_json()
	var rel := repo.get_relic(6023)
	if rel != null:
		var live := "「%s」（%s）%s" % [rel.relic_name, rel.tag_line(), rel.desc]
		var l2 := TextWrap.wrap_plain(f, live, 456.0, 13)
		print("[live] 行数 ", l2.size(), " 文案=", live)
		for i in l2.size():
			print("  M%d [%s]" % [i, l2[i]])
	# 三、6013 永生符（--relictip 演示同款文本）
	var r13 := repo.get_relic(6013)
	if r13 != null:
		var d3 := "「%s」（%s）%s\n当前复活概率 100%%。" % [r13.relic_name, r13.tag_line(), r13.desc]
		var l3 := TextWrap.wrap_plain(f, d3, 456.0, 13)
		print("[6013] 行数 ", l3.size())
		for i in l3.size():
			print("  N%d w=%.1f [%s]" % [i,
					f.get_string_size(l3[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, l3[i]])
	quit()
