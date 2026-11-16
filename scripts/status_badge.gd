class_name StatusBadge
extends RefCounted
## R774：状态特效文字的**绘制唯一口**。素材来自 AI 生成（`assets/fx/status_words/`、
## `assets/fx/status_digits/`），字形用内嵌思源黑体渲染锁死、AI 只贡献质感，黑底已抠透明。
##
## 取代 R770c 的纯矢量徽标：那版「有图案没质感」，店长要的是「冰雪嘉年华」那种
## 主题艺术字（冰封=冰块带冰凌积雪、燃烧=熔岩龟裂、中毒=毒液气泡…）。AI 直接画整字
## 会写错复杂字（燃/烧/封/障都栽过），所以：
##   * 字形 = 内嵌字体渲染（100% 正确）；
##   * 质感 = AI 生成的整字图（image-to-image 锁字形，复杂字用纹理合成兜底）。
##
## 文本解析：`_segments()` 把一条飘字拆成「状态词图 + 数字/符号图 + 兜底文字」片段，
## 横向拼接（「中毒 -3」= 中毒.png + sign_minus.png + digit_3.png）。
##
## ⚠️ 所有绘制发生在调用方 `_draw()` 内（`ci` 是那个 CanvasItem）；本类不 queue_redraw、
## 不读时钟。素材用静态缓存，不每帧 load。

const GLYPH_NONE := 0
const GLYPH_ICE := 1
const GLYPH_FLAME := 2
const GLYPH_POISON := 3
const GLYPH_BOLT := 4
const GLYPH_SHIELD := 5
const GLYPH_HEAL := 6
const GLYPH_SWORD := 7
const GLYPH_ENERGY := 8
const GLYPH_SKULL := 9
const GLYPH_STAR := 10
const GLYPH_TAUNT := 11

## 关键词表：按顺序匹配，先中先得。特例（「超负荷死亡」）排在泛词（「死亡」）前。
## 现在这些关键词不只决定图案，还决定**用哪张状态词素材**。
const RULES := [
	["冰封", GLYPH_ICE], ["冻结", GLYPH_ICE], ["冰冻", GLYPH_ICE], ["寒霜", GLYPH_ICE],
	["中毒", GLYPH_POISON], ["剧毒", GLYPH_POISON], ["毒", GLYPH_POISON],
	["燃烧", GLYPH_FLAME], ["灼烧", GLYPH_FLAME], ["烈焰", GLYPH_FLAME], ["着火", GLYPH_FLAME],
	["感电", GLYPH_BOLT], ["雷", GLYPH_BOLT], ["闪电", GLYPH_BOLT],
	["屏障", GLYPH_SHIELD], ["护甲", GLYPH_SHIELD], ["护盾", GLYPH_SHIELD], ["格挡", GLYPH_SHIELD],
	["治疗", GLYPH_HEAL], ["回复", GLYPH_HEAL], ["回血", GLYPH_HEAL],
	["自我修复", GLYPH_HEAL], ["生命", GLYPH_HEAL],
	["锻造", GLYPH_SWORD], ["精进", GLYPH_SWORD], ["攻击", GLYPH_SWORD], ["力量", GLYPH_SWORD],
	["超负荷死亡", GLYPH_SKULL], ["击破", GLYPH_SKULL], ["死亡", GLYPH_SKULL],
	["消灭", GLYPH_SKULL],
	["能源", GLYPH_ENERGY], ["能量", GLYPH_ENERGY], ["费用", GLYPH_ENERGY], ["费", GLYPH_ENERGY],
	["眩晕", GLYPH_STAR], ["睡眠", GLYPH_STAR], ["沉睡", GLYPH_STAR],
	["嘲讽", GLYPH_TAUNT],
]

## 英文关键词表（非中文语言统一用英文艺术字，店长口径）。长词在前，避免 Burn 误吞 Burning。
const RULES_EN := [
	["Frozen", GLYPH_ICE], ["Freezing", GLYPH_ICE], ["Freeze", GLYPH_ICE],
	["Burning", GLYPH_FLAME], ["Burn", GLYPH_FLAME],
	["Poisoned", GLYPH_POISON], ["Poison", GLYPH_POISON],
	["Electrified", GLYPH_BOLT], ["Shock", GLYPH_BOLT],
	["Barrier", GLYPH_SHIELD], ["Shield", GLYPH_SHIELD],
	["Healing", GLYPH_HEAL], ["Heal", GLYPH_HEAL],
	["Strength", GLYPH_SWORD], ["Power", GLYPH_SWORD],
	["Death", GLYPH_SKULL], ["Dead", GLYPH_SKULL],
	["Energy", GLYPH_ENERGY],
	["Stunned", GLYPH_STAR], ["Stun", GLYPH_STAR],
	["Taunt", GLYPH_TAUNT],
]

