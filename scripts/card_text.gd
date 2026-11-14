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
## R600：显示层再收两类「不该给玩家看」的东西 ——
##   * 「字段「次元」：…」与「离开手牌后恢复原价」属于字段框 / 规则层，不进效果正文；
##   * 时机关联词统一成「…时」（使用后 → 使用时），「然后 / 之后 / 后排」等语序方位词不动。
##
## 之所以**不动数据**：测试里有大量 `effect_text.contains("移动进入某个场地")` 这类
## 断言（补注本身就写在括号里），改数据会连带改坏断言；而玩家看到的只是卡面，
## 收在显示层既拿到自然语言，又让 `cards.json` 保持「带完整补注的权威版本」。

## 是否在显示层隐藏「（…）」括号补注。设 false 可一键恢复原样显示。
const UiTheme = preload("res://scripts/ui_theme.gd")

const HIDE_PARENS := true

## R187 性能：`parse` 是纯函数（输入串 → 片段数组），但每张卡每次重绘都要走一遍
## 「词句归一 + 括号剥离 + 提及扫描」。一局里输入串高度重复（卡就那两百来张），
## 缓存命中后只剩一次字典查询。返回**副本**（浅拷贝），调用方增删片段不伤缓存；
## 满 PARSE_CACHE_MAX 全清重来（极端长局也就重新填一次，无 correctness 风险）。
const PARSE_CACHE_MAX := 512
static var _parse_cache := {}

## 代码片段（`反引号`）的着色 —— 与正文的蓝色刻意分开，一眼能认出来。
## 关键字高亮色统一由 UiTheme 提供（R113）。

