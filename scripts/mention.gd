class_name Mention
extends RefCounted
## 「文本里提到另一张卡牌 / 一件道具」的**统一机制**（R168 · 规范 §4.38）。
##
## 契约（写文案的人只需要记住这一条）：
##   文案里把名字用 **「」括起来**（历史写法 `**…**` 也认）→ 只要这个名字命中**名字表**，
##   它就成了「提及」：**自动换色**、**鼠标悬浮看详情**、**命中矩形**由本模块交出。
##   对不上卡库 / 道具库的写法（纯引用、普通强调）一律原样保留 —— 宁可少标，
##   也不要标出一堆点开是空的「假链接」（规范 §4.10 纪律 4）。
##
## 给调用方的三件事：
##   ① 解析：`index()` / `resolve()` / `scan()`
##   ② 着色 + 命中矩形：`text_color()`，以及 `CardText.mark_mentions()` +
##      `CardText.draw_wrapped_hits()`（提及自动换色、交出 `hits` 数组）
##   ③ 画悬浮件：`tip_size()` / `draw_tip()`（卡牌画**真实卡面**、道具画名称+来源+完整说明），
##      以及 `draw_reference_block()`（「这条文案里提到的：…」附带块，
##      把被提及的卡 / 道具的名字 + 摘要一并列出来）
##
## 名字表**全工程只建一次**（卡 200+ / 道具 40+，每帧重建太浪费）；卡牌优先 ——
## 万一某张卡与某件道具同名，以卡面为准（与 R122 的既有口径一致）。

## ⚠️ UiTheme 有意不写 class_name（见 ui_theme.gd 顶部说明）→ 消费方必须 preload。
const UiTheme = preload("res://scripts/ui_theme.gd")

const PAD := 24.0            # 卡面浮窗内边距：必须 ≥ 徽章半径 20.24（规范 §4.10 纪律 3）
const CARD_SCALE := 2.4      # 卡面浮窗缩放（与事件页原口径一致）
const RELIC_W := 352.0       # 道具浮窗宽度
const RELIC_PAD := 14.0
const BLOCK_HEAD := "这条文案里提到的"   # 附带块标题
const BLOCK_MAX_LINES := 3               # 每个被提及项最多列几行摘要
## R206：附带块行距**唯一口** —— `draw_reference_block()` 与 `block_height()` 共用，
## 两边各写一份数字就是「预算 90px、实画 110px」的经典错位来源。
const BLOCK_HEAD_H := 24.0     # 标题行 + 与第一项的间隔
const BLOCK_ITEM_H := 18.0     # 每项「· 种类「名字」」行占位
const BLOCK_LINE_H := 15.0     # 摘要每行
const BLOCK_GAP := 6.0         # 项与项之间

static var _index := {}      # name -> {kind, id}
static var _cards := {}      # id -> CardData
static var _relics := {}     # id -> RelicData
static var _built := false
## R187 性能：`scan` 是纯函数（文案 → 提及列表），悬浮窗/附带块每次重绘都调。
## 缓存命中只剩字典查询；返回浅副本（条目 Dictionary 请勿原地改写）。
const SCAN_CACHE_MAX := 256
static var _scan_cache := {}


static func reset_cache() -> void:
	## 换过卡库 / 道具库数据后（正常流程不需要）可手动清一次。
	_index = {}
	_cards = {}
	_relics = {}
	_built = false
	_scan_cache = {}   # R187：名字表变了，文案扫描结果也一并作废


static func index() -> Dictionary:
	## 名字 → {kind:"card"|"relic", id:int}。懒建 + 缓存。
	if _built:
		return _index
	_built = true
	var idx := {}
	var cmap := {}
	var rmap := {}
	for c: CardData in CardRepo.load_json().all_cards():
		if c.card_name != "":
			idx[c.card_name] = {"kind": "card", "id": c.id}
		cmap[c.id] = c
	for r: RelicData in RelicRepo.load_json().all_relics():
		if r.relic_name != "" and not idx.has(r.relic_name):
			idx[r.relic_name] = {"kind": "relic", "id": r.id}
		rmap[r.id] = r
	_index = idx
	_cards = cmap
	_relics = rmap
	return _index


static func resolve(name: String) -> Dictionary:
	return index().get(name.strip_edges(), {})


