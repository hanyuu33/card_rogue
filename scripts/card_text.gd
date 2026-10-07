class_name CardText
extends RefCounted
## 卡面文案的「显示层」工具（R106）。
##
## 背景：`cards.json` 的 `effect_text` 里混了两类**不属于自然语言**的书写习惯：
##   ① 括号补注：`（不分敌我）`、`（每 1 点剩余费用回复 1 点生命，不超过生命上限）`……
##      —— 它们是规则说明，不是句子主干，堆在正文里把一句话切成好几截。
##   ② 极简 Markdown：`**接通**`、`**移动经过**`、`**超负荷**`……
##      —— 数据里早已写了几十处，但老版是**直接把星号画出来**的，玩家看到的是
##      `**移动经过**`，非常「程序化」。
##
## 本模块把这两件事统一收在**显示层**处理（**不改 cards.json**）：
##   * `naturalize()`：隐藏括号补注 + 去掉 Markdown 标记 → 纯文本（给 Label / 单行提示用）
##   * `parse()`：解析成「富文本片段」数组，每段带 `bold / italic / code`
##   * `to_bbcode()`：转成 BBCode（给 RichTextLabel 用）
##   * `wrap_segments()` / `draw_wrapped()`：按宽度折行 + 逐段取字体绘制（给自绘面板用）
##
## 之所以**不动数据**：测试里有大量 `effect_text.contains("移动进入某个场地")` 这类
## 断言（补注本身就写在括号里），改数据会连带改坏断言；而玩家看到的只是卡面，
## 收在显示层既拿到自然语言，又让 `cards.json` 保持「带完整补注的权威版本」。

## 是否在显示层隐藏「（…）」括号补注。设 false 可一键恢复原样显示。
const HIDE_PARENS := true

## 代码片段（`反引号`）的着色 —— 与正文的蓝色刻意分开，一眼能认出来。
const COL_CODE := Color("a8621f")

## 词句归一：把卡面里**对不上自然语言**的写法改正过来。**按顺序**做替换，
## 所以长词要排在短词前面（「返回手卡」必须早于「手卡」）。
## 这些修正刻意只在**显示层**做 —— `cards.json` 是权威数据、测试里有
## `effect_text.contains("返回手卡")` 这类的断言，动数据会连带改坏断言。
const PHRASE_FIXES := [
	["返回手卡", "收回手牌"],
	["抽牌库", "抽牌堆"],
	["手卡", "手牌"],
	["费用变为0", "费用变为 0"],
	["登场时攻击力", "登场时力量"],
]


static func _is_cjk(c: String) -> bool:
	if c == "":
		return false
	var cp := c.unicode_at(0)
	return (cp >= 0x4E00 and cp <= 0x9FFF) or (cp >= 0x3400 and cp <= 0x4DBF) \
			or (cp >= 0xF900 and cp <= 0xFAFF)


static func _is_digit(c: String) -> bool:
	return c.length() == 1 and c >= "0" and c <= "9"


static func _space_units(s: String) -> String:
	## 数值与汉字之间补一个半角空格：`获得+3生命` → `获得 +3 生命`、`费用变为0` → `费用变为 0`。
	## 项目里绝大多数文案本来就是 `造成 4 点伤害` 这种带空格的写法，这里把漏掉的补齐，
	## 免得同一张卡面上「力量+1」和「力量 +1」两种排法混着出现。
	var out := ""
	var n := s.length()
	for i in n:
		var ch := s[i]
		var prev := s[i - 1] if i > 0 else ""
		var nxt := s[i + 1] if i + 1 < n else ""
		# 符号前补空格：汉字 + 「+/-」 + 数字
		if (ch == "+" or ch == "-") and _is_cjk(prev) and _is_digit(nxt):
			out += " "
		# 数字与汉字之间补空格（`3生命` → `3 生命`；`造成4点` → `造成 4 点`）
		if _is_digit(ch) and prev != "" and not _is_digit(prev) and prev != " " \
				and prev != "+" and prev != "-" and _is_cjk(prev):
			out += " "
		out += ch
		if _is_digit(ch) and _is_cjk(nxt):
			out += " "
	return out


static func naturalize_phrases(s: String) -> String:
	## 词句归一：术语统一 + 数值与汉字之间补空格（**不改数据**，只改显示）。
	var out := s
	for pair in PHRASE_FIXES:
		out = out.replace(pair[0], pair[1])
	return _space_units(out)


static func _seg(text: String, bold: bool, italic: bool, code: bool) -> Dictionary:
	return {"text": text, "bold": bold, "italic": italic, "code": code}


static func strip_parens(s: String) -> String:
	## 去掉成对的括号补注（支持全角（）与半角 ()，可嵌套）。
	## 多余的空格与「空格 + 标点」顺手清掉，免得留下 `伤害 。` 这种断口。
	var out := ""
	var depth_f := 0   # 全角括号深度
	var depth_h := 0   # 半角括号深度
	for i in s.length():
		var ch := s[i]
		if ch == "（":
			depth_f += 1
			continue
		if ch == "）":
			if depth_f > 0:
				depth_f -= 1
			else:
				out += ch
			continue
		if ch == "(":
			depth_h += 1
			continue
		if ch == ")":
			if depth_h > 0:
				depth_h -= 1
			else:
				out += ch
			continue
		if depth_f == 0 and depth_h == 0:
			out += ch
	# 清理：连续空格压成一个；标点前不留空格
	# ⚠️ 只清半角空格，**不碰**「数字 4 点伤害」这类刻意留出的半角空格之间的情况。
	while out.contains("  "):
		out = out.replace("  ", " ")
	for p in ["，", "。", "、", "；", "：", "！", "？", "」", "）"]:
		out = out.replace(" " + p, p)
	return out.strip_edges()