## 词句归一：把卡面里**对不上自然语言**的写法改正过来。**按顺序**做替换，
## 所以长词要排在短词前面（「返回手卡」必须早于「手卡」）。
## 这些修正刻意只在**显示层**做 —— `cards.json` 是权威数据、测试里有
## `effect_text.contains("返回手卡")` 这类的断言，动数据会连带改坏断言。
const PHRASE_FIXES := [
	# R600：时机统一 —— 卡面写「…时」，不写「…后」。
	# 只列**时机关联词**；「然后 / 之后 / 后排 / 退后 / 后续」是语序或方位，不动。
	["使用效果牌后", "使用效果牌时"],
	["使用效果卡后", "使用效果卡时"],
	["攻击或离场后", "攻击或离场时"],
	["战斗结束后", "战斗结束时"],
	["使用后", "使用时"],
	["登场后", "登场时"],
	["被破坏后", "被破坏时"],
	["抽牌之后", "抽牌时"],
	["沉睡归零后", "沉睡归零时"],
	["交付完成后", "交付完成时"],
	["整列打穿后", "整列打穿时"],
	["攻击敌人后", "攻击敌人时"],
	["造成第 3 次伤害后", "造成第 3 次伤害时"],
	["其他卡后", "其他卡时"],
	# R344：术语三统一（**只在显示层**，cards.json 保持原样 —— 测试按原文断言）。
	# ① 「攻击力」→「力量」：卡面数值、左栏信息、道具说明里都叫「力量」，
	#    只有数据里的旧写法还是「攻击力」，同一个数字两个名字最伤阅读。
	# ② 「HP」→「生命」：状态栏写的是 50/50 的生命，卡面却写 HP 伤害 —— 英文缩写
	#    在正文里既不统一也不好读。「HP 伤害」连读会留下多余空格，所以单独排一条。
	# ③ 「效果牌 / 技能牌」→「效果卡 / 技能卡」：卡牌种类本身叫「效果」「技能」，
	#    数据里牌 / 卡两种写法混着用（9056「效果牌」vs 9058「效果卡」）。
	["HP 伤害", "生命伤害"],
	["HP", "生命"],
	["攻击力", "力量"],
	["效果牌", "效果卡"],
	["技能牌", "技能卡"],
	["返回手卡", "收回手牌"],
	# R649：显示层术语统一补齐（数据层 cards.json 仍是权威原文，不动）。
	# 顺序敏感：弃牌复合词必须先于「牌库」，否则「弃牌库」会被拆成「弃抽牌库」。
	# 店长 2026-11-13 定案：卡组＝完整卡组（顶栏按钮）；抽牌库＝战斗中待抽
	# （右下角牌堆，UI 区域名即「抽牌库」）；弃牌区统一叫弃牌区。
	["弃牌库", "弃牌区"],
	["弃牌堆", "弃牌区"],
	["抽牌库", "抽牌堆"],
	["牌库", "抽牌堆"],
	# 收口：上面两条先把「抽牌库／牌库」挪成不含「牌库」的中间形，再统一回正名。
	# 不能删掉第一条，否则「抽牌库」会被「牌库 -> 抽牌库」拆成「抽抽牌库」。
	["抽牌堆", "抽牌库"],
	["手卡", "手牌"],
	["生命值", "生命"],
	["血量", "生命"],
	["一回合可以行动两次", "每回合可以行动两次"],
	["一回合行动两次", "每回合可以行动两次"],
	["费用变为0", "费用变为 0"],
	# 2026-11-13 区域术语纠正（R2 回正）：卡组＝完整卡组，抽牌库＝战斗待抽区。
	# 精确短语，只改「战斗内待抽区」语义；「从卡组删除 / 不可以从卡组删除」等
	# 跨战斗增删语义必须保留「卡组」，所以这里绝不能用全局「卡组 -> 抽牌库」。
	["从卡组随机抽取", "从抽牌库随机抽取"],
	["从卡组随机将一张", "从抽牌库随机将一张"],
	["从卡组选择一张", "从抽牌库选择一张"],
	["从卡组将一张", "从抽牌库将一张"],
	["从卡组把一张", "从抽牌库把一张"],
	["从卡组加入手", "从抽牌库加入手"],
	["选择卡组一张", "选择抽牌库一张"],
	["选卡组一张", "选抽牌库一张"],
	["手牌和卡组", "手牌和抽牌库"],
	["卡组里的两张卡", "抽牌库里的两张卡"],
	["加入你的卡组", "加入抽牌库"],
	["往对方卡组中", "往对方抽牌库中"],
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


## R344：两个汉字之间的空格一律压掉。
## 术语替换会留下这种空格（`敌方 HP 造成` → `敌方 生命 造成`），中文句子里夹一个
## 半角空格看着像错字；而 `伤害 -2`、`4 点` 这类**汉字↔数字/符号**之间的空格要保留。
static var _cjk_gap: RegEx = null


static func naturalize_phrases(s: String) -> String:
	## 词句归一：术语统一 + 数值与汉字之间补空格（**不改数据**，只改显示）。
	var out := s
	for pair in PHRASE_FIXES:
		out = out.replace(pair[0], pair[1])
	out = _space_units(out)
	if _cjk_gap == null:
		_cjk_gap = RegEx.new()
		_cjk_gap.compile("(?<=[\\x{4e00}-\\x{9fff}])\\s+(?=[\\x{4e00}-\\x{9fff}])")
	out = _cjk_gap.sub(out, "", true)
	return out


## R600：字段解释与「离手恢复原价」属于字段框 / 规则层，不再占卡牌效果正文。
## 只在显示层剥掉，`cards.json` 仍是权威原文（老断言仍可读原文）。
static var _field_note_re: RegEx = null
static var _leave_hand_re: RegEx = null


static func clean_meta_notes(s: String) -> String:
	var out := s
	# 「字段「次元」：打出时消失…」整句删掉 —— 字段框已经写了同一件事。
	if _field_note_re == null:
		_field_note_re = RegEx.new()
		_field_note_re.compile("字段「[^」]+」：[^。]*。?")
	out = _field_note_re.sub(out, "", true)
	# 少见的无括号写法：保留「手牌中费用 -1」这个结论，删掉离手后的状态复位解释。
	out = out.replace("费用 -1；离开手牌后恢复原费用", "手牌中费用 -1")
	out = out.replace("费用 -1；离开手卡后恢复原费用", "手牌中费用 -1")
	if _leave_hand_re == null:
		_leave_hand_re = RegEx.new()
		_leave_hand_re.compile("[，；]离开手[牌卡](?:后|即|时)?(?:恢复原价|恢复原费用)")
	out = _leave_hand_re.sub(out, "", true)
	while out.contains("  "):
		out = out.replace("  ", " ")
	for p in ["，。", "；。", "，；", "；，"]:
		while out.contains(p):
			out = out.replace(p, p.substr(1, 1))
	return out.strip_edges()


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


static func parse(md: String, hide_parens := HIDE_PARENS, swaps: Dictionary = {}) -> Array:
	## 解析极简 Markdown → 片段数组：[{text, bold, italic, code}, ...]
	## 支持 `**加粗**`、`*斜体*`、`` `代码` ``。标记不成对时按字面保留（不吞字）。
	## ⚠️ R187：返回的是缓存的**浅副本** —— 片段 Dictionary 请勿原地改写。
	var ck := GameI18n.language() + "|" + ("1" if hide_parens else "0") + "|" + md
	if not swaps.is_empty():
		ck += "|" + str(swaps)     # R702：成长卡的同一段正文有两种数 → 缓存键必须分开
	if _parse_cache.has(ck):
		return (_parse_cache[ck] as Array).duplicate()
	# R702：换数字必须在 `source()` **之后** —— 译文里的数字是硬编码的（Deal 22 damage），
	# 先换原文会让整串查不到译文。换在译文上则与语言无关（22 → 30 在哪种语言都成立）。
	var translated := _apply_number_swaps(GameI18n.source(md), swaps)
	var s: String = clean_meta_notes(naturalize_phrases(translated))
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
	# R168：把「提到的卡牌 / 道具名」切出来（自动换色 + 可悬浮）。
	# ⚠️ 切出来的片段**保留含标记的原文**（`「名字」`），所以 `naturalize()` 的输出
	#    与历史逐字一致 —— 老的断言不会因为这次改动而变；颜色只体现在绘制层。
	var parsed: Array = mark_mentions(segs)
	if _parse_cache.size() >= PARSE_CACHE_MAX:
		_parse_cache.clear()
	_parse_cache[ck] = parsed
	return parsed.duplicate()


static func _mention_seg(seg: Dictionary, token: String, name: String,
		ref: Dictionary) -> Dictionary:
	## 提及片段：`text` 保留**含标记的原文**（`「名字」`）—— 原文不动、只加一层「它是谁」。
	var d := _carry(seg, token)
	d["mention"] = {"name": name, "kind": str(ref["kind"]), "id": int(ref["id"])}
	return d


static func mark_mentions(segs: Array) -> Array:
	## 把「提到的卡牌 / 道具名」从普通文本里切出来（R168 · 机制见 `Mention`）。
	## 两种写法都认：
	##   * `「名字」` —— 事件 / 卡面文案的惯用写法；
	##   * **整段加粗**的 `**名字**` —— 历史写法（parse 已把星号吃掉，这里按整段文本判定）。
	## 对不上名字表的一律原样保留（规范 §4.10 纪律 4：宁可少标，也不标「假链接」）。
	var out: Array = []
	for seg in segs:
		var t: String = str(seg.get("text", ""))
		if t == "":
			continue
		var whole := Mention.resolve(t)
		if bool(seg.get("bold", false)) and not whole.is_empty():
			out.append(_mention_seg(seg, t, t.strip_edges(), whole))
			continue
		var buf := ""
		var i := 0
		var n := t.length()
		while i < n:
			if t[i] == "「" or t[i] == "«":
				var closer := "」" if t[i] == "「" else "»"
				var j := t.find(closer, i + 1)
				if j > 0:
					var nm := t.substr(i + 1, j - i - 1)
					var ref := Mention.resolve(nm)
					if not ref.is_empty():
						if buf != "":
							out.append(_carry(seg, buf))
							buf = ""
						out.append(_mention_seg(seg, t.substr(i, j - i + 1), nm, ref))
						i = j + 1
						continue
			buf += t[i]
			i += 1
		if buf != "":
			out.append(_carry(seg, buf))
	if out.is_empty():
		out.append(_seg("", false, false, false))
	return out


static func segments_plain(segs: Array) -> String:
	var out := ""
	for seg in segs:
		out += str(seg.get("text", ""))
	return out


static func naturalize(md: String, hide_parens := HIDE_PARENS, swaps: Dictionary = {}) -> String:
	## 纯文本降级：隐藏括号补注 + 去掉 Markdown 标记。给 Label / 单行提示用。
	return segments_plain(parse(md, hide_parens, swaps))


static func parse_card(card: CardData, hide_parens := HIDE_PARENS) -> Array:
	## R702：**卡面正文的唯一取数口**（含「本局成长」的数值换算）。
	## 渲染口一律走这里，别再直接 `parse(card.effect_text)` —— 那样成长卡会一直写基础值
	## （猎杀长到 30 了、正文还印着 22）。数值只换正文里第一个「基础值」，
	## 与 R349 的内联（`inline_damage`，本场加成）叠着用：成长后的 base 正好是内联要找的锚。
	if card == null:
		return parse("", hide_parens)
	return parse(card.effect_text, hide_parens, card.body_number_swaps())


static func naturalize_card(card: CardData, hide_parens := HIDE_PARENS) -> String:
	## `parse_card()` 的纯文本版（Label / 单行提示 / 折行工具用）。
	if card == null:
		return ""
	return naturalize(card.effect_text, hide_parens, card.body_number_swaps())


static func _apply_number_swaps(text: String, swaps: Dictionary) -> String:
	## R702：把译文里的「卡库基础值」换成本局成长后的**当前值**。
	## 每对只换**第一次**出现 —— 卡面正文里那句「造成 N 点伤害」永远是第一个数字，
	## 再往后出现的同数字（「持续 2 回合」之类）不是伤害，不能跟着改。
	## 边界判断复用 `_find_token_in`：`8` 不许命中 `80`，`2` 不许命中 `22`。
	if swaps.is_empty() or text == "":
		return text
	var out := text
	for key in swaps.keys():
		var from := str(key)
		var to := str(swaps[key])
		if from == "" or to == "" or from == to:
			continue
		var i := _find_token_in(out, from)
		if i < 0:
			continue
		out = out.substr(0, i) + to + out.substr(i + from.length())
	return out


static func to_bbcode(md: String, hide_parens := HIDE_PARENS) -> String:
	## 转 BBCode（给 RichTextLabel 用）。BBCode 的 `[` 需转义，避免文案里的方括号被当标签。
	var out := ""
	for seg in parse(md, hide_parens):
		var t: String = str(seg.get("text", "")).replace("[", "[lb]")
		var men: Dictionary = seg.get("mention", {})
		if not men.is_empty():
			t = "[color=#%s]%s[/color]" % [UiTheme.MENTION_ON_LIGHT.to_html(false), t]
		if bool(seg.get("code", false)):
			t = "[code]%s[/code]" % t
		if bool(seg.get("italic", false)):
			t = "[i]%s[/i]" % t
		if bool(seg.get("bold", false)):
			t = "[b]%s[/b]" % t
		out += t
	return out


static func _find_token_in(s: String, token: String) -> int:
	## 在**单段文本**里找 token 的首次出现，且要求左侧不是数字。
	## 为什么要判左界：`2` 会命中 `12` / `22` 里的那一位 —— 标错数字比不标更糟。
	## 右界同理（token 末位是数字时）：`8` 不许命中 `80`。
	if token == "" or s == "":
		return -1
	var from := 0
	while true:
		var i := s.find(token, from)
		if i < 0:
			return -1
		var ok := true
		if i > 0 and _is_digit(s[i - 1]):
			ok = false
		var j := i + token.length()
		if ok and _is_digit(token[token.length() - 1]) and j < s.length() and _is_digit(s[j]):
			ok = false
		if ok:
			return i
		from = i + 1
	return -1


static func _seg_colored(seg: Dictionary, text: String, col: Color, bold := false) -> Dictionary:
	## 复制一个片段并改字 / 改色（**不改原字典** —— parse 的缓存片段是共享的）。
	var d := {"text": text, "bold": bold, "italic": false, "code": false, "col": col}
	if seg.has("mention"):
		d["mention"] = seg["mention"]
	return d


static func inline_damage(segs: Array, dmg: int, base: int, expr: String,
		anchor := "") -> Array:
	## R349（用户口径）：把「现在打出多少伤害」**内联进效果正文**，不再单开一行。
	##   加成型（expr 非空）→ 把正文里的基础数字换成 `总值（算式）`，例如
	##       `造成 **10** 点伤害` → `造成 18（10＋8）点伤害`
	##     其中 18 = DMG_NOW（醒目）、（10＋8）= DMG_CALC（次色）
	##   条件档位型（expr 为空）→ 正文本来就写了两档（「则改为造成 22 点伤害」），
	##      只把**当前生效那一档**染成 DMG_NOW，正文一个字都不改。
	## ⚠️ 口径：`dmg == base` 一律不动 —— 卡面已经说清了，标出来是噪音（R262 定下的规矩）。
	## ⚠️ 找不到锚点（正文给不出确数，如蓄势由 value 实时写）→ 原样返回，宁可不标也不标错。
	if segs.is_empty() or dmg == base:
		return segs
	var token := anchor
	if token == "":
		token = str(base) if expr != "" else str(dmg)
	for idx in segs.size():
		var seg: Dictionary = segs[idx]
		var t := str(seg.get("text", ""))
		var i := _find_token_in(t, token)
		if i < 0:
			continue
		var out: Array = []
		for k in idx:
			out.append(segs[k])
		var pre := t.substr(0, i)
		if pre != "":
			# 数字与汉字之间留一个半角空格（与 `_space_units` 同一口径）。
			# 原文 `**10**点伤害` 里的星号挡住了那层判断，换成实体数字后得自己补，
			# 否则会排成「造成22」这种贴着的字。
			if _is_cjk(pre[pre.length() - 1]):
				pre += " "
			out.append(_carry(seg, pre))
		elif not out.is_empty():
			# token **独占一段**（`**10**` 被 parse 成单独一个 bold 片段）→ 空格只能
			# 补到上一个片段的末尾，否则「造成」和「22」会贴在一起。
			var last_i := out.size() - 1
			var last_t := str((out[last_i] as Dictionary).get("text", ""))
			if last_t != "" and last_t[last_t.length() - 1] != " " \
					and _is_cjk(last_t[last_t.length() - 1]):
				out[last_i] = _carry(out[last_i] as Dictionary, last_t + " ")
		out.append(_seg_colored(seg, str(dmg), UiTheme.DMG_NOW, true))
		if expr != "":
			out.append(_seg_colored(seg, "（" + expr + "）", UiTheme.DMG_CALC))
		var post := t.substr(i + token.length())
		if post != "":
			out.append(_carry(seg, post))
		for k in range(idx + 1, segs.size()):
			out.append(segs[k])
		return out
	return segs


static func _carry(seg: Dictionary, text: String) -> Dictionary:
	## ⚠️ R168：必须**原样带走 `mention`** —— 折行会把一个片段切成多段，
	##    漏带就会让「提及」在换行处突然变回普通文字（颜色与悬浮一起丢）。
	## R349：`col` 同理 —— 伤害数内联染色靠它，丢在换行处就是「同一句话两种颜色」。
	var d := {"text": text, "bold": seg.get("bold", false),
			"italic": seg.get("italic", false), "code": seg.get("code", false)}
	if seg.has("mention"):
		d["mention"] = seg["mention"]
	if seg.has("col"):
		d["col"] = seg["col"]
	return d


static func wrap_segments(font: Font, font_bold: Font, segs: Array,
		max_w: float, size: int) -> Array:
	## 折行**唯一口** = `TextWrap.wrap_rich`（R292）—— 保留了每段的 bold / italic / code /
	## mention，但断行规则与卡面文案完全同一套（禁则 / 引号成对 / 西文成词 / 空格断点）。
	## 返回：若干「行」，每行是片段数组（可直接交给 `draw_wrapped_hits`）。
	return TextWrap.wrap_rich(font, font_bold, segs, max_w, size)


static func draw_wrapped(canvas: CanvasItem, font: Font, font_bold: Font, segs: Array,
		x: float, y: float, max_w: float, size: int, line_h: float, base_col: Color,
		max_y := -1.0) -> float:
	## 逐行绘制富文本片段；返回**画完后的 y**（下一行基线）。
	## 需要「提及的命中矩形」（悬浮用）时改用 `draw_wrapped_hits()`。
	return float(draw_wrapped_hits(canvas, font, font_bold, segs, x, y, max_w, size,
			line_h, base_col, max_y).get("y", y))


static func draw_wrapped_hits(canvas: CanvasItem, font: Font, font_bold: Font, segs: Array,
		x: float, y: float, max_w: float, size: int, line_h: float, base_col: Color,
		max_y := -1.0, min_y := -1.0, bg_col := Color(0, 0, 0, 0)) -> Dictionary:
	## 同上，但额外交出**提及的命中矩形**：`{y: 基线, hits: [{rect, name, kind, id}]}`。
	## 提及自动上强调色 + 淡底 + 下划线 —— 既满足「名字要有颜色」，
	## 也是「这里能悬浮」的显式提示（规范 §4.10 的提示口径升级版）。
	## 加粗用**加粗字体 + 略深的同色系**（不换色相，避免花）；行间纵向排布与
	## 调用方的普通文本一致。max_y >= 0 时超过就画「……」并停笔。
	var fnt_b := font_bold if font_bold != null else font
	var bold_col := base_col.darkened(0.28)
	var mcol := Mention.text_color(base_col)
	if bg_col.a > 0.0:
		mcol = Mention.text_color_on(bg_col)   # R206：有真实底色就按底色挑（浅底琥珀棕）
	var lines := wrap_segments(font, font_bold, segs, max_w, size)
	var hits: Array = []
	var drawn := 0
	for line in lines:
		if max_y >= 0.0 and drawn > 0 and y + size * 0.36 > max_y:
			canvas.draw_string(font, Vector2(x, y), "……",
					HORIZONTAL_ALIGNMENT_LEFT, -1, size, base_col)
			return {"y": y, "hits": hits}
		var cx := x
		# min_y：滚动视图里「顶边之上」的行**不画**（但仍推进 y）—— 否则会糊到面板标题上。
		var skip_draw := min_y >= 0.0 and y + size * 0.36 < min_y
		for seg in line:
			var f: Font = fnt_b if bool(seg.get("bold", false)) else font
			var col: Color = base_col
			# R349：片段显式带了 col（伤害内联着色）→ 直接用它，**不再**被 code / bold
			# 的「同色系压暗」改写 —— 否则红数字加粗后会变成暗红，和不加粗的挤在一起。
			var own_col: Variant = seg.get("col")
			var own := own_col is Color
			if own:
				col = own_col as Color
			if skip_draw:
				cx += f.get_string_size(str(seg.get("text", "")),
						HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				continue
			if not own and bool(seg.get("code", false)):
				col = UiTheme.CODE_TEXT
			elif not own and bool(seg.get("bold", false)):
				col = bold_col
			var men: Dictionary = seg.get("mention", {})
			var t: String = str(seg.get("text", ""))
			var w: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if not men.is_empty():
				col = mcol
				# R206：底衬要「罩住字形墨迹」。旧值 -0.86h / 高 1.12h 把底衬中心压到基线下方
				# 约 0.3 个字号 → 高亮块和文字视觉错位（用户口径「贴纸没对准」）。
				canvas.draw_rect(Rect2(cx - 2.0, y - size * 0.96, w + 4.0, size * 1.20),
						Color(mcol.r, mcol.g, mcol.b, 0.20), true)
			canvas.draw_string(f, Vector2(cx, y), t,
					HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			if not men.is_empty():
				canvas.draw_line(Vector2(cx, y + 2.0), Vector2(cx + w, y + 2.0),
						Color(mcol.r, mcol.g, mcol.b, 0.55), 1.0)
				hits.append({
					"rect": Rect2(cx - 2.0, y - size * 0.96, w + 4.0, size * 1.20),
					"name": str(men.get("name", "")),
					"kind": str(men.get("kind", "")),
					"id": int(men.get("id", 0))})
			cx += w
		y += line_h
		drawn += 1
	return {"y": y, "hits": hits}
