class_name BannerFit
extends RefCounted
## 横幅文字的**自适应排版**唯一口（R542）。
##
## 起因（用户口径）：「文字超过了中间文本框的长度。文字应该能自适应大小，换行，防止超出框体」。
## 战场中央那块木牌（`adventure_shared/button_forest`）原本是**固定 25 号字、单行居中**画的，
## 于是横幅文本只要长过十来个字，两头就会同时探出牌子压在棋盘 / 右侧面板上 ——
## R541 的「普罗诺亚之影」开场白（15 字）第一次把它暴露出来。
##
## ## 口径（按优先级）
##   ① **字号优先**：能用 25 号原样塞下就绝不动它 ——「我方回合 · 第 N 回合」这类短句
##      的观感一个字都不变，改动只对**放不下的长句**生效。
##   ② **放不下才折行**：走 `TextWrap.wrap_plain`（R292 唯一口，行首禁则 / 数字成词都照顾到），
##      行数上限 `MAX_LINES`（木牌只有 80 高，四行以上墨迹必糊成一片）。
##   ③ **折得难看宁可缩字号**：两行里末行短到不足最长行的 35%（例：14 字 + 1 字）算「没排好」
##      → 继续降字号；通常降一号就变成单行，比「14/1」好看得多。
##   ④ **兜底绝不溢出**：连 `FS_MIN` 都塞不下 → 按能放下的行数硬截，末行补 `…`。
##
## ⚠️ 度量一律量**整行串**（`font.get_string_size()`，与 `TextWrap` 同口径）；
##    逐字相加会偏小，贴边的最后一颗字会被 `draw_string` 的宽度裁剪吃掉（R244 踩过）。

const FS_MAX := 25          # 字号上限 = 原先写死在 `_draw_banner` 里的那个号
const FS_MIN := 12          # 字号下限（再小就压不住木牌那块深绿底）
const MAX_LINES := 3        # 行数上限
const LINE_K := 1.04        # 行距系数（× 字号）


static func fit(font: Font, text: String, max_w: float, max_h: float) -> Dictionary:
	## 把一段话塞进 `max_w × max_h` 的框，返回
	## `{"size": int, "lines": Array[String], "lh": float}`。
	## `lines` 是**已经定好**要画的行：调用方只管逐行居中，不必再折一次
	## （折行规则只有 `TextWrap` 一个口，这里不另起一套）。
	var body := text.strip_edges()
	if body == "":
		var one: Array[String] = [""]
		return {"size": FS_MAX, "lines": one, "lh": line_h(font, FS_MAX)}
	for s in range(FS_MAX, FS_MIN - 1, -1):
		var lines: Array[String] = TextWrap.wrap_plain(font, body, max_w, s)
		var lh := line_h(font, s)
		if lines.size() > MAX_LINES:
			continue
		if float(lines.size()) * lh > max_h:
			continue
		if not _looks_ok(font, lines, s):
			continue
		return {"size": s, "lines": lines, "lh": lh}
	# ── 兜底：最小字号 + 能放下的行数，末行截断补「…」（绝不溢出框体）──
	var lh2 := line_h(font, FS_MIN)
	var rows := maxi(1, int(floor(max_h / lh2)))
	var cut := body
	var last: Array[String] = []
	var guard := 0
	while guard < 512:
		last = TextWrap.wrap_plain(font, cut, max_w, FS_MIN)
		if last.size() <= rows:
			break
		# 每次砍 2 个字：长度**严格递减**，绘制路径里绝不留「只靠条件终将成立」的循环。
		cut = cut.substr(0, cut.length() - 2)
		guard += 1
	var out: Array[String] = []
	for i in mini(rows, last.size()):
		out.append(last[i])
	if out.is_empty():
		out.append("")
	if cut != body:
		# ⚠️ 「…」**也占宽度**：`TextWrap` 折出来的行只保证 ≤ max_w - SAFETY，
		# 末尾再补一个省略号就可能顶出框外（R542 断言当场抓到：300 的框排出 310 的行）。
		# 所以补完要回量，超了就把末行一个字一个字往下砍 —— 砍空就整行删掉。
		var guard2 := 0
		while guard2 < 128:
			if out.is_empty():
				break
			var cand: String = out[out.size() - 1] + "…"
			if _w(font, cand, FS_MIN) <= max_w:
				out[out.size() - 1] = cand
				break
			out[out.size() - 1] = out[out.size() - 1].substr(0, out[out.size() - 1].length() - 1)
			guard2 += 1
	return {"size": FS_MIN, "lines": out, "lh": lh2}


static func line_h(font: Font, size: int) -> float:
	## 行距取字体**真实行高**（`get_height`），不按字号拍脑袋估 —— 与卡面同一口径（R115）：
	## 雅黑 9px 实测行高 13，按 `sz * 1.12` 估会得到 10，两行墨迹必然叠在一起。
	if font == null:
		return float(size) * LINE_K
	return maxf(float(font.get_height(size)), float(size)) * LINE_K


static func _looks_ok(font: Font, lines: Array[String], size: int) -> bool:
	## 行数 ≥ 2 时末行不能短得离谱：`…我都会记住。` 只占一行 1 个字，
	## 玩家看到的是「没排好」，而不是「框太小」。
	if lines.size() <= 1:
		return true
	var widest := 0.0
	for ln in lines:
		widest = maxf(widest, _w(font, ln, size))
	var last := _w(font, lines[lines.size() - 1], size)
	return last >= widest * 0.35


static func _w(font: Font, s: String, size: int) -> float:
	if font == null or s == "":
		return 0.0
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