static func card_of(id: int) -> CardData:
	index()
	return _cards.get(id)


static func relic_of(id: int) -> RelicData:
	index()
	return _relics.get(id)


static func scan(text: String) -> Array:
	## 文案里出现过的（已登记的）提及：去重、按首次出现顺序。
	## 返回 [{name, token, kind, id}]；`token` 是**含标记**的原文（「名字」/ **名字**）。
	## ⚠️ R187：返回缓存的**浅副本** —— 条目 Dictionary 请勿原地改写。
	if _scan_cache.has(text):
		return (_scan_cache[text] as Array).duplicate()
	var out: Array = []
	var seen := {}
	var i := 0
	var n := text.length()
	while i < n:
		var tok := ""
		var nm := ""
		var nxt := i + 1
		if text[i] == "「":
			var j := text.find("」", i + 1)
			if j < 0:
				break
			tok = text.substr(i, j - i + 1)
			nm = text.substr(i + 1, j - i - 1)
			nxt = j + 1
		elif text[i] == "*" and i + 1 < n and text[i + 1] == "*":
			var k := text.find("**", i + 2)
			if k < 0:
				break
			tok = text.substr(i, k - i + 2)
			nm = text.substr(i + 2, k - i - 2)
			nxt = k + 2
		else:
			i += 1
			continue
		i = nxt
		var ref := resolve(nm)
		if nm == "" or ref.is_empty() or seen.has(nm):
			continue
		seen[nm] = true
		out.append({"name": nm, "token": tok, "kind": str(ref["kind"]), "id": int(ref["id"])})
	if _scan_cache.size() >= SCAN_CACHE_MAX:
		_scan_cache.clear()
	_scan_cache[text] = out
	return out.duplicate()


static func text_color(base: Color) -> Color:
	## 提及名在**当前底色**上的强调色：浅底用琥珀棕、暗底用亮金 ——
	## 保证「提到名字」永远比正文醒目、而且两种底色上都读得清。
	return UiTheme.MENTION_ON_LIGHT if base.get_luminance() > 0.45 else UiTheme.MENTION_ON_DARK


static func text_color_on(bg: Color) -> Color:
	## R206：按**真实底色**挑提及强调色（浅底琥珀棕 / 暗底亮金）。
	## ⚠️ `text_color()` 的判据看的是**正文色**亮度 —— 只在「正文色与底色明暗相反」时才对。
	## 羊皮纸面板上正文用深蓝 `#2a5a8a`，会被误判成暗底 → 亮金 `#f2c14e` 画在奶油色上
	## 只剩 1.6:1：「这条文案里提到的」那行与提及名几乎看不见（R206 用户反馈）。
	## 只要有明确底色，一律走这里。
	return UiTheme.MENTION_ON_LIGHT if bg.get_luminance() > 0.45 else UiTheme.MENTION_ON_DARK


static func same(a: Dictionary, b: Dictionary) -> bool:
	## 两个引用是不是同一张卡 / 同一件道具（悬浮高亮判定用）。
	if a.is_empty() != b.is_empty():
		return false
	if a.is_empty():
		return true
	return str(a.get("kind", "")) == str(b.get("kind", "")) \
			and int(a.get("id", -1)) == int(b.get("id", -1))


static func label_of(ref: Dictionary) -> String:
	## 人类可读的名字（找不到就返回空串）。
	if str(ref.get("kind", "")) == "card":
		var c := card_of(int(ref.get("id", -1)))
		return c.card_name if c != null else ""
	var r := relic_of(int(ref.get("id", -1)))
	return r.relic_name if r != null else ""


static func kind_label(ref: Dictionary) -> String:
	return "卡牌" if str(ref.get("kind", "")) == "card" else "道具"


static func tip_size(font: Font, ref: Dictionary) -> Vector2:
	## 悬浮件尺寸（不含位置）。
	if str(ref.get("kind", "")) == "card":
		var ch := 76.0 * CARD_SCALE
		var cw := ch * 63.0 / 76.0
		return Vector2(cw + PAD * 2.0, ch + PAD * 2.0)
	var rel := relic_of(int(ref.get("id", -1)))
	var w := RELIC_W
	var lines: Array[String] = []
	if rel != null:
		lines = CardFace.wrap_text(font, rel.desc, w - RELIC_PAD * 2.0, UiTheme.FS_LABEL)
	return Vector2(w, RELIC_PAD * 2.0 + 30.0 + float(lines.size()) * 19.0)


