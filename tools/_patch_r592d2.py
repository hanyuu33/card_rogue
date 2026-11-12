# -*- coding: utf-8 -*-
"""R592d-2：恢复「交换」的卡面图标。

用户口径（2026-11-12）：
  「我意识到了交换图标也是有用的，短暂、次元、交换都需要手卡上显示。」
  · 短暂 = 字段「幻影」（AFFIX_DEFS 里它在卡面上的描述就是「短暂复制」）—— 本来就显示；
  · 次元 —— 本来就显示；
  · 交换 —— R592c 被 `badge: false` 关掉了，现在恢复。
`badge` 开关本身保留（`affix_badge_on_card()` 仍是唯一判据），只是当前**没有字段**用它。
"""
import io

def patch(path, pairs, crlf):
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        src = f.read()
    for old, new in pairs:
        o = old.replace("\n", "\r\n") if crlf else old
        n = new.replace("\n", "\r\n") if crlf else new
        assert src.count(o) == 1, "anchor count=%d %r" % (src.count(o), o[:60])
        src = src.replace(o, n)
    if crlf:
        src = src.replace("\r\n", "\n").replace("\n", "\r\n")
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(src)
    with io.open(path, "r", encoding="utf-8", newline="") as f:
        raw = f.read()
    bare = raw.replace("\r\n", "").count("\n") if crlf else raw.count("\r\n")
    assert bare == 0, "line-ending broken in %s" % path
    print("[ok]", path)


# ── ① card_data.gd：交换恢复图标 ──────────────────────────────────────────
patch("scripts/card_data.gd", [
(
"""	"交换": {"label": "交换", "desc": "可放置在已有友方单位的格子上，原本在那个格子上的友方单位返回手卡。", "glyph": "swap", "on_board": false, "badge": false, "bg": "0a2a2e", "fg": "5fe0d0"},""",
"""	# R592d：**恢复卡面图标**（店长口径「交换图标也是有用的，短暂、次元、交换都需要手卡上显示」）。
	# R592c 曾把它关掉（理由是「放下之前怎么放，图标给不出这个信息」），现按店长口径撤销。
	"交换": {"label": "交换", "desc": "可放置在已有友方单位的格子上，原本在那个格子上的友方单位返回手卡。", "glyph": "swap", "on_board": false, "bg": "0a2a2e", "fg": "5fe0d0"},"""),
(
"""static func affix_badge_on_card(name: String) -> bool:
	## R592c：这个字段**要不要在卡面圆形槽位里出图**（默认要）。
	## `false` 的只有「交换」—— 它描述的是「放下之前怎么放」，卡已经在你手里时
	## 一个图标给不出这个信息，玩家真正需要的是「能盖在已有单位上」的提示，
	## 所以卡面不画它（店长口径）。字段本身、`affix_line()` 文本、引擎判定全部照旧。""",
"""static func affix_badge_on_card(name: String) -> bool:
	## 这个字段**要不要在卡面圆形槽位里出图**（默认要）。
	## ⚠️ R592d：**当前没有任何字段写 `badge: false`** —— R592c 曾用它关掉「交换」，
	## 店长随后改口径「交换图标也是有用的，短暂、次元、交换都需要手卡上显示」，
	## 于是撤销。这个开关留着：将来出现「图标反而误导」的字段还能一键关掉，
	## 而且它是**唯一判据**（`CardFace.affix_badge_queue()` 只读它，不写字段白名单）。"""),
], crlf=True)

# ── ② card_face.gd：队列注释 ──────────────────────────────────────────────
patch("scripts/card_face.gd", [
(
"""	## 这张卡**要轮流显示**的字段（中文名，按 `affixes` 顺序）。两层过滤：
	##   · `CardData.affix_badge_on_card()` 为 false 的字段**卡面一律不出图标**
	##     （R592c 交换 —— 它只管「放下之前怎么放」，图标给不出这个信息）；""",
"""	## 这张卡**要轮流显示**的字段（中文名，按 `affixes` 顺序）。两层过滤：
	##   · `CardData.affix_badge_on_card()` 为 false 的字段**卡面一律不出图标**
	##     （R592d 起没有字段用它 —— 交换已按店长口径恢复显示）；"""),
], crlf=False)

# ── ③ test_engine.gd：三条锁改口径 ───────────────────────────────────────
patch("scripts/test_engine.gd", [
(
"""	var on_hand := CardFace.affix_badge_queue(board_c, false)
	var on_board_q := CardFace.affix_badge_queue(board_c, true)
	check(on_hand.size() == 1 and on_hand[0] == "嘲讽",
			"R592c：交换在卡面上不出图标（手牌队列 %s）" % str(on_hand))""",
"""	var on_hand := CardFace.affix_badge_queue(board_c, false)
	var on_board_q := CardFace.affix_badge_queue(board_c, true)
	# R592d：交换的手牌图标**恢复显示**（店长口径「交换图标也是有用的」）
	check(on_hand.size() == 2 and on_hand.has("交换") and on_hand.has("嘲讽"),
			"R592d：交换在手卡上出图标（手牌队列 %s）" % str(on_hand))"""),
(
"""	# 只有交换的卡 → 整个槽位不出现（不留一个空圆）
	var swap_only := CardData.from_dict(base.to_dict())
	swap_only.affixes = ["交换"]
	check(CardFace.affix_badge_rect(swap_only, box_rect).size == Vector2.ZERO,
			"R592c：只有交换的卡不画槽位")""",
"""	# 只有交换的卡 → 手卡上照样有槽位；只是上场后被 `on_board` 滤掉
	var swap_only := CardData.from_dict(base.to_dict())
	swap_only.affixes = ["交换"]
	check(CardFace.affix_badge_rect(swap_only, box_rect).size != Vector2.ZERO,
			"R592d：只有交换的卡手卡上也画槽位")
	check(CardFace.affix_badge_rect(swap_only, box_rect, true).size == Vector2.ZERO,
			"R592b：只有交换的卡上场后槽位消失（on_board 口径未变）")"""),
(
"""	# R592c 数据锁：卡面不出图标由 AFFIX_DEFS.badge 控制，当前只挡「交换」
	var no_badge: Array[String] = []
	for na: String in CardData.AFFIX_DEFS.keys():
		if not CardData.affix_badge_on_card(na):
			no_badge.append(na)
	check(no_badge == ["交换"],
			"R592c：卡面不出图标的字段只有交换（实际 %s）" % str(no_badge))""",
"""	# R592d 数据锁：`AFFIX_DEFS.badge` 开关仍在，但当前**没有字段**关掉卡面图标
	var no_badge: Array[String] = []
	for na: String in CardData.AFFIX_DEFS.keys():
		if not CardData.affix_badge_on_card(na):
			no_badge.append(na)
	check(no_badge.is_empty(),
			"R592d：没有字段关闭卡面图标（实际 %s）" % str(no_badge))
	# 三个「只在出手那一刻说话」的字段都必须能在手卡上看到图标
	var must_show: Array[String] = ["交换", "幻影", "次元"]
	var shown := CardData.from_dict(base.to_dict())
	shown.affixes = must_show.duplicate()
	var shown_q := CardFace.affix_badge_queue(shown, false)
	check(shown_q.size() == 3,
			"R592d：交换 / 幻影(短暂) / 次元 三个字段手卡上都有图标（实际 %s）" % str(shown_q))"""),
], crlf=True)
print("done")
