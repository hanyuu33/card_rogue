class_name TextWrap
extends RefCounted
## 严格的自动换行引擎（R292）—— 所有「一段文案要塞进固定宽度」的地方都走这里。
##
## ## 为什么需要它
## `CanvasItem.draw_string()` **不会**自动折行。以前各处自己写了几份「逐字累加测量」
## 的小循环（`CardFace.wrap_text`、`CardText.wrap_segments`、`battle_scene._wrap_lines`、
## `map_scene._wrap_relic_text`、`relic_viewer._wrap`、`relic_pick_scene._wrap_text`、
## `class_pick_scene._wrap_text`），于是：
##   * 同一段文案在不同面板上的折法**不一致**；
##   * 折点只看「宽度够不够」，于是行首会撞上「，」「）」「」」这种标点 ——
##     玩家看到的是「换行没排好」，而不是「宽度不够」；
##   * 「12」「HP」「+2」这类连续字母数字会被从中间劈开（`12` → `1` / `2`）；
##   * 「卡名」被拆成两截，名字和引号分居两行。
## 本模块把这些规则收成**一份**（唯一口），按「不可拆分单元（cluster）」贪心填充。
##
## ## 断行规则（严格口径）
##   ① **行首禁则**：`，。、；：！？）」』】》〉”’…` 不许出现在行首 → 粘到前一个单元；
##   ② **行尾禁则**：`（「『【《〈“‘` 不许出现在行尾 → 粘住后一个字；
##   ③ **引号成对**：`「…」` / `『…』` / `“…”` 内部不拆行（卡面文案里大量 `「卡名」`
##      就是这种；拆开会让名字断成两截）。长度上限 `CLUSTER_MAX`，超了自然放开；
##   ④ **西文/数字成词**：连续字母数字（含 `+ - . / %`）算一个整体，不从中间断；
##   ⑤ **空格只在断点处吃掉**：折行处不把空格带到下一行行首，行尾也不留空格；
##   ⑥ `\n` 是**硬换行**（显示层保留这个能力，数据里不写）；
##   ⑦ 单个单元本身就超宽（超长英文单词 / 一长串引号）→ 退化成**逐字硬切**，
##      **保证不溢出、保证不死循环**（绘制代码里的循环绝不允许只靠「条件终将不成立」退出）；
##   ⑧ `safety` 安全边距：`get_string_size` 的度量比 `draw_string(width=…)` 的裁剪**略窄**，
##      正好贴着上限的那个字会被整颗裁掉（R244 在道具页实测过）。默认留 `SAFETY` px。
##
## ## ⚠️ 两套度量（踩过的坑）
## 纯文本行是**一个 `draw_string` 画一整行**，所以必须用「整行串」度量 ——
## 把逐单元的宽度**相加**会偏小（字体回退 / 提示微调下，片段单独度量之和 ≠ 整串实测：
## R292 实测同一行相加 108px、整串 120px，于是最后一行会画出面板外）。
## 富文本行是**逐片段 `draw_string`**（`CardText.draw_wrapped_hits` 里 `cx += w`），
## 所以必须用「按片段/字重分条度量再相加」—— 那才是玩家眼里的宽度。两条路径各按各的
## 渲染方式度量，`_layout_plain` / `_layout_rich` 因此是两个函数。
##
## 纯函数 + 缓存；返回**副本**，调用方随便改，不会污染缓存。

# ── 禁则表（唯一口）──────────────────────────────────────────────
const OPEN_PUNCT := "（(「『【《〈“‘[{｛"
const CLOSE_PUNCT := "，。、；：！？）」』】》〉”’…‰℃・·,.!?;:)]}｝"
## 成对引号：开 → 收。命中开括号时，整对**不在内部断行**。
const QUOTE_CLOSE_OF := {
	"「": "」", "『": "』", "【": "】", "《": "》", "〈": "〉",
	"（": "）", "(": ")", "“": "”", "‘": "’", "[": "]", "{": "}", "｛": "｝",
}
## 「引号成对」的最长吸附长度：超过就放开断点（防止没闭合的括号把整段吞成一行）。
const CLUSTER_MAX := 14
## 度量补偿：贴边的那颗字会被 draw_string 的宽度裁剪吃掉（R244 实测极端案例约 14px，
## 常规面板 2px 足够；道具三选一那页显式传 14）。
const SAFETY := 2.0
const CACHE_MAX := 1024
static var _cache := {}


