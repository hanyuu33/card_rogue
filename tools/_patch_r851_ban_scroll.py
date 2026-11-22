# -*- coding: utf-8 -*-
"""R851：禁卡表接入触屏拖动 + 细滚动条。

照搬 story_scene.gd 的 R671 方案（同一套 UiDrag / ScrollHint / 画与拖同源几何）。
exact-replace + assert count == 1，任何一个锚点对不上就整脚本失败。
"""
import io
import os

P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "ban_scene.gd")
P = os.path.abspath(P)
b = open(P, "rb").read()
assert b.count(b"\r\n") == 0, "ban_scene.gd 应为纯 LF"
s = b.decode("utf-8")


def rep(old, new, label):
    global s
    n = s.count(old)
    assert n == 1, "%s：锚点出现 %d 次（应为 1）" % (label, n)
    s = s.replace(old, new, 1)
    print("  ok:", label)


# ① 头部注释：记录 R851 的三处修复口径
rep(
    '## 出图参数：`-- --screenshot`（可加 `--demo`：在测试档案里解锁几张卡，看满额度态）\n',
    '## 出图参数：`-- --screenshot`（可加 `--demo`：在测试档案里解锁几张卡，看满额度态）\n'
    '##\n'
    '## R851（安卓拖动）：列表原来只认 `MOUSE_BUTTON_WHEEL_*`，触屏没有滚轮 → 下半截永远看不到；\n'
    '##   而且点行在 `event.pressed` 就执行 → 手指一滑的**第一帧**就把卡给禁了。\n'
    '##   现在与故事页同一套：手势口 `UiDrag.scroll_delta`（鼠标拖 / 触屏拖同一手感）、\n'
    '##   细滚动条 + 上下双箭头（画与拖同源）、点击一律「按下记意图、抬起且没拖才执行」。\n',
    "head-doc")

# ② 常量
rep(
    'const ROW_H := 40.0\nconst ROW_W := 980.0\nconst LIST_Y := 196.0\n',
    'const ROW_H := 40.0\nconst ROW_W := 980.0\nconst LIST_Y := 196.0\n'
    'const UiDrag = preload("res://scripts/ui_drag.gd")\n'
    'const ScrollHint = preload("res://scripts/ui_scroll_hint.gd")\n'
    'const BAR_W := 8.0             ## 滚动条视觉宽\n'
    'const BAR_HIT_W := 20.0        ## 拖动命中区宽（只画不给命中 = 手指点不到）\n',
    "consts")

# ③ 状态变量
rep(
    'var _last_mp := Vector2.INF\n',
    'var _last_mp := Vector2.INF\n'
    '## R851 拖动：正在拖哪条滚动条（"" / "list"）+ 按下点相对滑块顶的偏移。\n'
    'var _bar_drag := ""\n'
    'var _bar_grab_dy := 0.0\n'
    '## R851 按下位置（抬起才执行）：触屏第一下就是 pressed，按下即切禁会把滑动误判成点禁卡。\n'
    'var _press_pos := Vector2.INF\n'
    '## R851 拖动余量（像素）：按 ROW_H 折成整行，余量留到下一次（慢拖也不卡住）。\n'
    'var _drag_accum := 0.0\n'
    'var _breath_acc := 0.0\n',
    "state")

# ④ _refresh 换页签时清拖动意图（否则翻页后残留的 press 会误点新页的卡）
rep(
    '\t_cards.sort_custom(func(a: CardData, b: CardData):\n'
    '\t\tif a.rarity != b.rarity:\n'
    '\t\t\treturn a.rarity < b.rarity\n'
    '\t\treturn a.id < b.id)\n'
    '\t_scroll = 0\n'
    '\tqueue_redraw()\n',
    '\t_cards.sort_custom(func(a: CardData, b: CardData):\n'
    '\t\tif a.rarity != b.rarity:\n'
    '\t\t\treturn a.rarity < b.rarity\n'
    '\t\treturn a.id < b.id)\n'
    '\t_scroll = 0\n'
    '\t_press_pos = Vector2.INF\n'
    '\t_bar_drag = ""\n'
    '\t_drag_accum = 0.0\n'
    '\tqueue_redraw()\n',
    "refresh-reset")

