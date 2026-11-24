# -*- coding: utf-8 -*-
"""R780b：量产型赫尔墨斯 9188 同吃「每回合最多受到 20 点伤害」，
并给两张卡做「本回合已免伤」的可见表现（力场环 + 免伤图标 + 命中飘字）。

改动面：
  game_engine.gd     名单常量 / is_damage_capped / damage_cap_left / _cap 内 emit
  battle_scene.gd    _draw_damage_cap_aura / _state_slots 图标 / damage_capped 分支
  card_info_boxes.gd draw_glyph "immune"
  card_face.gd       _state_style "immune"
  cards.json + i18n  9188 卡面文本四语

⚠️ 行尾：game_engine / battle_scene / test_engine / cards.json = CRLF，其余 LF。
⚠️ cards.json 与 i18n 的 9188 都是空 effect_text —— 必须先定位 id 就近替换，
   不能全局替换 `"effect_text": "",`（几十张空文本卡）。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"


def blk(s):
    """三引号源码块 → 目标行尾（\t 已由 Python 转义成真实 tab）。"""
    return s.replace("\n", NL)


def read(p):
    return io.open(p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


fails = []


def must(s, needle, n=1, tag=""):
    c = s.count(needle)
    if c != n:
        fails.append("%s: 期望 %d 处，实际 %d 处 —— %r" % (tag, n, c, needle[:70]))
    return c


def sub(s, old, new, tag, n=1):
    must(s, old, n, tag + " 原串")
    if s.count(old) == n:
        return s.replace(old, new, n)
    return s


# ================= 1) game_engine.gd =================
p = ROOT + "scripts/game_engine.gd"
s = read(p)

s = sub(s,
        'const HERMES_DMG_CAP:= 20           # R780：每回合最多受到 20 点伤害',
        'const HERMES_DMG_CAP:= 20           # R780：每回合最多受到 20 点伤害\r\n'
        'const HERMES_MASS_ID:= 9188         # R780b：量产型赫尔墨斯（同一条上限）',
        "engine 常量")

OLD_CAP = blk('''func _cap_turn_damage(p: Placement, dmg: int) -> int:
	## R780 赫尔墨斯（9140）：「每回合最多受到 20 点伤害」。
	## 位置 = **两个扣血落地口的最后一格**（`p.health -= dmg` 的**前一格**，
	## 正义背刺倍率乘完之后）：卡面说的是「受到」，也就是**最终真正扣掉的血** ——
	## 倍率 / 减伤 / 护甲全算完才封顶，顺序反了会被 `dmg *= jb_mult` 突破上限。
	## ⚠️ 不放进 `_unit_damage_taken()`：那里只是减伤链，护甲还没扣；
	##    而且 `_op_deal_damage()` 是先过那条链、再自己扣血，两条口共用一个函数
	##    才能保证「单目标技能」和「普攻 / 多格效果」口径一致。
	## ⚠️ 累计只记**实际扣掉的血**：护甲吸收掉的、被一次性能量屏障免掉的不占额度，
	##    否则「有护甲反而更快打满上限」。
	## 回合口径 = `turn_number`（整轮；只有我方回合开始 +1）—— 换回合后 key 失配，
	## 额度自动归零，不用扫全场重置。
	if p == null or p.card == null or dmg <= 0 or p.card.id != HERMES_ID:
		return dmg
	if p.turn_dmg_key != turn_number:
		p.turn_dmg_key = turn_number
		p.turn_dmg_taken = 0
	var left:= HERMES_DMG_CAP - p.turn_dmg_taken
	if left <= 0:
		_log("%s：本回合已受满 %d 点伤害，这一下全免" % [p.card.card_name, HERMES_DMG_CAP])
		return 0
	if dmg > left:
		_log("%s：本回合伤害上限 %d 点 —— 这一下 %d 封顶到 %d" % [
			p.card.card_name, HERMES_DMG_CAP, dmg, left])
		dmg = left
	p.turn_dmg_taken += dmg
	return dmg''')

NEW_CAP = blk('''static func is_damage_capped(id: int) -> bool:
	## R780b：吃「每回合最多受到 20 点伤害」这条上限的卡 —— 赫尔墨斯 9140 + 量产型 9188。
	## **名单只此一处**：引擎两个扣血口、界面 `damage_cap_left()`、测试边界全问这里。
	## 抽成静态判据（同 `GameBuild.is_release()` 的做法）：测试可以只传 id 验边界，
	## 不用每验一张就造一个引擎；以后再加同类卡也只改这一个函数。
	return id == HERMES_ID or id == HERMES_MASS_ID


func damage_cap_left(p: Placement) -> int:
	## R780b：这张卡**本回合**还能受多少伤害；返回 -1 = 不吃这条上限（各卡通用）。
	## 0 就是界面必须表现的那个「现在打它一点也进不去」——
	## 卡面力场环 / 右上角「免伤」图标 / 命中时「免伤 N」飘字，全部读这一条，
	## 谁都不许在别处再算一次（否则「环亮着却还在掉血」这种自相矛盾迟早出现）。
	if p == null or p.card == null or not is_damage_capped(p.card.id):
		return -1
	var taken: int = p.turn_dmg_taken if p.turn_dmg_key == turn_number else 0
	return maxi(0, HERMES_DMG_CAP - taken)


func _cap_turn_damage(p: Placement, dmg: int) -> int:
	## R780 赫尔墨斯（9140）/ R780b 量产型赫尔墨斯（9188）：「每回合最多受到 20 点伤害」。
	## 位置 = **两个扣血落地口的最后一格**（`p.health -= dmg` 的**前一格**，
	## 正义背刺倍率乘完之后）：卡面说的是「受到」，也就是**最终真正扣掉的血** ——
	## 倍率 / 减伤 / 护甲全算完才封顶，顺序反了会被 `dmg *= jb_mult` 突破上限。
	## ⚠️ 不放进 `_unit_damage_taken()`：那里只是减伤链，护甲还没扣；
	##    而且 `_op_deal_damage()` 是先过那条链、再自己扣血，两条口共用一个函数
	##    才能保证「单目标技能」和「普攻 / 多格效果」口径一致。
	## ⚠️ 累计只记**实际扣掉的血**：护甲吸收掉的、被一次性能量屏障免掉的不占额度，
	##    否则「有护甲反而更快打满上限」。
	## 回合口径 = `turn_number`（整轮；只有我方回合开始 +1）—— 换回合后 key 失配，
	## 额度自动归零，不用扫全场重置。
	if p == null or p.card == null or dmg <= 0:
		return dmg
	var left:= damage_cap_left(p)
	if left < 0:
		return dmg
	if p.turn_dmg_key != turn_number:
		p.turn_dmg_key = turn_number
		p.turn_dmg_taken = 0
	# R780b：被挡掉多少也要报出去 —— 额度吃满时 `dmg` 直接归 0，`_hit_unit` 尾部
	# 那条 `fx_impact` 判的是 `if dmg > 0`，根本不会发。于是敌人一拳打上来
	# **画面一动不动**，玩家只会以为卡死了。`damage_capped` 就是「这一下被吃掉」
	# 的唯一表现来源（界面侧见 battle_scene 的同名分支）。
	var blocked:= maxi(0, dmg - left)
	if left <= 0:
		_log("%s：本回合已受满 %d 点伤害，这一下全免" % [p.card.card_name, HERMES_DMG_CAP])
	elif blocked > 0:
		_log("%s：本回合伤害上限 %d 点 —— 这一下 %d 封顶到 %d" % [
			p.card.card_name, HERMES_DMG_CAP, dmg, left])
	if blocked > 0:
		dmg = left
		action.emit("damage_capped", {"cell": _cell_of(p), "card": p.card,
				"blocked": blocked, "dealt": dmg, "cap": HERMES_DMG_CAP,
				"side": p.owner})
	p.turn_dmg_taken += dmg
	return dmg''')

s = sub(s, OLD_CAP, NEW_CAP, "engine _cap_turn_damage")

s = sub(s,
        blk('''	# ⑤b R780 赫尔墨斯：「每回合最多受到 20 点伤害」——与 `_cap_turn_damage()`
	#    **同一位置**（护甲之后 = 最终落地值）、同一份累计读数。
	#    换回合判据同引擎：`turn_dmg_key` 失配就当作 0。
	if dmg > 0 and p.card.id == HERMES_ID:
		var taken:= p.turn_dmg_taken if p.turn_dmg_key == turn_number else 0
		dmg = maxi(0, mini(dmg, HERMES_DMG_CAP - taken))'''),
        blk('''	# ⑤b R780 赫尔墨斯 / R780b 量产型赫尔墨斯：「每回合最多受到 20 点伤害」——
	#    与 `_cap_turn_damage()` **同一位置**（护甲之后 = 最终落地值），
	#    而且**同一个读数口** `damage_cap_left()`（换回合 key 失配的判定也在里面）。
	var cap_left:= damage_cap_left(p)
	if dmg > 0 and cap_left >= 0:
		dmg = maxi(0, mini(dmg, cap_left))'''),
        "engine preview 镜像")

write(p, s)


# ================= 2) battle_scene.gd =================
p = ROOT + "scripts/battle_scene.gd"
s = read(p)

s = sub(s,
        blk('''	if p.first_hit_shield:
		# 能量屏障（8033，R87）：**首次受伤免掉**的一次性护盾。'''),
        blk('''	if engine.damage_cap_left(p) == 0:
		# R780b 赫尔墨斯 9140 / 量产型赫尔墨斯 9188：本回合 20 点伤害额度已经吃满，
		# 接下来谁打它都进不去。这是**看卡面看不出来**的隐藏状态 ——
		# 卡面只写「每回合最多受到 20 点伤害」，不写「这一刻已经满了」，
		# 而玩家恰恰要靠这个决定「还要不要继续砸它」。
		# 图标由 `_state_slots()` 送进右上角圆槽，环与薄金罩在这里画。
		_draw_damage_cap_aura(center, w, h)
	if p.first_hit_shield:
		# 能量屏障（8033，R87）：**首次受伤免掉**的一次性护盾。'''),
        "battle aura 调用")

s = sub(s,
        blk('''	if p == null or p.card == null:
		return out
	if p.frozen:
		out.append({"glyph": "frozen", "label": "冰封"})'''),
        blk('''	if p == null or p.card == null:
		return out
	if engine.damage_cap_left(p) == 0:
		# R780b：本回合额度吃满 = 现在打它没用。**排在队列最前** —— 冰封 / 眩晕说的是
		# 「它不能动」，这条说的是「你打不动」，玩家下一步怎么打直接取决于它。
		out.append({"glyph": "immune", "label": "免伤"})
	if p.frozen:
		out.append({"glyph": "frozen", "label": "冰封"})'''),
        "battle state_slots")

NEW_AURA = blk('''func _draw_damage_cap_aura(center: Vector2, w: float, h: float) -> void:
	## 免伤力场（`GameEngine.damage_cap_left(p) == 0` 的唯一表现口，R780b）。
	## 赫尔墨斯 9140 / 量产型赫尔墨斯 9188 本回合的 20 点伤害额度已经吃满，
	## 接下来所有伤害都被上限吃掉、一点血也扣不动。
	## ⚠️ 形状必须和现有那几个环分开：实线圆环已被嘲讽（橙）/ 冰封（冷蓝）/ 沉睡（紫）/
	##    屏障（青）/ 可发动（黄绿）用满，虚线圆环是眩晕（金）。这里用**贴卡框的六边形** ——
	##    力场 / 结界是硬的、有棱角的语义，形状上一眼就能和「状态环」分开。
	## ⚠️ 六边形**不旋转**：按椭圆参数化转起来会变形（看起来像在抖），
	##    改成呼吸式缩放 + 顶点亮点明暗，动感够而不晃眼。
	## ⚠️ 薄金罩只压 5%→9%：再厚就把卡图糊了，玩家会看不清那到底是谁。
	var dc_t := float(_now()) / 1000.0
	var dc_pulse := (sin(dc_t * 2.6) + 1.0) * 0.5
	var dc_col := Color(1.0, 0.86, 0.42)
	draw_rect(Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h)),
			Color(dc_col.r, dc_col.g, dc_col.b, 0.05 + dc_pulse * 0.04), true)
	for k in 2:
		var hw := w * 0.5 + 3.0 + float(k) * 4.0 + dc_pulse * 1.5
		var hh := h * 0.5 + 3.0 + float(k) * 4.0 + dc_pulse * 1.5
		var pts := PackedVector2Array()
		for i in 6:
			var a: float = -PI * 0.5 + TAU * float(i) / 6.0
			pts.append(center + Vector2(cos(a) * hw, sin(a) * hh))
		pts.append(pts[0])
		var dc_a: float = (0.52 if k == 0 else 0.26) + dc_pulse * 0.28
		draw_polyline(pts, Color(dc_col.r, dc_col.g, dc_col.b, dc_a),
				2.2 if k == 0 else 1.3, true)
	# 六个顶点各点一颗小方块：呼吸时跟着亮，远看也认得出「有东西罩着」
	for i in 6:
		var a2: float = -PI * 0.5 + TAU * float(i) / 6.0
		var vp := center + Vector2(cos(a2) * (w * 0.5 + 3.0), sin(a2) * (h * 0.5 + 3.0))
		var sq := 1.8 + dc_pulse * 1.0
		draw_rect(Rect2(vp - Vector2(sq, sq), Vector2(sq, sq) * 2.0),
				Color(dc_col.r, dc_col.g, dc_col.b, 0.45 + dc_pulse * 0.45), true)


func _draw_stun_aura(center: Vector2, w: float, h: float) -> void:''')

s = sub(s, blk('''func _draw_stun_aura(center: Vector2, w: float, h: float) -> void:'''),
        NEW_AURA, "battle 新增 aura 函数")

s = sub(s,
        blk('''		"barrier":
			# 护盾**挡下**伤害的瞬间（R87）：这是玩家最需要看到的反馈 —— 护盾消失且不扣血。'''),
        blk('''		"damage_capped":
			# R780b：赫尔墨斯 / 量产型赫尔墨斯本回合的 20 点伤害额度吃掉了多少。
			# 额度满时引擎把扣血压到 0，`fx_impact` 判的是 `dmg > 0` → 不会发，
			# 于是敌人一拳打上去**画面一动不动**，看着像卡死了。这条就是补那个反馈。
			# 文案写「免伤 N」而不是「0 伤」：N 是**被上限吃掉**的量，玩家据此判断
			# 「这回合还吃不吃得动」；与能量屏障的「护盾 · 0 伤」（护盾碎掉，另一种事）区分开。
			var dcap_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var dcap_blocked := int(data.get("blocked", 0))
			if dcap_cell.x >= 0 and dcap_blocked > 0:
				var dcap_at := _hit_cue_at(dcap_cell)
				_bursts.append({"pos": _cell_center(dcap_cell), "sc": _grid_scroll,
						"start": dcap_at, "dur": 460, "col": Color("ffd863"), "big": false})
				_floaters.append({"pos": _cell_center(dcap_cell) + Vector2(0, -14),
						"sc": _grid_scroll, "text": "免伤 %d" % dcap_blocked,
						"col": Color("ffd863"), "start": dcap_at, "dur": 1400, "size": 17})
		"barrier":
			# 护盾**挡下**伤害的瞬间（R87）：这是玩家最需要看到的反馈 —— 护盾消失且不扣血。'''),
        "battle damage_capped 分支")

write(p, s)


# ================= 3) card_info_boxes.gd（LF） =================
p = ROOT + "scripts/card_info_boxes.gd"
s = io.open(p, encoding="utf-8", newline="").read()
s = sub(s,
        '		"portal":                  # 次元：两个同心菱形',
        '''		"immune":                  # 免伤（R780b）：盾形 + 外环（被力场罩住，伤害进不来）
			var impts := PackedVector2Array([
				c + Vector2(-r * 0.46, -r * 0.50), c + Vector2(r * 0.46, -r * 0.50),
				c + Vector2(r * 0.46, r * 0.04), c + Vector2(0.0, r * 0.54),
				c + Vector2(-r * 0.46, r * 0.04)])
			cv.draw_colored_polygon(impts, Color(col.r, col.g, col.b, 0.30))
			var imedge := impts.duplicate()
			imedge.append(impts[0])
			cv.draw_polyline(imedge, col, 1.3)
			cv.draw_arc(c, r * 0.92, 0.0, TAU, 24, col, 1.4)
		"portal":                  # 次元：两个同心菱形'''.replace("\n", "\n"),
        "draw_glyph immune")
io.open(p, "w", encoding="utf-8", newline="").write(s)


# ================= 4) card_face.gd（LF） =================
p = ROOT + "scripts/card_face.gd"
s = io.open(p, encoding="utf-8", newline="").read()
s = sub(s,
        '''		"taunt":
			return [Color(0.20, 0.11, 0.02), Color(1.0, 0.84, 0.40)]''',
        '''		"taunt":
			return [Color(0.20, 0.11, 0.02), Color(1.0, 0.84, 0.40)]
		"immune":
			return [Color(0.24, 0.17, 0.03), Color(1.0, 0.90, 0.56)]''',
        "state_style immune")
io.open(p, "w", encoding="utf-8", newline="").write(s)


# ================= 5) cards.json 9188 =================
p = ROOT + "cards.json"
s = read(p)
anchor = '"id": 9188'
i = s.find(anchor)
assert i > 0, "cards.json 找不到 id 9188"
seg = s[i:i + 700]
old_empty = '"effect_text": "",'
must(seg, old_empty, 1, "cards.json 9188 空 effect_text")
T9188_ZH = "每回合最多受到 20 点伤害。"
s = s[:i] + seg.replace(old_empty, '"effect_text": "%s",' % T9188_ZH, 1) + s[i + 700:]
must(s, T9188_ZH, 1, "cards.json 9188 写入")
write(p, s)


# ================= 6) i18n 四语 9188 =================
T9188 = {
    "zh": T9188_ZH,
    "en": "Takes at most 20 damage each turn.",
    "ja": "1ターンに受けるダメージは最大20。",
    "es": "No puede recibir más de 20 de daño por turno.",
}
for lang in ("zh_canonical", "cards_en", "cards_ja", "cards_es"):
    p = ROOT + "i18n/%s.json" % lang
    s = io.open(p, encoding="utf-8", newline="").read()
    idx = s.find('"9188"')
    assert idx > 0, "%s 找不到 9188" % lang
    nxt = s.find('"9189"', idx)
    end = nxt if nxt > idx else idx + 400
    seg = s[idx:end]
    must(seg, '"effect_text": ""', 1, "%s 9188 空串" % lang)
    seg2 = seg.replace('"effect_text": ""', '"effect_text": "%s"' % T9188[lang], 1)
    s = s[:idx] + seg2 + s[end:]
    must(s, T9188[lang], 1, "%s 9188 写入" % lang)
    io.open(p, "w", encoding="utf-8", newline="").write(s)


# ================= 回读校验 =================
import json
d = json.load(io.open(ROOT + "cards.json", encoding="utf-8"))["cards"]
idx = {c["id"]: c for c in d}
if idx[9188]["effect_text"] != T9188_ZH:
    fails.append("回读：cards.json 9188 effect_text = %r" % idx[9188]["effect_text"])
if idx[9140]["effect_text"] != "每过3回合，行动次数+1。每回合最多受到 20 点伤害。":
    fails.append("回读：9140 文本被改动了 %r" % idx[9140]["effect_text"])
for lang in ("zh_canonical", "cards_en", "cards_ja", "cards_es"):
    pool = json.load(io.open(ROOT + "i18n/%s.json" % lang, encoding="utf-8"))
    pool = pool.get("cards", pool)
    if pool["9188"]["effect_text"] != T9188[{"zh_canonical": "zh"}.get(lang, lang)]:
        fails.append("回读：%s 9188 = %r" % (lang, pool["9188"]["effect_text"]))

ge = io.open(ROOT + "scripts/game_engine.gd", encoding="utf-8", newline="").read()
for needle in ("const HERMES_MASS_ID:= 9188", "static func is_damage_capped",
               "func damage_cap_left", 'action.emit("damage_capped"',
               "var cap_left:= damage_cap_left(p)"):
    if ge.count(needle) < 1:
        fails.append("回读 game_engine 缺 %r" % needle)
if 'p.card.id != HERMES_ID' in ge:
    fails.append("回读：engine 里还有旧的 9140 硬判定")
if 'p.card.id == HERMES_ID' in ge:
    fails.append("回读：preview 里还有旧的 9140 硬判定")

bs = io.open(ROOT + "scripts/battle_scene.gd", encoding="utf-8", newline="").read()
for needle in ("_draw_damage_cap_aura(center, w, h)", "func _draw_damage_cap_aura",
               '"damage_capped":', '"glyph": "immune"'):
    if bs.count(needle) < 1:
        fails.append("回读 battle_scene 缺 %r" % needle)

if fails:
    print("\n".join(fails))
    sys.exit("补丁未全部命中")
print("ALL_OK")