# ══════════════════════════════════════════════════════════════════
#  基础度量 / 字符分类
# ══════════════════════════════════════════════════════════════════

static func _measure(font: Font, s: String, size: int) -> float:
	if s == "":
		return 0.0
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func _is_word_char(ch: String) -> bool:
	## 「西文/数字成词」的字符集：字母、数字，以及贴在数字上的符号（+2 / 1/2 / 25% / 3.5）。
	if ch == "":
		return false
	var cp := ch.unicode_at(0)
	if cp >= 48 and cp <= 57:      # 0-9
		return true
	if cp >= 65 and cp <= 90:      # A-Z
		return true
	if cp >= 97 and cp <= 122:     # a-z
		return true
	return ch == "+" or ch == "-" or ch == "." or ch == "/" or ch == "%"


static func _no_break_before(ch: String) -> bool:
	return ch != "" and CLOSE_PUNCT.contains(ch)


static func _no_break_after(ch: String) -> bool:
	return ch != "" and OPEN_PUNCT.contains(ch)


# ══════════════════════════════════════════════════════════════════
#  单元（cluster）构建
# ══════════════════════════════════════════════════════════════════

static func _first_ch(u: Dictionary) -> String:
	var cs: Array = u["chars"]
	return "" if cs.is_empty() else str((cs[0] as Dictionary)["c"])


static func _last_ch(u: Dictionary) -> String:
	var cs: Array = u["chars"]
	return "" if cs.is_empty() else str((cs[cs.size() - 1] as Dictionary)["c"])


static func _unit_text(u: Dictionary) -> String:
	var s := ""
	for c in u["chars"]:
		s += str((c as Dictionary)["c"])
	return s


static func _absorb(prev: Dictionary, u: Dictionary) -> void:
	## 把一个单元并进前一个单元（禁则合并）。`prev` 是字典 → 原地改即可。
	(prev["chars"] as Array).append_array(u["chars"])


static func _has_quote_close(u: Dictionary) -> bool:
	## 「开括号 + 中途某处已经收尾」→ 这一对已经闭合，不必继续吸附。
	var open := _first_ch(u)
	if not QUOTE_CLOSE_OF.has(open):
		return true
	return _unit_text(u).find(str(QUOTE_CLOSE_OF[open])) >= 0


static func _build_units(chars: Array) -> Array:
	## 字符数组 → 不可拆分单元数组。
	## chars: `[{c: String, si: int, b: bool}]`（si = 属于第几个片段，b = 是否加粗）
	## 单元：`{chars: Array, space: bool, hard: bool}`
	var units: Array = []
	var i := 0
	var n := chars.size()
	while i < n:
		var ch := str((chars[i] as Dictionary)["c"])
		if ch == "\n":
			units.append({"chars": [chars[i]], "space": false, "hard": true})
			i += 1
			continue
		if ch == " " or ch == "\t":
			units.append({"chars": [chars[i]], "space": true, "hard": false})
			i += 1
			continue
		if _is_word_char(ch):
			var j := i
			while j < n and _is_word_char(str((chars[j] as Dictionary)["c"])):
				j += 1
			units.append({"chars": chars.slice(i, j), "space": false, "hard": false})
			i = j
			continue
		units.append({"chars": [chars[i]], "space": false, "hard": false})
		i += 1
	# ── 禁则合并（单遍）──
	var out: Array = []
	for u in units:
		if out.is_empty():
			out.append(u)
			continue
		var prev: Dictionary = out[out.size() - 1]
		var u_is_space := bool(u["space"])
		var u_is_hard := bool(u["hard"])
		# ① 行首禁则：闭合标点粘到前一个单元
		if not u_is_space and not u_is_hard and _no_break_before(_first_ch(u)):
			_absorb(prev, u)
			continue
		# ② 行尾禁则：开引号 / 开括号粘住后一个字
		if not u_is_space and not bool(prev["space"]) and _no_break_after(_last_ch(prev)):
			_absorb(prev, u)
			continue
		# ③ 引号成对：还没闭合就继续吸（有长度上限，保证能退出）
		if not u_is_space and not u_is_hard and not bool(prev["space"]) \
				and (prev["chars"] as Array).size() < CLUSTER_MAX \
				and QUOTE_CLOSE_OF.has(_first_ch(prev)) and not _has_quote_close(prev):
			_absorb(prev, u)
			continue
		out.append(u)
	return out


