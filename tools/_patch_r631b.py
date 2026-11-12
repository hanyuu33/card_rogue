# -*- coding: utf-8 -*-
"""R631 补丁：卡面文字区排版抽成唯一口 + 判据统一 + 不裁字。

三个问题：
  ① `fit_text_lines` 按「行数 × 行高 ≤ 可用高」判，绘制又按「末行墨迹底」重算行数
     → fit 说 4 行放得下、绘制只画 3 行，末行被补「…」（用户：描述超过格子）。
  ② 缩字号下限写死 7，且只降 5 档（`sz - 5`）→ 长效果文（激光巨炮）直接截断。
  ③ 每行 `draw_string(..., width=maxw, ...)` 会**裁掉**超出部分（贴边的半个词消失）。

改法：抽 `text_zone_layout()` 作为「画到哪 / 多大字 / 每行是什么」的唯一口，
绘制与体检探针共用；`fit_text_lines` 增加 `last_line_descent` 模式；绘制 width 传 -1。

card_face.gd = LF。
"""
import io

P = "scripts/card_face.gd"

NEW_ZONE = '''static func text_zone_layout(card: CardData, rect: Rect2, font: Font, font_bold: Font,
		pad: float) -> Dictionary:
	## 卡面文字区（卡名 → 种类 → 效果文）的**唯一排版口**（R631）。
	## 绘制 `_draw_text_zone` 与体检探针 `tools/probe_r631_textfit.gd` 共用这一份 ——
	## 两边各算一套的亏已经吃过：`fit_text_lines` 按 `行数 × 行高 ≤ 可用高` 判（多算半行），
	## 绘制又按「末行墨迹底」重算一遍能画几行，于是 fit 说 4 行放得下、绘制只肯画 3 行，
	## 第 4 行被补成「…」（用户口径「激光巨炮的描述超过了格子」）。
	##
	## 返回字段：`ok` / `top` / `bottom` / `maxw` / `name_sz` / `ninfo` / `base_name` /
	## `meta_sz` / `base_meta` / `has_meta` / `eff_text` / `eff_sz` / `eff_lines` /
	## `line_h` / `eff_base0` / `eff_n` / `eff_truncated`。
	var out := {"ok": false, "eff_truncated": false, "eff_n": 0, "eff_lines": []}
	var top: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_TOP + pad
	var bottom: float = rect.position.y + rect.size.y * UiTheme.CARD_NAMEPLATE_BOTTOM - pad
	bottom = minf(bottom, text_zone_bottom(rect))
	if bottom - top < 6.0:
		return out
	var kt: float = minf(scale_of(rect), UiTheme.CARD_TEXT_SCALE_CAP)
	var sz: int = maxi(7, roundi(UiTheme.CARD_FS_TEXT * kt))
	var maxw: float = rect.size.x * (UiTheme.CARD_NAMEPLATE_X1 - UiTheme.CARD_NAMEPLATE_X0) - pad * 2.0
	var row_h: float = maxf(font.get_height(sz), font_bold.get_height(sz))
	var desc: float = float(font.get_descent(sz))
	var ninfo := name_layout(card.card_name, rect, font_bold, bottom - top)
	var nsz: int = int(ninfo["sz"])
	var base_name: float = minf(top + float(nsz) * 0.88, bottom - float(nsz) * 0.22)
	var base_meta: float = base_name + row_h                 # 种类行基线
	var has_meta: bool = base_meta + desc <= bottom
	var eff_base0: float = base_meta + row_h                 # 效果首行基线
	var eff: String = CardText.naturalize(card.effect_text).replace("\\n", " ").strip_edges()
	var eff_sz: int = sz
	var eff_lines: Array = []
	var line_h: float = sz * 1.16
	var eff_n: int = 0
	if eff != "":
		# R569：**超框缩字号**；R631：① 缩到 6px（原来 7px + 只降 5 档，长文案必截断）；
		# ② `last_line_descent = true` → 判据改成「末行墨迹底」，与下面算 eff_n 的公式**同一套**。
		var avail_h: float = bottom - eff_base0
		var fit := fit_text_lines(font, eff, maxw, avail_h, sz, maxi(6, sz - 8), 99, true)
		eff_sz = int(fit["fs"])
		eff_lines = fit["lines"]
		line_h = float(fit["line_h"])
		if avail_h > 0.0:
			var dh: float = float(font.get_descent(eff_sz))
			eff_n = maxi(0, int(floor((avail_h - dh) / line_h)) + 1)
		eff_n = mini(eff_lines.size(), eff_n)
	return {
		"ok": true, "top": top, "bottom": bottom, "maxw": maxw,
		"name_sz": nsz, "ninfo": ninfo, "base_name": base_name,
		"meta_sz": sz, "base_meta": base_meta, "has_meta": has_meta,
		"eff_text": eff, "eff_sz": eff_sz, "eff_lines": eff_lines,
		"line_h": line_h, "eff_base0": eff_base0, "eff_n": eff_n,
		"eff_truncated": eff_n < eff_lines.size(),
	}


static func _draw_text_zone(canvas: CanvasItem, card: CardData, rect: Rect2, kt: float,
		k: float, pad: float, sep_y: float, hp: int, font: Font, font_bold: Font,
		on_board: bool, is_tapped := false, name_only := false) -> void:
	## 文字区（下半）：**卡名 → 种类 · 字段 → 效果文字**，按这个优先级往下排，排不下的整块省略。
	##
	## ⚠️ 「种类」与「字段」**合并成一行**（`盟友 · 迅捷`）—— 分成两行的话，
	##    58×70 / 98×119 这类尺寸上光是这两行就把文字区吃光，效果文字永远轮不到。
	## ⚠️ 效果文字**只在排得下完整一行时**才画 —— 小卡上排「半行字 + 省略号」比不排
	##    更难看，而且玩家根本读不到信息。
	##
	## ⚠️ R164 版式重写（用户口径「文字和卡面的布局对应不上，白底上描边的字难以辨认」）：
	##   ① **所有行共用一个基线基准**：卡名基线 = `top + ascent`，下面每行依次 +`row_h`。
	##      旧版卡名经 `_draw_center`（内部 **+0.36 字号**）下移，而「种类」直接 `draw_string`
	##      不下移 —— 两条基线只差 `row_h - 0.36×字号`，大卡上卡名与种类**必然叠字**
	##      （奖励三选一 216×260 实测：字糊成一片），效果首行也一起挤上来。
	##   ② **先算「画到哪一行」，再画字**：文字块整块落在姓名牌内框里，上不盖分隔金条、
	##      下不吃底部数值徽章 —— 文字与卡面因此对得上。
	##   ③ 文字**一律不描边**，也**不铺底衬**（R208）：可读性靠 card_paper 姓名牌那块
	##      羊皮纸；贴一块程序画的长方形反而像贴纸（用户口径）。
	# name_only（战斗内卡面口径）：只画居中卡名，不画种类·字段与效果文 ——
	# 效果详情由悬停/点选的描述面板提供（战斗左栏信息 / 选卡界面底部描述条）。
	if name_only:
		_draw_name_zone(canvas, card, rect, kt, k, pad, font_bold, true)   # 战斗内：贴金条上移，避开底部徽章
		return
	# R631：排版全部交给 `text_zone_layout()` —— 这里只负责「照着画」，
	# 不再自己算第二套字号 / 行数（两套判据就是「描述超过格子」的根因）。
	var L := text_zone_layout(card, rect, font, font_bold, pad)
	if not bool(L["ok"]):
		return
	var maxw: float = float(L["maxw"])
	var cx: float = rect.position.x + rect.size.x * (UiTheme.CARD_NAMEPLATE_X0 + UiTheme.CARD_NAMEPLATE_X1) / 2.0
	var sz: int = int(L["meta_sz"])
	var kind_col: Color = UiTheme.kind_color(card.kind)
	var meta_a: String = card.kind
	# R592：**字段改走右上角标志**（`_draw_affix_badges`），这一行只剩卡种。
	# 字段名不再出现在文字里 —— 用户口径「所有贴在卡上的 buff 都不再用纯文字」。
	# `card.affix_line()` / `field_affix_line()` 保留：它们是数据层口径
	# （悬停浮层 / 战场徽标 / 测试仍在用），只是卡面不再画。
	var affix_txt: String = ""
	var meta_b: String = (" · " + affix_txt) if affix_txt != "" else ""
	var nsz: int = int(L["name_sz"])
	var ninfo: Dictionary = L["ninfo"]
	var base_name: float = float(L["base_name"])
	var base_meta: float = float(L["base_meta"])
	# ── 画字（**不描边**）───────────────────────────────────────────────
	# R203：卡名横幅（R165 的 banner 渐变条）已去掉 —— 用户口径「卡名后面垫着的那条
	# 绿色长方形直接去掉，卡名直接放在上面就好」；卡名直接画在羊皮卷/木板底衬上。
	# R281：卡名恒单行（宽度自适应 → 超宽横向滚动），不再折行；超宽时也不省略。
	if bool(ninfo["need_scroll"]):
		_draw_name_marquee(canvas, font_bold, nsz, card.card_name,
			rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad,
			base_name, float(ninfo["maxw"]), UiTheme.INK_900, float(ninfo["text_w"]))
	else:
		_draw_center(canvas, font_bold, nsz, card.card_name,
			Vector2(cx, base_name - nsz * 0.36), UiTheme.INK_900)
	if bool(L["has_meta"]):
		var wa: float = font.get_string_size(meta_a, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var wb: float = font.get_string_size(meta_b, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		# ⚠️⚠️ 这里踩过一个**让整个游戏未响应**的坑，改这一行前务必读完：
		#   起初写的是 `meta_b = meta_b.substr(0, meta_b.length() - 1) + "…"` ——
		#   去掉最后一个字符再补一个 `…`，**长度恒定不变**；而且末位一旦是 `…`，
		#   下一轮会得到**完全相同的字符串**（末位被换成 `…`，再砍一位又补回 `…`）。
		#   于是只要「种类 + 长字段」一开始就超宽，这个循环**永远退不出来**。
		#   它在 `_draw()` 里 → 整帧不返回 → 游戏直接未响应。图鉴会画全部卡
		#   （里面有带字段的），所以必中、必卡死，表现为「一打开就卡住」。
		#   两条保险：① 每次砍 **2** 个字符（长度严格递减）；② 再加一个硬上限兜底
		#   —— 绘制代码里的循环**绝不允许**只依赖「条件终将不成立」来退出。
		var meta_guard := 0
		while meta_b != "" and wa + wb > maxw and meta_b.length() > 2 and meta_guard < 64:
			meta_b = meta_b.substr(0, meta_b.length() - 2) + "…"
			wb = font.get_string_size(meta_b, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			meta_guard += 1
		var mx: float = cx - (wa + wb) / 2.0
		canvas.draw_string(font, Vector2(mx, base_meta), meta_a,
				HORIZONTAL_ALIGNMENT_LEFT, -1, sz, kind_col)
		if meta_b != "":
			canvas.draw_string(font, Vector2(mx + wa, base_meta), meta_b,
					HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UiTheme.STAT_POWER)
	# R631：效果文整行**不传 width** —— `draw_string` 的 width 会把超出部分直接裁掉，
	# 贴边的那半个词（幻影斗篷的「力量 -1」）会凭空消失。宽度由折行保证，这里只管画。
	var eff_lines: Array = L["eff_lines"]
	var eff_n: int = int(L["eff_n"])
	var eff_sz: int = int(L["eff_sz"])
	var line_h: float = float(L["line_h"])
	var eff_base0: float = float(L["eff_base0"])
	for i in eff_n:
		var t: String = str(eff_lines[i])
		if i == eff_n - 1 and eff_lines.size() > eff_n:
			t = _ellipsize(font, t + "…", maxw, eff_sz)
		canvas.draw_string(font, Vector2(rect.position.x + rect.size.x * UiTheme.CARD_NAMEPLATE_X0 + pad,
				eff_base0 + line_h * i), t,
				HORIZONTAL_ALIGNMENT_LEFT, -1, eff_sz, UiTheme.INK_600)


'''

