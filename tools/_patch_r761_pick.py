# -*- coding: utf-8 -*-
"""R761 补丁 7/9：class_pick_scene.gd —— 吟游诗人在头像行**上方**多出一枚槽位。

为什么在正上方而不是排进头像行：头像行加第四枚会顶到右侧「随机种子」面板
（行宽 394 → 498，可用空档只有 ~228），而森林精魄头像正上方那块是空的 CG 背景。
槽位只在 `PlayerClass.bard_enabled()` 为真时绘制 / 可点，默认版本**一个像素都不多**。
"""
import io

p = r"E:\work\card_rogue\scripts\class_pick_scene.gd"
with io.open(p, "rb") as f:
    b = f.read()


def rep(old, new, n=1):
    global b
    o = old.encode("utf-8")
    c = b.count(o)
    assert c == n, "命中 %d 次（期望 %d）：%r" % (c, n, old[:70])
    b = b.replace(o, new.encode("utf-8"))


# ---- 1. 字段 ----
rep('''var _hover := -1              # 悬停的头像下标
''', '''var _hover := -1              # 悬停的头像下标
## R761：隐藏职业「吟游诗人」是否被选中。它**不在** `PlayerClass.ids()` 里，
## 所以不能用 `_selected` 表示；两者互斥（点头像清它、点它清 `_selected`）。
var _bard_sel := false
var _bard_hover := false      # 上方那枚槽位的悬停态（自绘，得自己跟）
''')

rep('''static var last_selected := 0
''', '''static var last_selected := 0
## R761：上次选的是不是吟游诗人（从禁卡表回来要恢复成同一枚）。
static var last_bard := false
''')

# ---- 2. 几何：正上方那一枚 ----
rep('''func _rand_rect() -> Rect2:
''', '''func _bard_rect() -> Rect2:
	## R761：吟游诗人的槽位 = **森林精魄头像正上方**，同尺寸同名牌。
	## 纵向：槽底与 firstName 的名字条之间留 4px；横向：与 av0 严格同 x。
	var r := _av_rect(0)
	return Rect2(r.position.x, r.position.y - AV - 56.0, AV, AV)


func _current_cid() -> String:
	## 此刻「在选谁」的唯一口（三职业走 `_selected`，吟游诗人走 `_bard_sel`）。
	if _bard_sel and PlayerClass.bard_enabled():
		return PlayerClass.BARD
	return PlayerClass.ids()[clampi(_selected, 0, PlayerClass.ids().size() - 1)]


func _rand_rect() -> Rect2:
''')

# ---- 3. 绘制：CG 与面板按 _current_cid；槽位跟头像一起画 ----
rep('''	else:
		var cid := PlayerClass.ids()[_selected]
		var cg := UiAssets.class_cg(cid)
''', '''	else:
		var cid := _current_cid()
		var cg := UiAssets.class_cg(cid)
''')

rep('''	for i in PlayerClass.ids().size():
		_draw_avatar(i)
	_draw_rand_button()
''', '''	for i in PlayerClass.ids().size():
		_draw_avatar(i)
	_draw_bard_slot()
	_draw_rand_button()
''')

# ---- 4. 头像选中态 ----
rep('''	var sel := i == _selected and not _rand_pending   # R545：盲选态不标任何头像
''', '''	var sel := i == _selected and not _rand_pending and not _bard_sel   # R545/R761
''')