static func _trim_line(cur: Array) -> Array:
	## 收一行：**行尾不留空格**（折行处的空格直接吃掉）。
	var ln: Array = cur.duplicate()
	while not ln.is_empty() and bool((ln[ln.size() - 1] as Dictionary)["space"]):
		ln.pop_back()
	return ln


# ══════════════════════════════════════════════════════════════════
#  排版：纯文本（整行一次 draw_string → 用整行串度量）
# ══════════════════════════════════════════════════════════════════

static func _hard_split_plain(font: Font, text: String, limit: float, size: int) -> Array[String]:
	## 超宽单元（塞不进一整行）退化处理：逐字硬切。
	## ⚠️ 硬切会破坏禁则（切点正好把「。」「）」留到下一行行首），所以切完必须
	## 补一次「追い込み」：把上一行的最后一个字拖到下一行来陪它 —— `_fix_leading_punct`。
	var parts: Array[String] = []
	var cur := ""
	for ch in text:
		if cur != "" and _measure(font, cur + ch, size) > limit:
			parts.append(cur)
			cur = ch
		else:
			cur += ch
	if cur != "" or parts.is_empty():
		parts.append(cur)
	return _fix_leading_punct_str(parts)


static func _fix_leading_punct_str(parts: Array[String]) -> Array[String]:
	## 硬切善后：行首落在收尾标点上 → 从上一行末尾拖一个字下来（上一行只剩 1 字就作罢）。
	## 有硬上限 `CLUSTER_MAX` 轮，绝不靠「条件终将不成立」退出。
	var guard := 0
	var i := 1
	while i < parts.size() and guard < CLUSTER_MAX:
		guard += 1
		var cur := parts[i]
		var prev := parts[i - 1]
		if cur.length() > 0 and _no_break_before(cur.substr(0, 1)) and prev.length() >= 2:
			parts[i] = prev.substr(prev.length() - 1) + cur
			parts[i - 1] = prev.substr(0, prev.length() - 1)
			continue
		i += 1
	return parts


static func _layout_plain(font: Font, units: Array, limit: float, size: int) -> Array:
	var lines: Array = []
	var cur: Array = []
	var cur_txt := ""
	for u in units:
		if bool(u["hard"]):
			lines.append(_trim_line(cur))
			cur = []
			cur_txt = ""
			continue
		var t := _unit_text(u)
		if bool(u["space"]):
			# 空格只是「断点」：行首直接丢；放得下就带上（渲染时行尾会被剪掉）。
			if cur.is_empty():
				continue
			if _measure(font, cur_txt + t, size) <= limit:
				cur.append(u)
				cur_txt += t
			else:
				lines.append(_trim_line(cur))
				cur = []
				cur_txt = ""
			continue
		if not cur.is_empty() and _measure(font, cur_txt + t, size) <= limit:
			cur.append(u)
			cur_txt += t
			continue
		if cur.is_empty() and _measure(font, t, size) <= limit:
			cur = [u]
			cur_txt = t
			continue
		# 换行（cur 非空 → 先收行；单元自身超宽 → 硬切）
		if not cur.is_empty():
			lines.append(_trim_line(cur))
			cur = []
			cur_txt = ""
		var parts := _hard_split_plain(font, t, limit, size)
		for pi in parts.size():
			var piece: Dictionary = {"chars": [], "space": false, "hard": false}
			for ch in parts[pi]:
				piece["chars"].append({"c": ch, "si": 0, "b": false})
			if pi == parts.size() - 1:
				cur = [piece]
				cur_txt = parts[pi]
			else:
				lines.append([piece])
	if not cur.is_empty() or lines.is_empty():
		lines.append(_trim_line(cur))
	return lines