raw = io.open(P, encoding="utf-8", newline="").read()
i = raw.find("static func _draw_text_zone(")
j = raw.find("static func _draw_badges(")
assert i >= 0 and j > i, (i, j)
old = raw[i:j]
assert old.count("static func _draw_text_zone(") == 1
assert "fit_text_lines(font, eff" in old, "源码锁锚点不见了"
raw = raw[:i] + NEW_ZONE + raw[j:]

# ── fit_text_lines：增加 last_line_descent 模式 ──
OLD_FIT = '''static func fit_text_lines(font: Font, text: String, max_w: float, max_h: float,
		fs_max: int, fs_min: int, max_lines: int = 99) -> Dictionary:'''
NEW_FIT = '''static func fit_text_lines(font: Font, text: String, max_w: float, max_h: float,
		fs_max: int, fs_min: int, max_lines: int = 99,
		last_line_descent := false) -> Dictionary:'''
assert raw.count(OLD_FIT) == 1, raw.count(OLD_FIT)
raw = raw.replace(OLD_FIT, NEW_FIT, 1)

OLD_LOOP = '''	var sz: int = maxi(fs_min, fs_max)
	while sz > fs_min:
		var probe := wrap_text(font, text, max_w, sz)
		var lh: float = maxf(font.get_height(sz), float(sz))
		if probe.size() <= max_lines and probe.size() * lh <= max_h:
			return {"fs": sz, "lines": probe, "line_h": lh}
		sz -= 1'''
NEW_LOOP = '''	var sz: int = maxi(fs_min, fs_max)
	while sz > fs_min:
		var probe := wrap_text(font, text, max_w, sz)
		var lh: float = maxf(font.get_height(sz), float(sz))
		# R631：`last_line_descent = true` → 按「末行墨迹底」判（(n-1)×行高 + 下行留白）。
		# 绘制方算「能画几行」用的就是这个式子；两边必须同一套，否则末行会被白砍一刀。
		var need: float = probe.size() * lh
		if last_line_descent and not probe.is_empty():
			need = (probe.size() - 1) * lh + float(font.get_descent(sz))
		if probe.size() <= max_lines and need <= max_h:
			return {"fs": sz, "lines": probe, "line_h": lh}
		sz -= 1'''
assert raw.count(OLD_LOOP) == 1, raw.count(OLD_LOOP)
raw = raw.replace(OLD_LOOP, NEW_LOOP, 1)

io.open(P, "w", encoding="utf-8", newline="").write(raw)
b = io.open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
print("zone", len(old), "->", len(NEW_ZONE))