## 主题 → 状态词素材。关键词（冻结/冰冻/灼烧…）都归到同一张主素材。
const WORD_TEX := {
	GLYPH_ICE: "res://assets/fx/status_words/bingfeng.png",
	GLYPH_FLAME: "res://assets/fx/status_words/ranshao.png",
	GLYPH_POISON: "res://assets/fx/status_words/zhongdu.png",
	GLYPH_BOLT: "res://assets/fx/status_words/gandian.png",
	GLYPH_SHIELD: "res://assets/fx/status_words/pingzhang.png",
	GLYPH_HEAL: "res://assets/fx/status_words/zhiliao.png",
	GLYPH_SWORD: "res://assets/fx/status_words/liliang.png",
	GLYPH_ENERGY: "res://assets/fx/status_words/nengliang.png",
	GLYPH_SKULL: "res://assets/fx/status_words/siwang.png",
	GLYPH_STAR: "res://assets/fx/status_words/xuanyun.png",
	GLYPH_TAUNT: "res://assets/fx/status_words/chaofeng.png",
}

## 英文状态词素材（非中文语言统一用这一套）。
const WORD_TEX_EN := {
	GLYPH_ICE: "res://assets/fx/status_words_en/frozen.png",
	GLYPH_FLAME: "res://assets/fx/status_words_en/burn.png",
	GLYPH_POISON: "res://assets/fx/status_words_en/poison.png",
	GLYPH_BOLT: "res://assets/fx/status_words_en/shock.png",
	GLYPH_SHIELD: "res://assets/fx/status_words_en/barrier.png",
	GLYPH_HEAL: "res://assets/fx/status_words_en/heal.png",
	GLYPH_SWORD: "res://assets/fx/status_words_en/power.png",
	GLYPH_ENERGY: "res://assets/fx/status_words_en/energy.png",
	GLYPH_SKULL: "res://assets/fx/status_words_en/death.png",
	GLYPH_STAR: "res://assets/fx/status_words_en/stun.png",
	GLYPH_TAUNT: "res://assets/fx/status_words_en/taunt.png",
}

## 状态词文本（飘字里「状态词」部分的 i18n 唯一口）。中文 → 中文词，其余 → 英文词。
const WORD_ZH := {
	GLYPH_ICE: "冰封", GLYPH_FLAME: "燃烧", GLYPH_POISON: "中毒", GLYPH_BOLT: "感电",
	GLYPH_SHIELD: "屏障", GLYPH_HEAL: "治疗", GLYPH_SWORD: "力量", GLYPH_ENERGY: "能量",
	GLYPH_SKULL: "死亡", GLYPH_STAR: "眩晕", GLYPH_TAUNT: "嘲讽",
}
const WORD_EN := {
	GLYPH_ICE: "Frozen", GLYPH_FLAME: "Burn", GLYPH_POISON: "Poison", GLYPH_BOLT: "Shock",
	GLYPH_SHIELD: "Barrier", GLYPH_HEAL: "Heal", GLYPH_SWORD: "Power", GLYPH_ENERGY: "Energy",
	GLYPH_SKULL: "Death", GLYPH_STAR: "Stun", GLYPH_TAUNT: "Taunt",
}

## 数字 / 符号素材。
const DIGIT_TEX := {
	"0": "res://assets/fx/status_digits/digit_0.png",
	"1": "res://assets/fx/status_digits/digit_1.png",
	"2": "res://assets/fx/status_digits/digit_2.png",
	"3": "res://assets/fx/status_digits/digit_3.png",
	"4": "res://assets/fx/status_digits/digit_4.png",
	"5": "res://assets/fx/status_digits/digit_5.png",
	"6": "res://assets/fx/status_digits/digit_6.png",
	"7": "res://assets/fx/status_digits/digit_7.png",
	"8": "res://assets/fx/status_digits/digit_8.png",
	"9": "res://assets/fx/status_digits/digit_9.png",
	"+": "res://assets/fx/status_digits/sign_plus.png",
	"-": "res://assets/fx/status_digits/sign_minus.png",
}

## 素材基准高度（px）。状态词 / 数字统一缩放到这个高度，按各自宽高比定宽。
const BASE_H := 40.0
## 数字相对状态词的高度倍率（数字单字符，略矮才不抢状态词的戏）。
const DIGIT_H_SCALE := 0.82

static func _digit_h(ch: String, H: float) -> float:
	## 符号 / 数字的高度：减号是细横条（比数字矮），加号是十字（略矮于数字）。
	if ch == "-":
		return H * 0.24
	if ch == "+":
		return H * 0.72
	return H * DIGIT_H_SCALE


static var _tex_cache: Dictionary = {}


static func _is_zh() -> bool:
	return GameI18n.language() == "zh"