# ⑤ 滚动几何 + 绘制（插在 _row_at 前）
rep(
    'func _row_at(pos: Vector2) -> int:\n',
    'func _max_scroll() -> int:\n'
    '\treturn maxi(0, _cards.size() - _max_rows())\n'
    '\n'
    '\n'
    'func _list_track() -> Rect2:\n'
    '\t## 竖排在列表右沿外侧的空白带（1280 宽时右沿 1130，右侧还剩 150）。\n'
    '\t## 窄屏放不下就贴回窗口右边缘 —— 别让滚动条跑到屏幕外。\n'
    '\tvar right := (size.x + ROW_W) * 0.5\n'
    '\tvar x := minf(right + 14.0, size.x - BAR_W - 10.0)\n'
    '\tvar top := LIST_Y\n'
    '\tvar bottom := LIST_Y + _max_rows() * ROW_H - 10.0\n'
    '\treturn Rect2(x, top, BAR_W, bottom - top)\n'
    '\n'
    '\n'
    'func _list_bar_hit() -> Rect2:\n'
    '\t## 命中区比视觉条宽：8px 的条手指根本点不准。\n'
    '\tvar t := _list_track()\n'
    '\treturn Rect2(t.position.x - (BAR_HIT_W - BAR_W) * 0.5, t.position.y - 4.0,\n'
    '\t\t\tBAR_HIT_W, t.size.y + 8.0)\n'
    '\n'
    '\n'
    'func _bar_thumb_rect(track: Rect2, ratio: float, t: float) -> Rect2:\n'
    '\t## 滑块矩形 —— **绘制与拖动共用**，分开算一次就是「看得见摸不到」。\n'
    '\t## 最小 22px：内容再长，滑块也不能细成一条线（手指点不到、眼睛看不见）。\n'
    '\tvar th := clampf(track.size.y * clampf(ratio, 0.04, 1.0), 22.0, track.size.y)\n'
    '\tvar y := track.position.y + (track.size.y - th) * clampf(t, 0.0, 1.0)\n'
    '\treturn Rect2(track.position.x, y, track.size.x, th)\n'
    '\n'
    '\n'
    'func _bar_grab_offset(track: Rect2, ratio: float, t: float, my: float) -> float:\n'
    '\t## 按下点相对滑块顶的偏移；点在轨道空白处 = 抓滑块中心（滑块直接跟过去）。\n'
    '\tvar th := _bar_thumb_rect(track, ratio, t)\n'
    '\tif my < th.position.y or my > th.end.y:\n'
    '\t\treturn th.size.y * 0.5\n'
    '\treturn my - th.position.y\n'
    '\n'
    '\n'
    'func _bar_scroll_at(track: Rect2, ratio: float, max_scroll: int, my: float) -> int:\n'
    '\t## 指针 y → 滚动量（抓取式：滑块顶始终跟着手指，拖多久都不会越拖越偏）。\n'
    '\tvar th := _bar_thumb_rect(track, ratio, 0.0)\n'
    '\tvar travel := maxf(track.size.y - th.size.y, 1.0)\n'
    '\tvar t := clampf((my - _bar_grab_dy - track.position.y) / travel, 0.0, 1.0)\n'
    '\treturn int(round(t * float(max_scroll)))\n'
    '\n'
    '\n'
    'func _draw_bar(track: Rect2, ratio: float, t: float) -> void:\n'
    '\t## 细滚动条（轨道 + 滑块），配色沿用 BRASS 系；滑块压暗一档才认得出是可拖的。\n'
    '\t## ⚠️ 只在真的溢出时调用：装得下却挂根条 = 骗玩家「下面还有」。\n'
    '\tvar lit := track.grow(7.0).has_point(get_local_mouse_position())\n'
    '\tdraw_rect(track, Color(0.30, 0.26, 0.18, 0.22), true)\n'
    '\tdraw_rect(track, Color(UiTheme.ADVENTURE_BRASS, 0.70), false, 0.8)\n'
    '\tvar thumb := _bar_thumb_rect(track, ratio, t)\n'
    '\tvar fill := UiTheme.ADVENTURE_BRASS.darkened(0.16 if lit else 0.26)\n'
    '\tdraw_rect(thumb, fill, true)\n'
    '\tdraw_rect(thumb, Color(UiTheme.ADVENTURE_BRASS_LIT, 0.92), false, 0.8)\n'
    '\n'
    '\n'
    'func _set_scroll(v: int) -> void:\n'
    '\tvar nv := clampi(v, 0, _max_scroll())\n'
    '\tif nv != _scroll:\n'
    '\t\t_scroll = nv\n'
    '\tqueue_redraw()\n'
    '\n'
    '\n'
    'func _row_at(pos: Vector2) -> int:\n',
    "scroll-geometry")