static func parse(md: String, hide_parens := HIDE_PARENS) -> Array:
	## 解析极简 Markdown → 片段数组：[{text, bold, italic, code}, ...]
	## 支持 `**加粗**`、`*斜体*`、`` `代码` ``。标记不成对时按字面保留（不吞字）。
	var s: String = naturalize_phrases(md)
	if hide_parens:
		s = strip_parens(s)
	var segs: Array = []
	var buf := ""
	var bold := false
	var italic := false
	var code := false
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch == "*" and not code:
			if i + 1 < n and s[i + 1] == "*":
				if buf != "":
					segs.append(_seg(buf, bold, italic, code))
					buf = ""
				bold = not bold
				i += 2
				continue
			if buf != "":
				segs.append(_seg(buf, bold, italic, code))
				buf = ""
			italic = not italic
			i += 1
			continue
		if ch == "`":
			if buf != "":
				segs.append(_seg(buf, bold, italic, code))
				buf = ""
			code = not code
			i += 1
			continue
		buf += ch
		i += 1
	if buf != "":
		segs.append(_seg(buf, bold, italic, code))
	if segs.is_empty():
		segs.append(_seg("", false, false, false))
	return segs


static func segments_plain(segs: Array) -> String:
	var out := ""
	for seg in segs:
		out += str(seg.get("text", ""))
	return out


static func naturalize(md: String, hide_parens := HIDE_PARENS) -> String:
	## 纯文本降级：隐藏括号补注 + 去掉 Markdown 标记。给 Label / 单行提示用。
	return segments_plain(parse(md, hide_parens))


static func to_bbcode(md: String, hide_parens := HIDE_PARENS) -> String:
	## 转 BBCode（给 RichTextLabel 用）。BBCode 的 `[` 需转义，避免文案里的方括号被当标签。
	var out := ""
	for seg in parse(md, hide_parens):
		var t: String = str(seg.get("text", "")).replace("[", "[lb]")
		if bool(seg.get("code", false)):
			t = "[code]%s[/code]" % t
		if bool(seg.get("italic", false)):
			t = "[i]%s[/i]" % t
		if bool(seg.get("bold", false)):
			t = "[b]%s[/b]" % t
		out += t
	return out


static func _carry(seg: Dictionary, text: String) -> Dictionary:
	return {"text": text, "bold": seg.get("bold", false),
			"italic": seg.get("italic", false), "code": seg.get("code", false)}


static func wrap_segments(font: Font, font_bold: Font, segs: Array,
		max_w: float, size: int) -> Array:
	## 中文友好的字符级折行，**保留每段的字体/样式**。
	## 返回：若干「行」，每行是片段数组（可直接交给 draw_wrapped 或自己绘制）。
	var fnt_b := font_bold if font_bold != null else font
	var lines: Array = []
	var cur: Array = []
	var cur_w := 0.0
	for seg in segs:
		var f: Font = fnt_b if bool(seg.get("bold", false)) else font
		var parts: PackedStringArray = str(seg.get("text", "")).split("\n")
		for pi in parts.size():
			if pi > 0:
				lines.append(cur)
				cur = []
				cur_w = 0.0
			var run := ""
			for ch in parts[pi]:
				var w: float = f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				if cur_w + w > max_w and cur_w > 0.0:
					if run != "":
						cur.append(_carry(seg, run))
						run = ""
					lines.append(cur)
					cur = []
					cur_w = 0.0
				run += ch
				cur_w += w
			if run != "":
				cur.append(_carry(seg, run))
	if not cur.is_empty() or lines.is_empty():
		lines.append(cur)
	return lines


static func draw_wrapped(canvas: CanvasItem, font: Font, font_bold: Font, segs: Array,
		x: float, y: float, max_w: float, size: int, line_h: float, base_col: Color,
		max_y := -1.0) -> float:
	## 逐行绘制富文本片段；返回**画完后的 y**（下一行基线）。
	## 加粗用**加粗字体 + 略深的同色系**（不换色相，避免花）；行间纵向排布与
	## 调用方的普通文本一致。max_y >= 0 时超过就画「……」并停笔。
	var fnt_b := font_bold if font_bold != null else font
	var bold_col := base_col.darkened(0.28)
	var lines := wrap_segments(font, font_bold, segs, max_w, size)
	var drawn := 0
	for line in lines:
		if max_y >= 0.0 and drawn > 0 and y + size * 0.36 > max_y:
			canvas.draw_string(font, Vector2(x, y), "……",
					HORIZONTAL_ALIGNMENT_LEFT, -1, size, base_col)
			return y
		var cx := x
		for seg in line:
			var f: Font = fnt_b if bool(seg.get("bold", false)) else font
			var col: Color = base_col
			if bool(seg.get("code", false)):
				col = COL_CODE
			elif bool(seg.get("bold", false)):
				col = bold_col
			var t: String = str(seg.get("text", ""))
			canvas.draw_string(f, Vector2(cx, y), t,
					HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			cx += f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		y += line_h
		drawn += 1
	return y