# ══════════════════════════════════════════════════════════════════
#  排版：富文本（逐片段 draw_string → 按片段/字重分条度量再相加）
# ══════════════════════════════════════════════════════════════════

static func _unit_width(font: Font, font_bold: Font, u: Dictionary, size: int) -> float:
	## 单元宽度：按「同片段 + 同字重」切成长条各自度量再相加（与 `draw_wrapped_hits`
	## 里 `cx += w` 的口径一致）。
	var w := 0.0
	var run := ""
	var run_si := -1
	var run_b := false
	for c in u["chars"]:
		var cd: Dictionary = c
		var si := int(cd["si"])
		var b := bool(cd["b"])
		if si != run_si or b != run_b:
			if run != "":
				w += _measure(font_bold if run_b else font, run, size)
			run = ""
			run_si = si
			run_b = b
		run += str(cd["c"])
	if run != "":
		w += _measure(font_bold if run_b else font, run, size)
	return w


static func _line_width(font: Font, font_bold: Font, cur: Array, size: int) -> float:
	var w := 0.0
	for u in cur:
		w += _unit_width(font, font_bold, u, size)
	return w


static func _hard_split_rich(font: Font, font_bold: Font, u: Dictionary,
		limit: float, size: int) -> Array:
	## 超宽单元退化处理：逐字硬切（每片都尽量塞满 limit）。
	var parts: Array = []
	var buf: Array = []
	var buf_w := 0.0
	for c in u["chars"]:
		var cd: Dictionary = c
		var cw := _measure(font_bold if bool(cd["b"]) else font, str(cd["c"]), size)
		if not buf.is_empty() and buf_w + cw > limit:
			parts.append(buf)
			buf = []
			buf_w = 0.0
		buf.append(cd)
		buf_w += cw
	if not buf.is_empty():
		parts.append(buf)
	if parts.is_empty():
		parts.append([])
	return _fix_leading_punct(parts)


static func _fix_leading_punct(parts: Array) -> Array:
	## 硬切善后（富文本版，单元是字符字典数组）：行首落在收尾标点上 →
	## 从上一片末尾拖一个字下来。上一片只剩 1 字就作罢，硬上限 `CLUSTER_MAX` 轮。
	var guard := 0
	var i := 1
	while i < parts.size() and guard < CLUSTER_MAX:
		guard += 1
		var cur: Array = parts[i]
		var prev: Array = parts[i - 1]
		if not cur.is_empty() and prev.size() >= 2 \
				and _no_break_before(str((cur[0] as Dictionary)["c"])):
			cur.insert(0, prev[prev.size() - 1])
			prev.pop_back()
			continue
		i += 1
	return parts


static func _layout_rich(font: Font, font_bold: Font, units: Array,
		limit: float, size: int) -> Array:
	var lines: Array = []
	var cur: Array = []
	var cur_w := 0.0
	for u in units:
		if bool(u["hard"]):
			lines.append(_trim_line(cur))
			cur = []
			cur_w = 0.0
			continue
		var w := _unit_width(font, font_bold, u, size)
		if bool(u["space"]):
			if cur.is_empty():
				continue
			if cur_w + w <= limit:
				cur.append(u)
				cur_w += w
			else:
				lines.append(_trim_line(cur))
				cur = []
				cur_w = 0.0
			continue
		if not cur.is_empty() and cur_w + w <= limit:
			cur.append(u)
			cur_w += w
			continue
		if cur.is_empty() and w <= limit:
			cur = [u]
			cur_w = w
			continue
		if not cur.is_empty():
			lines.append(_trim_line(cur))
			cur = []
			cur_w = 0.0
		if w <= limit:
			cur = [u]
			cur_w = w
			continue
		var parts: Array = _hard_split_rich(font, font_bold, u, limit, size)
		for pi in parts.size():
			var piece: Dictionary = {"chars": parts[pi], "space": false, "hard": false}
			if pi == parts.size() - 1:
				cur = [piece]
				cur_w = _unit_width(font, font_bold, piece, size)
			else:
				lines.append([piece])
	if not cur.is_empty() or lines.is_empty():
		lines.append(_trim_line(cur))
	return lines