# ⑥ _gui_input 整段重写 + 拖动助手
old_input = (
    'func _gui_input(event: InputEvent) -> void:\n'
    '\tif event is InputEventMouseMotion:\n'
    '\t\t_hover = _row_at(event.position)\n'
    '\t\tqueue_redraw()\n'
    '\telif event is InputEventMouseButton and event.pressed \\\n'
    '\t\t\tand event.button_index == MOUSE_BUTTON_LEFT:\n'
    '\t\tif _back_rect().has_point(event.position):\n'
    '\t\t\tsfx.play("click")\n'
    '\t\t\t_back()\n'
    '\t\t\treturn\n'
    '\t\t# R352：职业页签\n'
    '\t\tfor ti in PlayerClass.ids().size():\n'
    '\t\t\tif _tab_rect(ti).has_point(event.position):\n'
    '\t\t\t\tvar ids := PlayerClass.ids()\n'
    '\t\t\t\tif _cls != ids[ti]:\n'
    '\t\t\t\t\t_cls = ids[ti]\n'
    '\t\t\t\t\tsfx.play("click")\n'
    '\t\t\t\t\t_refresh()\n'
    '\t\t\t\treturn\n'
    '\t\tvar hit := _row_at(event.position)\n'
    '\t\tif hit >= 0:\n'
    '\t\t\t_toggle(_cards[hit])\n'
    '\t\t\treturn\n'
    '\telif event is InputEventMouseButton and event.pressed \\\n'
    '\t\t\tand (event.button_index == MOUSE_BUTTON_WHEEL_DOWN\n'
    '\t\t\tor event.button_index == MOUSE_BUTTON_WHEEL_UP):\n'
    '\t\tvar step := 4 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -4\n'
    '\t\tvar hi := maxi(0, _cards.size() - _max_rows())\n'
    '\t\t_scroll = clampi(_scroll + step, 0, hi)\n'
    '\t\tqueue_redraw()\n'
    '\telif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:\n'
    '\t\tif _menu != null:\n'
    '\t\t\t_menu.toggle()\n'
    '\n'
    '\n'
)
new_input = (
    'func _gui_input(event: InputEvent) -> void:\n'
    '\t# R851：滚轮 / 按住内容拖 / 拖滚动条三种翻法（触屏没有滚轮）。\n'
    '\t# 点击一律「按下只记意图、抬起且没拖才执行」—— 触屏滑动的第一帧就是 pressed。\n'
    '\tif event is InputEventMouseMotion:\n'
    '\t\tvar mm := event as InputEventMouseMotion\n'
    '\t\tif _bar_drag == "list":\n'
    '\t\t\t_set_scroll(_bar_scroll_at(_list_track(),\n'
    '\t\t\t\t\tfloat(_max_rows()) / float(maxi(1, _cards.size())),\n'
    '\t\t\t\t\t_max_scroll(), mm.position.y))\n'
    '\t\t\treturn\n'
    '\t\tif _press_pos != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:\n'
    '\t\t\tif _drag_rows(mm):\n'
    '\t\t\t\t_hover = -1\n'
    '\t\t\t\treturn\n'
    '\t\t_hover = _row_at(mm.position)\n'
    '\t\tqueue_redraw()\n'
    '\t\treturn\n'
    '\tif event is InputEventMouseButton:\n'
    '\t\tvar mb := event as InputEventMouseButton\n'
    '\t\tif mb.button_index == MOUSE_BUTTON_WHEEL_UP \\\n'
    '\t\t\t\tor mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:\n'
    '\t\t\tif mb.pressed:\n'
    '\t\t\t\tvar step := 4 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -4\n'
    '\t\t\t\t_set_scroll(_scroll + step)\n'
    '\t\t\treturn\n'
    '\t\tif mb.button_index != MOUSE_BUTTON_LEFT:\n'
    '\t\t\treturn\n'
    '\t\tif mb.pressed:\n'
    '\t\t\t_press_pos = mb.position\n'
    '\t\t\t_drag_accum = 0.0\n'
    '\t\t\tif _max_scroll() > 0 and _list_bar_hit().has_point(mb.position):\n'
    '\t\t\t\t_bar_drag = "list"\n'
    '\t\t\t\t_bar_grab_dy = _bar_grab_offset(_list_track(),\n'
    '\t\t\t\t\t\tfloat(_max_rows()) / float(maxi(1, _cards.size())),\n'
    '\t\t\t\t\t\tfloat(_scroll) / float(maxi(1, _max_scroll())), mb.position.y)\n'
    '\t\t\t\t_press_pos = Vector2.INF\n'
    '\t\t\treturn\n'
    '\t\t# —— 抬起：拖动收尾，或者真的是一次点击\n'
    '\t\tvar dragged := _bar_drag == "list"\n'
    '\t\t_bar_drag = ""\n'
    '\t\tvar press := _press_pos\n'
    '\t\t_press_pos = Vector2.INF\n'
    '\t\tif dragged or press == Vector2.INF or UiDrag.drag_moved(press, mb.position):\n'
    '\t\t\tqueue_redraw()\n'
    '\t\t\treturn\n'
    '\t\tif _back_rect().has_point(press):\n'
    '\t\t\tsfx.play("click")\n'
    '\t\t\t_back()\n'
    '\t\t\treturn\n'
    '\t\t# R352：职业页签\n'
    '\t\tfor ti in PlayerClass.ids().size():\n'
    '\t\t\tif _tab_rect(ti).has_point(press):\n'
    '\t\t\t\tvar ids := PlayerClass.ids()\n'
    '\t\t\t\tif _cls != ids[ti]:\n'
    '\t\t\t\t\t_cls = ids[ti]\n'
    '\t\t\t\t\tsfx.play("click")\n'
    '\t\t\t\t\t_refresh()\n'
    '\t\t\t\treturn\n'
    '\t\tvar hit := _row_at(press)\n'
    '\t\tif hit >= 0:\n'
    '\t\t\t_toggle(_cards[hit])\n'
    '\t\t\treturn\n'
    '\t\treturn\n'
    '\tif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:\n'
    '\t\tif _menu != null:\n'
    '\t\t\t_menu.toggle()\n'
    '\n'
    '\n'
    'func _drag_rows(mm: InputEventMouseMotion) -> bool:\n'
    '\t## 按住内容拖：像素位移按 ROW_H 折成整行，余量留到下一次（不丢手感）。\n'
    '\t## ⚠️ 单位必须是 ROW_H(40) 而不是正文行距 26，否则手指走 40px 被算成 1.5 行，\n'
    '\t##    安卓上「一碰就飞」（故事页 R735 踩过同一个坑）。\n'
    '\tvar d := UiDrag.scroll_delta(mm, 0.0)\n'
    '\tif d == 0.0:\n'
    '\t\treturn false\n'
    '\t_drag_accum += d\n'
    '\tvar rows := int(_drag_accum / ROW_H)\n'
    '\tif rows != 0:\n'
    '\t\t_drag_accum -= float(rows) * ROW_H\n'
    '\t\t_set_scroll(_scroll + rows)\n'
    '\treturn true\n'
    '\n'
    '\n'
)
rep(old_input, new_input, "gui-input")