static func block_height(font: Font, font_bold: Font, text: String, w: float,
		head_h := 32.0) -> float:
	## 「提到的卡 / 道具」附带块需要多高（0 = 这条文案没有提及）。
	## 调用方拿它去算悬浮窗总高，好让**一个**边框把摘要一起框住。
	## `head_h`：标题那一行的占位 —— 悬浮窗预留 **32**（= `BLOCK_HEAD_H` 24 + 8px 间距），
	## 面板内要跟 `draw_reference_block()` 的行距**严格同源**就传 `BLOCK_HEAD_H`（R206）。
	## ⚠️ 每项 / 摘要 / 项间距一律用上面的 `BLOCK_*` 常量，别再写字面量。
	var refs := scan(text)
	if refs.is_empty():
		return 0.0
	var h := head_h
	for r: Dictionary in refs:
		h += BLOCK_ITEM_H + float(summary_lines(font, r, w - 14.0).size()) * BLOCK_LINE_H \
				+ BLOCK_GAP
	return h


static func draw_tip(canvas: CanvasItem, font: Font, font_bold: Font,
		ref: Dictionary, top_left: Vector2, extra_bottom := 0.0,
		block_text := "") -> float:
	## 在 `top_left` 处画**整套**悬浮件：暗底 + 金边（与事件页 / 奖励悬浮窗同一语言）。
	## 卡牌 → 真实卡面（与图鉴 / 战场同一套 `CardFace`，所见即所得）；
	## 道具 → 名称 + 「类型 · 来源」+ 完整说明（按面板宽折行）。
	var sz := tip_size(font, ref)
	var frame := Rect2(top_left, Vector2(sz.x, sz.y + extra_bottom))
	canvas.draw_rect(frame, Color(0.10, 0.11, 0.15, 0.96), true)
	canvas.draw_rect(frame, UiTheme.ACCENT_GOLD, false, 1.4)
	if str(ref.get("kind", "")) == "card":
		var card := card_of(int(ref.get("id", -1)))
		if card == null:
			return 0.0
		var ch := 76.0 * CARD_SCALE
		var cw := ch * 63.0 / 76.0
		CardFace.draw(canvas, card, Rect2(frame.position + Vector2(PAD, PAD),
				Vector2(cw, ch)), card.health, false, false, font, font_bold, -1, false)
		return _draw_tip_block(canvas, font, font_bold, frame, sz, extra_bottom, block_text)
	var rel := relic_of(int(ref.get("id", -1)))
	if rel == null:
		return 0.0
	var p := RELIC_PAD
	var inner := RELIC_W - p * 2.0
	canvas.draw_string(font_bold, frame.position + Vector2(p, p + 16.0),
			rel.relic_name, HORIZONTAL_ALIGNMENT_LEFT, inner,
			UiTheme.FS_SUBHEAD, rel.badge_color())
	canvas.draw_string(font, frame.position + Vector2(p, p + 34.0),
			rel.tag_line(), HORIZONTAL_ALIGNMENT_LEFT,
			inner, UiTheme.FS_CAPTION, UiTheme.INK_ON_DARK)
	var y := frame.position.y + p + 45.0
	for t: String in CardFace.wrap_text(font, rel.desc, inner, UiTheme.FS_LABEL):
		canvas.draw_string(font, Vector2(frame.position.x + p, y), t,
				HORIZONTAL_ALIGNMENT_LEFT, inner, UiTheme.FS_LABEL, Color("f0ead8"))
		y += 19.0
	return _draw_tip_block(canvas, font, font_bold, frame, sz, extra_bottom, block_text)


static func _draw_tip_block(canvas: CanvasItem, font: Font, font_bold: Font,
		frame: Rect2, sz: Vector2, extra_bottom: float, block_text: String) -> float:
	## 悬浮窗底部那段「提到的卡 / 道具」摘要（extra_bottom > 0 才有位置）。
	if extra_bottom <= 0.0 or block_text == "":
		return 0.0
	var blk := draw_reference_block(canvas, font, font_bold, block_text,
			frame.position.x + PAD, frame.position.y + sz.y + 16.0,
			sz.x - PAD * 2.0, Color("f0ead8"))
	return float(blk["y"])


