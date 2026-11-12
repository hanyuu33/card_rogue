extends SceneTree
## R631 只读探针：卡面效果文 / 道具说明在**各种真实框尺寸**下的排版结果。
##
## 判据全部走 `CardFace.text_zone_layout()` —— 与实机绘制同一个函数，
## 所以「探针说放得下」=「实机上画得出来」。
##
## 用法：Godot --headless --path . --script res://tools/probe_r631_textfit.gd
##
## 口径说明：
##   * 「截断」= 画了一部分、剩下的补「…」（玩家读不到全文）。
##   * 「一行都放不下」= 这块尺寸放不下一行效果文（不画，属正常，不报超框）。
##   * 战场 58×70 / 手牌 216×260 走 `name_only=true`，本来不画效果文，不进统计。

const CardRepo = preload("res://scripts/card_repo.gd")
const CardFace = preload("res://scripts/card_face.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const RelicRepo = preload("res://scripts/relic_repo.gd")


func _initialize() -> void:
	var font := UiTheme.font()
	var bold := UiTheme.font_bold()
	var repo := CardRepo.load_json()
	# 真实出现过的「会画效果文」的卡面尺寸
	var rects := {
		"图鉴 101x117": Rect2(0, 0, 101, 117),
		"卡组 336x410": Rect2(0, 0, 336, 410),
		"详情 431x520": Rect2(0, 0, 431, 520),
	}
	for key in rects:
		var r: Rect2 = rects[key]
		var pad: float = UiTheme.CARD_PAD * (r.size.y / CardFace.CARD_H_DESIGN)
		var cuts: Array = []
		var zero := 0
		for c in repo.all_cards():
			var L: Dictionary = CardFace.text_zone_layout(c, r, font, bold, pad)
			if not bool(L.get("ok", false)):
				continue
			var n: int = int(L.get("eff_n", 0))
			var tot: int = (L.get("eff_lines", []) as Array).size()
			if n == 0 and tot > 0:
				zero += 1
			elif n > 0 and n < tot:
				cuts.append("%d %s | 画 %d/%d 行 · %dpx · 原文 %d 字" % [
						c.id, c.card_name, n, tot, int(L["eff_sz"]),
						str(L["eff_text"]).length()])
		print("=== %s：截断 %d 张 ／ 一行都放不下 %d 张（正常）===" % [key, cuts.size(), zero])
		for h in cuts:
			print("    ", h)

	# ── 道具：悬停提示面板（RELIC_TIP_W 480 / pad 12 / 13px 起）──
	var rrepo := RelicRepo.load_json()
	var inner := 480.0 - 24.0
	var max_lines_in_window: int = int(floor((720.0 - 16.0 - 24.0) / 18.0))
	var tip_bad: Array = []
	for rel in rrepo.all_relics():
		var txt := "「%s」（%s）%s" % [rel.relic_name, rel.tag_line(), rel.desc]
		var lines := CardFace.wrap_text(font, txt, inner, 13)
		var over := 0
		for ln in lines:
			if font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > inner:
				over += 1
		if lines.size() > max_lines_in_window or over > 0:
			tip_bad.append("%s | %d 行 · 超宽行 %d" % [rel.relic_name, lines.size(), over])
	print("[道具提示] 13px 行数上限 %d；%d 件需要缩字号/截断" % [max_lines_in_window, tip_bad.size()])
	for h in tip_bad:
		print("    ", h)
	quit()