# ⑦ _process 呼吸重绘（箭头不动就不醒目；20fps 足够，别逐帧烧电量）
rep(
    '\tvar mp := get_local_mouse_position()\n'
    '\tif mp != _last_mp:\n'
    '\t\t_last_mp = mp\n'
    '\t\tqueue_redraw()\n',
    '\tvar mp := get_local_mouse_position()\n'
    '\tif mp != _last_mp:\n'
    '\t\t_last_mp = mp\n'
    '\t\tqueue_redraw()\n'
    '\t# R851：只有真的溢出才需要呼吸重绘（箭头/滑块提示）；20fps 足够。\n'
    '\tif _max_scroll() > 0:\n'
    '\t\t_breath_acc += delta\n'
    '\t\tif _breath_acc >= 0.05:\n'
    '\t\t\t_breath_acc = 0.0\n'
    '\t\t\tqueue_redraw()\n',
    "process-breath")

# ⑧ _draw 溢出时画滚动条 + 上下双箭头
rep(
    '\tif _cards.size() > _max_rows():\n'
    '\t\t# R630：底注原来画在 size.y - 12，纸面九宫格内框只到 size.y - 16、边框还有 ~12 厚\n',
    '\tif _cards.size() > _max_rows():\n'
    '\t\t# R851：右侧细滚动条 + 上下双箭头。先让玩家知道下面还有，才谈得上往下看。\n'
    '\t\tvar track := _list_track()\n'
    '\t\t_draw_bar(track, float(_max_rows()) / float(_cards.size()),\n'
    '\t\t\t\tfloat(_scroll) / float(maxi(1, _max_scroll())))\n'
    '\t\tScrollHint.draw(self, track.get_center().x, track.position.y - 4.0,\n'
    '\t\t\t\ttrack.end.y + 4.0, _scroll > 0, _scroll < _max_scroll(),\n'
    '\t\t\t\tScrollHint.breath())\n'
    '\t\t# R630：底注原来画在 size.y - 12，纸面九宫格内框只到 size.y - 16、边框还有 ~12 厚\n',
    "draw-bar")

open(P, "wb").write(s.encode("utf-8"))
print("WROTE", P, len(s.encode("utf-8")), "bytes")