static func summary_lines(font: Font, ref: Dictionary, max_w: float, max_lines := BLOCK_MAX_LINES) -> Array:
	## 一处提及的摘要（折好行、最多 max_lines 行，超出以「…」收尾）。
	var out: Array = []
	var body := ""
	if str(ref.get("kind", "")) == "card":
		var c := card_of(int(ref.get("id", -1)))
		if c == null:
			return out
		var stats := CardFace.stats_line(c)
		var eff := CardText.naturalize(c.effect_text).replace("\n", " ").strip_edges()
		body = "%s · %d 费 · %s%s" % [c.kind, c.cost, stats,
				("；" + eff) if eff != "" else ""]
	else:
		var r := relic_of(int(ref.get("id", -1)))
		if r == null:
			return out
		body = "%s；%s" % [r.tag_line(),
				CardText.naturalize(r.desc).replace("\n", " ").strip_edges()]
	var lines: Array[String] = CardFace.wrap_text(font, body, max_w, UiTheme.FS_CAPTION)
	for i in lines.size():
		if i >= max_lines:
			break
		var t: String = lines[i]
		if i == max_lines - 1 and lines.size() > max_lines:
			t = t + "…"
		out.append(t)
	return out


static func draw_reference_block(canvas: CanvasItem, font: Font, font_bold: Font,
		text: String, x: float, y: float, w: float, base_col: Color,
		draw_head := true, max_y := -1.0, bg_col := Color(0, 0, 0, 0)) -> Dictionary:
	## 「这条文案里提到的：…」附带块 —— 把被提及的卡 / 道具**名字 + 摘要**一并列出来
	## （用户口径 R168：卡片文本提到另一张卡牌时，看这张卡的详情要能顺带看到那张卡）。
	## 返回 `{y: 画完后的基线, hits: [{rect, name, kind, id}]}`，`hits` 交给悬浮层即可。
	var refs := scan(text)
	var res := {"y": y, "hits": []}
	if refs.is_empty():
		return res
	var ty := y
	var hits: Array = []
	var mcol := text_color(base_col)
	if bg_col.a > 0.0:
		mcol = text_color_on(bg_col)   # R206：有真实底色就按底色挑，别拿正文色猜
	if draw_head:
		canvas.draw_line(Vector2(x, ty - 7.0), Vector2(x + w, ty - 7.0),
				Color(base_col.r, base_col.g, base_col.b, 0.22), 1.0)
		if max_y >= 0.0 and ty + 22.0 > max_y:
			return res
		canvas.draw_string(font_bold, Vector2(x, ty + 6.0), BLOCK_HEAD,
				HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_CAPTION, base_col)
		ty += BLOCK_HEAD_H
	for r: Dictionary in refs:
		if max_y >= 0.0 and ty + 16.0 > max_y:
			break
		var nm := str(r["name"])
		var head := "· %s「%s」" % [kind_label(r), nm]
		var hw: float = font_bold.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1,
				UiTheme.FS_CAPTION).x
		var hrect := Rect2(x - 3.0, ty - 12.0, hw + 6.0, 18.0)
		canvas.draw_rect(hrect, Color(mcol.r, mcol.g, mcol.b, 0.14), true)
		canvas.draw_string(font_bold, Vector2(x, ty), head,
				HORIZONTAL_ALIGNMENT_LEFT, w, UiTheme.FS_CAPTION, mcol)
		# R206：这里原来还画一条下划线，压着 12 号字的字底（底衬底边也在同一高度）
		# → 两重装饰叠成「文字被上下夹住」；底衬已足够表达「这里能悬浮看详情」，删掉。
		hits.append({"rect": hrect,
				"name": nm, "kind": str(r["kind"]), "id": int(r["id"])})
		ty += BLOCK_ITEM_H
		for line: String in summary_lines(font, r, w - 14.0):
			if max_y >= 0.0 and ty > max_y:
				break
			canvas.draw_string(font, Vector2(x + 12.0, ty), line,
					HORIZONTAL_ALIGNMENT_LEFT, w - 12.0, UiTheme.FS_CAPTION,
					Color(base_col.r, base_col.g, base_col.b, 0.78))
			ty += BLOCK_LINE_H
		ty += BLOCK_GAP
	res["y"] = ty
	res["hits"] = hits
	return res
