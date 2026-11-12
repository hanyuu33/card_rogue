extends SceneTree
## R620 验收：从卡组取卡（选卡模式）在电脑版「悬停卡 → 鼠标移到详情按钮 → 点详情」
## 整条路径上，描述条不许消失。弃牌区浏览模式作对照组（R618 修的就是它）。
## 直接调产品代码 PickOverlay，不复制公式。
## 用法：
##   Godot_v4.3-stable_win64_console.exe --path . --script res://tools/verify_deck_pick_hover.gd
##
## 背景：R618 修的是 `_gui_input()` 里「指到空白就把 _hover_idx 清成 -1」，
## 那段代码不分浏览 / 选卡模式；但 R618 的回归用例只覆盖了弃牌区浏览模式。
## 从卡组取卡（许愿 / 专注移除 / 淘汰 / 惊喜运单 / 合体）共用同一 PickOverlay，
## 这里把选卡模式也实测一遍，防止以后有人按 mode 分叉时把这条约束弄丢。

const PickOverlay = preload("res://scripts/pick_overlay.gd")
const CardRepo = preload("res://scripts/card_repo.gd")

var _fails := 0
var _cases := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	_cases += 1
	if not cond:
		_fails += 1
		print("FAIL: " + msg)


func _motion(ov, pos: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = pos
	ov._gui_input(mm)


func _run() -> void:
	var ov: PickOverlay = PickOverlay.new()
	root.add_child(ov)
	ov.size = Vector2(1280, 720)
	var repo := CardRepo.load_json()
	var cards: Array = []
	for id in [8003, 8005, 9002, 9069]:
		var c: CardData = repo.get_card(id)
		if c != null:
			cards.append(c)
	if cards.size() < 2:
		print("PROBE FAIL: 卡库取样不足（至少需要 2 张）")
		quit(1)
		return
	var opts: Array = []
	for i in cards.size():
		opts.append(i)
	var modes := [
		{"label": "从卡组取卡·选卡模式(许愿)", "view_only": false, "max_sel": 1,
				"confirm": "确认", "title": "许愿：从卡组选择一张卡加入手卡"},
		{"label": "弃牌区·浏览模式(对照)", "view_only": true, "max_sel": 0,
				"confirm": "关闭", "title": "弃牌区 4 张（从左到右：先弃的在前）"},
	]
	for m in modes:
		ov.open({
			"kind": "probe", "short": "探针",
			"view_only": m["view_only"], "title": m["title"], "note": "",
			"opts": opts, "cards": cards, "max_sel": m["max_sel"],
			"confirm_label": m["confirm"], "cancel_label": "",
		})
		ov._layout()
		var c0: CardData = cards[0]
		var c1: CardData = cards[1]
		var p0: Vector2 = ov._clip.position + ov._grid.position + ov._card_rect(0).get_center()
		var p1: Vector2 = ov._clip.position + ov._grid.position + ov._card_rect(1).get_center()
		var bar: Vector2 = ov._desc_bar_rect().get_center()
		var det: Vector2 = ov._desc_detail_rect().get_center()
		ov._press = {}
		# ① 悬停第 1 张卡
		_motion(ov, p0)
		_check(ov._hover_idx == 0, "%s：悬停第 1 张应记下下标 0" % m["label"])
		# ② 鼠标移到描述条（已经离开卡面）—— R618 出问题的那一步
		_motion(ov, bar)
		_check(ov._desc_card() == c0, "%s：鼠标离开卡面后描述条不许消失" % m["label"])
		# ③ 点「详情」
		ov._tap(det)
		_check(ov._detail != null and ov._detail.is_open(),
				"%s：详情按钮应能打开浮层" % m["label"])
		if ov._detail != null and ov._detail.is_open():
			_check(ov._detail._card == c0, "%s：详情应显示描述条那张卡" % m["label"])
			ov._detail.close()
		# ④ 点第 2 张卡，再把鼠标挪到详情按钮
		ov._press = {}
		ov._tap(p1)
		_check(ov._hover_idx == 1 and ov._desc_card() == c1,
				"%s：点卡后描述条应跟到新卡" % m["label"])
		_motion(ov, det)
		_check(ov._desc_card() == c1, "%s：点卡后移到详情按钮仍是同一张" % m["label"])
		ov._tap(det)
		_check(ov._detail != null and ov._detail.is_open() and ov._detail._card == c1,
				"%s：点卡后「详情」可点且卡正确" % m["label"])
		if ov._detail != null:
			ov._detail.close()
		if not bool(m["view_only"]):
			_check(ov.selected_count() == 1,
					"从卡组取卡：选卡模式点卡应选中 1 张（没被浏览模式带坏）")
		# ⑤ open / close 清零语义（R294）不能被 R618 改坏
		ov.close()
		_check(ov._hover_idx == -1, "%s：close 后悬停下标应清零" % m["label"])
		print("[%s] checked" % m["label"])
	print("DECK PICK HOVER: cases=%d fails=%d" % [_cases, _fails])
	if _fails == 0:
		print("DECK PICK HOVER PASS: 从卡组取卡没有 R618 同类问题（描述条 + 详情按钮全程可点）")
	quit(0 if _fails == 0 else 1)