static func _rules() -> Array:
	return RULES if _is_zh() else RULES_EN


static func _word_tex() -> Dictionary:
	return WORD_TEX if _is_zh() else WORD_TEX_EN


static func word_of(glyph: int) -> String:
	## 状态词文本：中文版中文词，其余语言英文词（飘字 i18n 唯一口）。
	return str((WORD_EN if not _is_zh() else WORD_ZH).get(glyph, ""))


static func glyph_of(text: String) -> int:
	for rule: Array in _rules():
		if text.find(str(rule[0])) >= 0:
			return int(rule[1])
	return GLYPH_NONE


static func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


# ------------------------------------------------------------------ 解析
static func _segments(text: String) -> Array:
	## 拆成 [{kind: "word"/"digit"/"text"/"gap", ...}]。
	## 数字与 + / - 走素材拼接；没匹配到素材的中文（如「隐藏」「接下」）用 font 兜底。
	var out: Array = []
	var word := ""
	var glyph := GLYPH_NONE
	for rule: Array in _rules():
		if text.find(str(rule[0])) >= 0:
			word = str(rule[0])
			glyph = int(rule[1])
			break
	if word != "":
		var idx := text.find(word)
		if idx > 0:
			_push_chars(out, text.substr(0, idx))
		out.append({"kind": "word", "glyph": glyph, "text": word})
		_push_chars(out, text.substr(idx + word.length()))
	else:
		_push_chars(out, text)
	return out


static func _push_chars(out: Array, s: String) -> void:
	var buf := ""
	for i in range(s.length()):
		var c := s.substr(i, 1)
		if c == " " or c == "\u3000":
			if buf != "":
				out.append({"kind": "text", "text": buf})
				buf = ""
			out.append({"kind": "gap"})
		elif c == "+" or c == "-" or (c >= "0" and c <= "9"):
			if buf != "":
				out.append({"kind": "text", "text": buf})
				buf = ""
			out.append({"kind": "digit", "text": c})
		else:
			buf += c
	if buf != "":
		out.append({"kind": "text", "text": buf})


# ------------------------------------------------------------------ 绘制
static func paint(ci: CanvasItem, font: Font, center: Vector2, text: String,
		tint: Color, alpha: float, px: int) -> void:
	## 画一条状态特效文字。`center` 是屏幕空间中心；不改变换。
	if alpha <= 0.004:
		return
	var H := maxf(BASE_H, float(maxi(14, px)) * 2.4)
	var segs := _segments(text)
	var mod := Color(1.0, 1.0, 1.0, alpha)

	# 先量总宽（gap 固定 0.16H；text 用 font 按 H*0.72 号量）
	var widths: Array = []
	var total := 0.0
	for seg: Dictionary in segs:
		var w := _seg_width(ci, font, seg, H)
		widths.append(w)
		total += w

	var x := center.x - total * 0.5
	var y := center.y - H * 0.5
	for i in range(segs.size()):
		var seg: Dictionary = segs[i]
		var w := float(widths[i])
		match str(seg.get("kind", "")):
			"word":
				var tex := _tex(str(_word_tex()[int(seg["glyph"])]))
				var tw := float(tex.get_width()) * H / float(tex.get_height())
				ci.draw_texture_rect(tex, Rect2(x, y, tw, H), false, mod)
			"digit":
				var tex := _tex(str(DIGIT_TEX[str(seg["text"])]))
				var dh := _digit_h(str(seg["text"]), H)
				var tw := float(tex.get_width()) * dh / float(tex.get_height())
				ci.draw_texture_rect(tex, Rect2(x, y + (H - dh) * 0.5, tw, dh), false, mod)
			"text":
				var fs := int(round(H * 0.72))
				ci.draw_string_outline(font, Vector2(x, y + H * 0.78), str(seg["text"]),
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(fs * 0.16)),
						Color(0.05, 0.04, 0.03, alpha))
				ci.draw_string(font, Vector2(x, y + H * 0.78), str(seg["text"]),
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
						Color(tint.r, tint.g, tint.b, alpha))
			"gap":
				pass
		x += w


static func _seg_width(ci: CanvasItem, font: Font, seg: Dictionary, H: float) -> float:
	match str(seg.get("kind", "")):
		"word":
			var tex := _tex(str(_word_tex()[int(seg["glyph"])]))
			return float(tex.get_width()) * H / float(tex.get_height())
		"digit":
			var tex := _tex(str(DIGIT_TEX[str(seg["text"])]))
			var dh := _digit_h(str(seg["text"]), H)
			return float(tex.get_width()) * dh / float(tex.get_height())
		"text":
			var fs := int(round(H * 0.72))
			return font.get_string_size(str(seg["text"]),
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		"gap":
			return H * 0.16
		_:
			return 0.0
