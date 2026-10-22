# -*- coding: utf-8 -*-
"""R310 修订（用户口径）：① 去掉立绘；② 背景图不拉伸（等比完整显示）。
纪律：exact replace + assert count==1 + 保留原行尾。"""
import os

ROOT = r"E:/work/card_rogue"


def patch(rel, pairs):
    p = os.path.join(ROOT, rel)
    raw = open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8").replace("\r\n", "\n")
    for old, new in pairs:
        assert txt.count(old) == 1, "%s count=%d for %r" % (rel, txt.count(old), old[:70])
        txt = txt.replace(old, new)
    out = txt.replace("\n", "\r\n") if crlf else txt
    open(p, "wb").write(out.encode("utf-8"))
    print("%-28s %d 处 ok (crlf=%s)" % (rel, len(pairs), crlf))


patch("scripts/curtain_scene.gd", [
    # ① 文件头：素材登记去掉立绘那一行
    ('''##   assets/ui/curtain_plate.png       名称牌
##   assets/ui/curtain_hero_<key>.png  三个职业的立绘（key 走 UiAssets.class_key）''',
     '''##   assets/ui/curtain_plate.png       名称牌
## ⚠️ R310 修订（用户口径）：**不再使用角色立绘** —— 二层回答改成只换名称牌 + 台词，
##    立绘素材（curtain_hero_*）已从 assets/ui 撤掉，源图留在 art_src 备查。'''),

    # ② 删 _hero 变量
    ('''var _bg: TextureRect = null
var _hero: TextureRect = null''',
     '''var _bg: TextureRect = null'''),

    # ③ 背景不拉伸：等比完整显示（不裁、不放大变形）
    ('''	_bg.texture = UiAssets.get_tex("bg_curtain")
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED''',
     '''	_bg.texture = UiAssets.get_tex("bg_curtain")
	# 用户口径：**背景图不拉伸** —— 等比完整显示、居中；
	# 窗口不是 16:9 时宁可两侧/上下留暗边，也不裁掉画面、更不拉变形。
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED'''),

    # ④ 删立绘节点
    ('''	# ② 立绘（第二层起的回答态才显示）
	_hero = TextureRect.new()
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.visible = false
	add_child(_hero)
	# ③ 对话框（羊皮纸，九宫格：左右边角不拉伸、中间拉宽）''',
     '''	# ② 对话框（羊皮纸，九宫格：左右边角不拉伸、中间拉宽）'''),

    # ⑤ 删立绘布局
    ('''	# 立绘：右下，底部压在对话框上沿之内（对话框盖住它下半）
	if _hero != null and _hero.visible:
		var hh: float = minf(430.0, size.y * 0.60)
		var tex := _hero.texture
		var hw: float = hh * 0.62
		if tex != null and tex.get_height() > 0:
			hw = hh * float(tex.get_width()) / float(tex.get_height())
		_hero.size = Vector2(hw, hh)
		_hero.position = Vector2(r.end.x - hw - 26.0, r.position.y + 14.0 - hh)
''', ''),

    # ⑥ 收下后：不再叫立绘出场
    ('''	if CurtainLines.has_reply(_layer):
		# 二层起：角色立绘出场，回一句
		_show_hero()
		_say(CurtainLines.reply(_layer, _cls), CurtainLines.reply_speaker(_layer, _cls))
		_skip.text = "离开"''',
     '''	if CurtainLines.has_reply(_layer):
		# 二层起：角色回一句（R310 修订：只换名称牌，不再出立绘 —— 用户口径）
		_say(CurtainLines.reply(_layer, _cls), CurtainLines.reply_speaker(_layer, _cls))
		_skip.text = "离开"'''),

    # ⑦ 删 _show_hero()
    ('''func _show_hero() -> void:
	var key := UiAssets.class_key(CurtainLines.reply_speaker(_layer, _cls))
	var tex: Texture2D = UiAssets.get_tex("curtain_hero_" + key) if key != "" else null
	if tex == null:
		return
	_hero.texture = tex
	_hero.visible = true
	_relayout()


''', ''),
])

# smoke 的回答态检查：不再断言立绘，改断言「名称牌换成职业名 + 台词是本职业那句」
patch("scripts/test_smoke.gd", [
    ('''	var hero: Variant = s.get("_hero")
	var title: Variant = s.get("_title")
	var ok_hero: bool = hero != null and (hero as TextureRect).visible \\
			and (hero as TextureRect).texture != null
	var ok_name: bool = title != null and (title as Label).text == PlayerClass.MECH
	print("  [smoke] curtain 回答态：立绘=%s 名称牌=%s" % [ok_hero, ok_name])''',
     '''	var title: Variant = s.get("_title")
	var desc: Variant = s.get("_desc")
	var ok_name: bool = title != null and (title as Label).text == PlayerClass.MECH
	var ok_text: bool = desc != null \\
			and (desc as Label).text == CurtainLines.reply(GameLayers.LAYER_TWO, PlayerClass.MECH)
	print("  [smoke] curtain 回答态：名称牌=%s 台词=%s" % [ok_name, ok_text])'''),
])
print("ALL DONE")