# ══════════════════════════════════════════════════════════════════
#  对外 API
# ══════════════════════════════════════════════════════════════════

static func _plain_of(chars: Array) -> String:
	var s := ""
	for c in chars:
		s += str((c as Dictionary)["c"])
	return s


static func _cache_put(ck: String, val: Variant) -> void:
	if _cache.size() >= CACHE_MAX:
		_cache.clear()
	_cache[ck] = val


static func wrap_plain(font: Font, text: String, max_w: float, size: int,
		safety := SAFETY) -> Array[String]:
	## 纯文本折行（卡名以外的所有卡片 / 道具 / 事件说明都走这里）。
	## ⚠️ 返回的是**副本**，调用方增删不伤缓存（R187 的教训：同实例被改过一次就永久错了）。
	if text == "":
		var one: Array[String] = [""]
		return one
	if font == null or max_w <= 0.0:
		return [text]
	var limit: float = maxf(1.0, max_w - safety)
	var ck := "P|%d|%d|%d|%s" % [font.get_instance_id(), size, roundi(limit * 4.0), text]
	if _cache.has(ck):
		var hit: Array = _cache[ck]
		return hit.duplicate()
	var chars: Array = []
	for i in text.length():
		chars.append({"c": text[i], "si": 0, "b": false})
	var lines := _layout_plain(font, _build_units(chars), limit, size)
	var out: Array[String] = []
	for ln in lines:
		var s := ""
		for u in ln:
			s += _unit_text(u)
		out.append(s)
	_cache_put(ck, out.duplicate())
	return out.duplicate()


static func wrap_rich(font: Font, font_bold: Font, segs: Array, max_w: float, size: int,
		safety := SAFETY) -> Array:
	## 富文本折行：**保留每段的 bold / italic / code / mention**（加粗段用加粗字体度量）。
	## 返回：若干「行」，每行是片段数组（可直接交给 `CardText.draw_wrapped_hits()`）。
	var fnt_b: Font = font_bold if font_bold != null else font
	if font == null:
		return [segs]
	var limit: float = maxf(1.0, max_w - safety)
	var chars: Array = []
	var sig := ""
	for si in segs.size():
		var seg: Dictionary = segs[si]
		var t := str(seg.get("text", ""))
		var b := bool(seg.get("bold", false))
		sig += "%d%s," % [t.length(), "b" if b else "-"]
		for i in t.length():
			chars.append({"c": t[i], "si": si, "b": b})
	var plain := _plain_of(chars)
	var ck := "R|%d|%d|%d|%d|%s|%s" % [font.get_instance_id(), fnt_b.get_instance_id(),
			size, roundi(limit * 4.0), sig, plain]
	if _cache.has(ck):
		var hit: Array = _cache[ck]
		return hit.duplicate(true)
	var lines := _layout_rich(font, fnt_b, _build_units(chars), limit, size)
	var out: Array = []
	for ln in lines:
		var cur_line: Array = []
		var run := ""
		var run_si := -1
		for u in ln:
			for c in (u as Dictionary)["chars"]:
				var cd: Dictionary = c
				var si := int(cd["si"])
				if si != run_si:
					if run != "":
						cur_line.append(_carry(segs[run_si], run))
					run = ""
					run_si = si
				run += str(cd["c"])
		if run != "":
			cur_line.append(_carry(segs[run_si], run))
		out.append(cur_line)
	_cache_put(ck, out.duplicate(true))
	return out.duplicate(true)


static func _carry(seg: Dictionary, text: String) -> Dictionary:
	## 折行会把一个片段切成多段 → 新片段必须**原样带走** `mention`
	## （漏带会让「提及」在换行处突然变回普通文字：颜色与悬浮一起丢）。
	var d := {"text": text, "bold": seg.get("bold", false),
			"italic": seg.get("italic", false), "code": seg.get("code", false)}
	if seg.has("mention"):
		d["mention"] = seg["mention"]
	return d
