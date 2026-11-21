"""R848 补丁：图鉴正文自绘 + 试玩版图鉴口径与发布版一致。

改两处 CRLF 文件（Edit 会把整篇转 LF，必须走 python exact-replace）：
  1. scripts/test_smoke.gd  `_check_gallery_text_bounds`：判据从 Label 换成自绘口径；
  2. scripts/test_engine.gd R753 源码锁改 `is_published()`，并补 R848 判据断言。
"""
import io
import os
import sys

ROOT = "E:/work/card_rogue"
SMOKE = os.path.join(ROOT, "scripts", "test_smoke.gd")
ENG = os.path.join(ROOT, "scripts", "test_engine.gd")


def read(p):
    # 统一成 LF 再比对：文件本身是 CRLF，旧的 old 串是 LF 写法。
    with io.open(p, "r", encoding="utf-8", newline="") as f:
        return f.read().replace("\r\n", "\n")


def write_crlf(p, s):
    s = s.replace("\r\n", "\n").replace("\n", "\r\n")
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


def sub1(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        print("FAIL %s: count=%d" % (tag, n))
        sys.exit(1)
    return s.replace(old, new)


# ---------------------------------------------------------------- test_smoke.gd
smoke = read(SMOKE)

OLD_SMOKE = """func _check_gallery_text_bounds(scene: Variant) -> void:
	## R717（用户报「复制术等许多卡描述换行溢出、压住边框」）：两条根因都钉在真场景。
	##   ① 固定框会被前一张卡 / 前一种语言撑宽，换卡必须重新收回到 236×230；
	##   ② Font 多行度量不含 Label 的 line_spacing，缩字必须把它算进去，否则正文向下长出去。
	## 不只验复制术：玩家卡全量 × 四语言都走真实 `_refresh_detail()`，再量同一份正文。
	var copy: CardData = null
	var checked := 0
	for lang in ["zh", "en", "ja", "es"]:
		GameSettings.language = lang
		for c in scene._all:
			if c.group != "player":
				continue
			ProfileData.mark_card_seen(c.id)
			if c.id == 9165:
				copy = c
			scene._selected = c
			scene._refresh_detail()
			var lb: Label = scene.detail_text
			var box := Vector2(236.0, 230.0)
			if lb.size != box:
				GameSettings.language = "zh"
				_smoke_fail("R717 图鉴正文框被撑开：lang=%s id=%d size=%s，应为 %s"
						% [lang, c.id, str(lb.size), str(box)])
				return
			var fs := lb.get_theme_font_size("font_size")
			var spacing := float(lb.get_theme_constant("line_spacing"))
			var need := UiTheme.text_need(lb.get_theme_font("font"), lb.text,
					box.x, fs, true, spacing)
			if need.x > box.x + 0.5 or need.y > box.y + 0.5:
				GameSettings.language = "zh"
				_smoke_fail("R717 图鉴正文仍越界：lang=%s id=%d need=%s > %s（fs=%d）"
						% [lang, c.id, str(need), str(box), fs])
				return
			checked += 1
	GameSettings.language = "zh"
	if copy == null:
		_smoke_fail("R717：卡库里找不到复制术 9165")
		return
	# 人工制造截图同形的「上一张卡把 Label 撑到 520px」状态，再切回复制术。
	# 旧实现会沿用 520px 折成两行并穿出右框；现在必须当次收回 236px。
	scene._selected = copy
	scene.detail_text.size = Vector2(520.0, 230.0)
	scene._refresh_detail()
	if scene.detail_text.size != Vector2(236.0, 230.0):
		_smoke_fail("R717 复制术沿用了残留宽度：%s" % str(scene.detail_text.size))
		return
	print("SMOKE OK R717 图鉴详情：%d 个卡牌×语言正文均在安全框内；复制术残留宽度收回" % checked)
"""

NEW_SMOKE = """func _check_gallery_text_bounds(scene: Variant) -> void:
	## R717 / R848：图鉴右栏正文「全卡 × 四语言」都走真实 `_refresh_detail()`，再按**自绘口径**丈量。
	## R848 把正文从 Label 换成自绘 —— Label 的行高随字号 / 平台跳变（实测 16→25、12→36、
	## 10→30、9→27），偏大时 230px 只画得下四五行、余下被 `clip_text` 无声削掉，
	## 正是用户报的「图鉴看不全」。现在判据直接读排版结果：每行宽 ≤ BODY_W、整块高 ≤ BODY_H。
	## ⚠️ 这里**不再只测玩家卡**：用户截图那张 9260 常数测量员是敌人卡，
	##    原来那句 `if c.group != "player": continue` 恰好把它漏掉了。
	var gs = preload("res://scripts/gallery_scene.gd")
	var box_w := float(gs.BODY_W)
	var box_h := float(gs.BODY_H)
	var lh_scale := float(gs.BODY_LINE_SCALE)
	var fs_min := int(gs.BODY_FS_MIN)
	var fs_max := int(gs.BODY_FS_MAX)
	var copy: CardData = null
	var checked := 0
	for lang in ["zh", "en", "ja", "es"]:
		GameSettings.language = lang
		for c in scene._all:
			ProfileData.mark_card_seen(c.id)
			if c.id == 9165:
				copy = c
			scene._selected = c
			scene._refresh_detail()
			var lines: Array = scene._body_lines
			var fs := int(scene._body_fs)
			if fs < fs_min or fs > fs_max:
				GameSettings.language = "zh"
				_smoke_fail("R848 图鉴正文字号越界：lang=%s id=%d fs=%d" % [lang, c.id, fs])
				return
			var need_h := float(lines.size()) * float(fs) * lh_scale
			if need_h > box_h + 0.5:
				GameSettings.language = "zh"
				_smoke_fail("R848 图鉴正文仍然放不下：lang=%s id=%d 需 %.1fpx > %.1fpx（fs=%d，%d 行）"
						% [lang, c.id, need_h, box_h, fs, lines.size()])
				return
			for ln in lines:
				var lw := scene._font.get_string_size(str(ln),
						HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if lw > box_w + 0.5:
					GameSettings.language = "zh"
					_smoke_fail("R848 图鉴正文行宽越界：lang=%s id=%d「%s」= %.1fpx > %.1fpx"
							% [lang, c.id, str(ln), lw, box_w])
					return
			checked += 1
	GameSettings.language = "zh"
	if copy == null:
		_smoke_fail("R717：卡库里找不到复制术 9165")
		return
	# 换卡必须**整份替换**排版（不许沿用上一张卡的行数 / 字号）：
	# 切到全库最长的那张，再切回复制术，排版要回到复制术自己的值。
	scene._selected = copy
	scene._refresh_detail()
	var copy_fs := int(scene._body_fs)
	var copy_n := scene._body_lines.size()
	var longest: CardData = null
	var longest_n := 0
	for c in scene._all:
		scene._selected = c
		scene._refresh_detail()
		if scene._body_lines.size() > longest_n:
			longest_n = scene._body_lines.size()
			longest = c
	if longest != null:
		scene._selected = copy
		scene._refresh_detail()
		if int(scene._body_fs) != copy_fs or scene._body_lines.size() != copy_n:
			_smoke_fail("R848 图鉴正文沿用上一张卡的排版（复制术 fs=%d / %d 行，最长那张 %s 是 %d 行）"
					% [copy_fs, copy_n, str(longest.id), longest_n])
			return
	print("SMOKE OK R848 图鉴详情：%d 个卡牌×语言正文按自绘口径全落在 %.0fx%.0f 框内；换卡整份替换"
			% [checked, box_w, box_h])
"""

smoke = sub1(smoke, OLD_SMOKE, NEW_SMOKE, "smoke._check_gallery_text_bounds")
write_crlf(SMOKE, smoke)
print("OK test_smoke.gd")

# ---------------------------------------------------------------- test_engine.gd
eng = read(ENG)

OLD_LOCK = """	check_src(r753_gs_src.contains("static func gallery_locked(")
			and r753_gs_src.contains("return gallery_locked(c, GameBuild.is_release())"),
			"R753 源码锁：`_locked()` 走 `gallery_locked(c, GameBuild.is_release())`")
"""
NEW_LOCK = """	check_src(r753_gs_src.contains("static func gallery_locked(")
			and r753_gs_src.contains("return gallery_locked(c, GameBuild.is_published())"),
			"R753/R848 源码锁：`_locked()` 走 `gallery_locked(c, GameBuild.is_published())`（试玩版同口径）")

	# ---- R848（店长口径「试玩版在图鉴机制上要和发布版一致」）----
	# 判据：`is_published()` = 发布版 ∪ 试玩版；图鉴的收录 / 锁 / 收集分母都挂在它上面。
	var r848_gs = preload("res://scripts/gallery_scene.gd")
	GameBuild.set_test_demo(1)
	check(GameBuild.is_published() and not GameBuild.is_release(),
			"R848 判据：试玩版算「面向玩家的成品包」，且不冒充发布版")
	check(not r848_gs.gallery_visible(r642_new_card, GameBuild.is_published()),
			"R848 判据：试玩版图鉴同样「没见过就没有条目」（与发布版一致）")
	GameBuild.set_test_demo(-1)
	check(not GameBuild.is_published(),
			"R848 复位：测试版不是成品包（图鉴全解锁）")
"""
eng = sub1(eng, OLD_LOCK, NEW_LOCK, "engine.R753 源码锁")
write_crlf(ENG, eng)
print("OK test_engine.gd")