# ---- 5. 槽位绘制 ----
rep('''func _draw_rand_button() -> void:
''', '''func _draw_bard_slot() -> void:
	## R761：吟游诗人的槽位（隐藏职业）。**开关关着时整支不执行** ——
	## 玩家看到的选人界面与以前逐像素相同。
	if not PlayerClass.bard_enabled():
		return
	var cid := PlayerClass.BARD
	var r := _bard_rect()
	var sel := _bard_sel and not _rand_pending
	var cc: Color = UiTheme.class_color(cid)
	UiTheme.draw_info_card(self, r)
	var tex := UiAssets.class_avatar(cid)
	if tex != null:
		var fr := CardFace.fit_rect(tex.get_size(), r.grow(-6.0))
		draw_texture_rect(tex, fr, false)
	else:
		# 缺图回退：职业圆徽（再缺则只留框 + 名字）
		var badge := UiAssets.class_badge(cid)
		if badge != null:
			draw_texture_rect(badge, r.grow(-8.0), false)
	draw_rect(r, cc if sel else Color(1, 1, 1, 0.25), false, 4.0 if sel else 2.0)
	if _bard_hover and not sel:
		draw_rect(r.grow(3.0), Color(1, 1, 1, 0.55), false, 2.0)
	# 名牌与头像行同一套尺寸 / 字体（写在槽位**下面**，正好落在 av0 上方那条缝里）
	UiTheme.draw_info_card(self, Rect2(r.position.x - 4, r.end.y + 4, r.size.x + 8, 48))
	draw_string(_font_bold, Vector2(r.position.x, r.end.y + 24.0), PlayerClass.name_of(cid),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_LABEL, UiTheme.PAGE_INK)
	var hp_txt := GameI18n.ui("shell", "CLASS_PICK_HP", "生命 %d") % PlayerClass.base_hp_of(cid)
	draw_string(_font, Vector2(r.position.x, r.end.y + 44.0), hp_txt,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, UiTheme.FS_CAPTION,
			UiTheme.class_color(cid).lightened(0.35))


func _draw_rand_button() -> void:
''')

# ---- 6. 难度上限 / 当前职业 ----
rep('''	if _rand_pending:
		return ids[clampi(_rand_pick, 0, ids.size() - 1)]
	return ids[clampi(_selected, 0, ids.size() - 1)]
''', '''	if _rand_pending:
		return ids[clampi(_rand_pick, 0, ids.size() - 1)]
	return _current_cid()
''')

# ---- 7. 输入：命中 + 互斥 ----
rep('''		var rh := _rand_rect().grow(4.0).has_point(event.position)
		if rh != _rand_hover:
			_rand_hover = rh
			queue_redraw()
''', '''		var rh := _rand_rect().grow(4.0).has_point(event.position)
		if rh != _rand_hover:
			_rand_hover = rh
			queue_redraw()
		# R761：吟游诗人槽位（开关关着时恒为 false，不参与命中）
		var bh := PlayerClass.bard_enabled() and _bard_rect().grow(5.0).has_point(event.position)
		if bh != _bard_hover:
			_bard_hover = bh
			queue_redraw()
''')

rep('''			if _confirm_rect().has_point(pos):
				_choose(PlayerClass.ids()[_selected])
				return
''', '''			if _confirm_rect().has_point(pos):
				_choose(_current_cid())
				return
''')

rep('''				_selected = i
				last_selected = i
				_rand_pending = false   # R545：点具体角色 = 取消盲选
''', '''				_selected = i
				last_selected = i
				_bard_sel = false        # R761：点具体头像 = 取消吟游诗人
				last_bard = false
				_rand_pending = false   # R545：点具体角色 = 取消盲选
''')

rep('''		# R519b：「随机」钮 —— 放在头像循环之后判，两者不重叠所以顺序无所谓，
''', '''		# R761：吟游诗人槽位（在森林精魄头像正上方，与头像行不重叠）
		if PlayerClass.bard_enabled() and _bard_rect().grow(5.0).has_point(pos):
			_bard_sel = true
			last_bard = true
			_rand_pending = false
			_diff_set_to(RunState.difficulty)   # 换职业后难度可能超上限 → 当场压回
			sfx.play("click")
			queue_redraw()
			return
		# R519b：「随机」钮 —— 放在头像循环之后判，两者不重叠所以顺序无所谓，
''')

# ---- 8. 恢复上次选择 ----
rep('''	if uargs.find("--sel") < 0:
		_selected = clampi(last_selected, 0, PlayerClass.ids().size() - 1)
''', '''	if uargs.find("--sel") < 0:
		_selected = clampi(last_selected, 0, PlayerClass.ids().size() - 1)
		# R761：上次玩的是吟游诗人 → 恢复成同一枚（开关关着就退回普通头像）
		_bard_sel = last_bard and PlayerClass.bard_enabled()
''')

# ---- 9. 盲选揭晓 ----
rep('''	_selected = clampi(_rand_pick, 0, PlayerClass.ids().size() - 1)
	last_selected = _selected
''', '''	_selected = clampi(_rand_pick, 0, PlayerClass.ids().size() - 1)
	last_selected = _selected
	_bard_sel = false
	last_bard = false
''')

with io.open(p, "wb") as f:
    f.write(b)
print("class_pick_scene.gd OK")
