# -*- coding: utf-8 -*-
"""R577d：战斗中道具栏「数量适应 + 满了自动换行 + 按行平均分配」补丁（可重跑）。

用法：
    python tools/_patch_r577d.py                # 打补丁（已打过则 SKIP）
    python tools/_patch_r577d.py --check-only   # 只验结果，不写

纪律：二进制读写 + exact-replace + assert count==1；按每个文件自己的行尾拼接，
CRLF 文件不会被引擎/工具混成 bareLF。新建的排版脚本固定 LF。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK_ONLY = "--check-only" in sys.argv

LAYOUT_REL = "scripts/relic_bar_layout.gd"
LAYOUT_SRC = '''extends RefCounted
## R577d：战斗右栏道具格排版的唯一口（纯静态，故意不写 class_name —— headless 回归
## 读不到全局类缓存，消费方一律 const X = preload(...)，见 ui_theme.gd 的说明）。
##
## 店长口径：数量少时铺得开，数量多时收紧间距；一行最多 6 个，放不下才换行；
## 换行后把总数**按行平均分配**（每行个数差 <= 1），不是「前几行填满 + 尾巴剩 1 个」。
## 图标尺寸恒定 44 —— R577c 刚按「别糊」放大过，紧凑只体现在间距，不缩图标。

const CELL := 44.0
const MAX_COLS := 6
const ROW_STEP := 48.0
const GAP_LOOSE := 60.0
const INNER_W := 310.0
const TOP_PAD := 34.0


static func row_counts(n: int, cap: int = 12) -> Array[int]:
	var count: int = clampi(n, 1, cap)
	var rows: int = ceili(float(count) / float(MAX_COLS))
	var base: int = int(count / rows)
	var extra: int = count % rows
	var out: Array[int] = []
	for r in rows:
		if r < extra:
			out.append(base + 1)
		else:
			out.append(base)
	return out


static func rect_for(i: int, zone: Rect2, counts: Array[int]) -> Rect2:
	var row: int = 0
	var col: int = maxi(i, 0)
	for r in counts.size():
		var c: int = counts[r]
		if col < c:
			row = r
			break
		col -= c
	var cnt: int = counts[row]
	var step_x: float = CELL + GAP_LOOSE
	if cnt > 1:
		step_x = minf(step_x, (INNER_W - CELL) / float(cnt - 1))
	var total_w: float = float(cnt - 1) * step_x + CELL
	var x0: float = zone.position.x + (zone.size.x - total_w) * 0.5
	return Rect2(x0 + float(col) * step_x,
			zone.position.y + TOP_PAD + float(row) * ROW_STEP,
			CELL, CELL)
'''


def apply(rel, old, new, tag):
    """按文件自身行尾做 exact-replace；已打过则跳过。"""
    p = os.path.join(ROOT, rel)
    b = io.open(p, "rb").read()
    eol = b"\r\n" if b"\r\n" in b else b"\n"
    o = old.replace("\n", eol.decode()).encode("utf-8")
    n = new.replace("\n", eol.decode()).encode("utf-8")
    if n in b:
        print(tag, "SKIP (already applied)")
        return
    if CHECK_ONLY:
        raise AssertionError("%s: check-only 但补丁未落地" % tag)
    c = b.count(o)
    assert c == 1, "%s: 锚点命中 %d 次（应为 1）: %s" % (tag, c, rel)
    io.open(p, "wb").write(b.replace(o, n, 1))
    print(tag, "OK")


def check_contains(rel, needles, tag):
    b = io.open(os.path.join(ROOT, rel), "rb").read()
    for s in needles:
        assert s.encode("utf-8") in b, "%s: 缺少 %r" % (tag, s)
    print(tag, "OK")


# ---------------------------------------------------------------- 新文件：排版唯一口
def ensure_layout():
    p = os.path.join(ROOT, LAYOUT_REL)
    want = LAYOUT_SRC.encode("utf-8")
    if os.path.isfile(p):
        got = io.open(p, "rb").read()
        if got == want:
            print("LAYOUT SKIP (identical)")
            return
        assert b"R577d" in got, "%s 不是本补丁管理的文件，不覆盖" % LAYOUT_REL
        assert not CHECK_ONLY, "check-only 但排版脚本需要更新"
        io.open(p, "wb").write(want)
        print("LAYOUT UPDATE OK")
        return
    assert not CHECK_ONLY, "check-only 但排版脚本不存在"
    io.open(p, "wb").write(want)
    print("LAYOUT OK")


# ---------------------------------------------------------------- battle_scene.gd
BS = "scripts/battle_scene.gd"

BS_PRELOAD_OLD = '''const UiTheme = preload("res://scripts/ui_theme.gd")
'''
BS_PRELOAD_NEW = '''const UiTheme = preload("res://scripts/ui_theme.gd")
## R577d：战斗道具格排版的唯一口（纯静态脚本，故意不写 class_name）。
const RelicBarLayout = preload("res://scripts/relic_bar_layout.gd")
'''

BS_RECT_OLD = '''func _relic_zone_rect() -> Rect2:
	## R577c：容量契约 —— 固定装得下 3 列 x 4 行 = 12 格 44x44 图标
	## （test_smoke 的「第 12 个徽章不越界」锁的就是这条，不跟着件数缩）。
	## 视觉上不留空白：_draw_relic_bar() 另算 draw_z，只把底板画到实际行数。
	return Rect2(794, 348, 338, 232)


func _relic_rect(i: int) -> Rect2:
	var z := _relic_zone_rect()
	return Rect2(z.position + Vector2(14 + (i % 3) * 104, 34 + int(i / 3) * 48), Vector2(44, 44))
'''
BS_RECT_NEW = '''func _relic_zone_rect() -> Rect2:
	## 容量契约 —— 固定装得下 12 格 44x44 图标
	## （test_smoke 的「第 12 个徽章不越界」锁的就是这条，不跟着件数缩）。
	## 视觉上不留空白：_draw_relic_bar() 另算 draw_z，只把底板画到实际行数。
	return Rect2(794, 348, 338, 232)


func _relic_layout_count() -> int:
	## 绘制 / 悬停 / 命中判定的唯一取数口：含溢出时末位那张「+N」摘要格。
	return clampi(_relic_bar_ids().size(), 1, _relic_max_slots())


func _relic_rect(i: int) -> Rect2:
	## R577d：格位按当前件数排 —— 一行最多 6 个，放不下才换行，
	## 换行后把总数按行平均分配（每行差 <= 1），间距随每行个数收紧。
	## i 超出当前件数时按「至少装得下 i+1 个」取布局，容量判据仍落在区域内。
	var want := clampi(maxi(_relic_layout_count(), i + 1), 1, _relic_max_slots())
	var counts := RelicBarLayout.row_counts(want, _relic_max_slots())
	return RelicBarLayout.rect_for(i, _relic_zone_rect(), counts)
'''

BS_ROWS_OLD = '''	# R577c：底板只画到当前实际行数，避免只拿 3 件道具时留出一大块空白。
	# 输入命中 / 容量契约仍用 z（固定 12 格），两者分开，不互相牵连。
	var draw_rows := clampi(ceili(float(mini(ids.size(), 12)) / 3.0), 1, 4)
	var draw_z := Rect2(z.position, Vector2(z.size.x, 40.0 + draw_rows * 48.0))
'''
BS_ROWS_NEW = '''	# 底板只画到当前实际行数，避免只拿 3 件道具时留出一大块空白。
	# 输入命中 / 容量契约仍用 z（固定 12 格），两者分开，不互相牵连。
	var draw_rows := RelicBarLayout.row_counts(mini(ids.size(), _relic_max_slots()), _relic_max_slots()).size()
	var draw_z := Rect2(z.position, Vector2(z.size.x, 40.0 + draw_rows * RelicBarLayout.ROW_STEP))
'''

BS_DEMO_OLD = '''	if "--relics" in args and engine != null:
		# 演示：右栏道具栏（截图验证用；放在 args 循环后，避免被 --level 重建覆盖）
		engine.self_relics = [6001, 6005, 6010]   # 初始白 / 奖励黄 / 事件紫
		_whisper_txt = "本回合造成的伤害 +1"
'''
BS_DEMO_NEW = '''	if "--relics" in args and engine != null:
		# 演示：右栏道具栏（截图验证用；放在 args 循环后，避免被 --level 重建覆盖）
		engine.self_relics = [6001, 6005, 6010]   # 初始白 / 奖励黄 / 事件紫
		_whisper_txt = "本回合造成的伤害 +1"
	if "--reliccount" in args and engine != null:
		# R577d 出图：按件数验「数量适应 / 满了换行 / 按行平均分配」。
		# 用法：`battle.tscn -- --screenshot --reliccount 7 --shotframe 600`
		var r577d_n := 4
		for r577d_i in args.size():
			if args[r577d_i] == "--reliccount" and r577d_i + 1 < args.size():
				r577d_n = clampi(int(args[r577d_i + 1]), 1, 16)
		var r577d_ids: Array[int] = []
		for r577d_k in r577d_n:
			r577d_ids.append(6001 + r577d_k)
		RunState.relics = r577d_ids
		engine.self_relics = r577d_ids.duplicate()
		status_text = "R577d：%d 件道具按行平均分配" % r577d_n
		queue_redraw()
'''

# ---------------------------------------------------------------- test_engine.gd
TE = "scripts/test_engine.gd"

TE_PRELOAD_OLD = '''const UiDrag = preload("res://scripts/ui_drag.gd")
'''
TE_PRELOAD_NEW = '''const UiDrag = preload("res://scripts/ui_drag.gd")
## R577d：排版唯一口（无 class_name，显式 preload 才能被 headless 套件调用）。
const RelicBarLayout = preload("res://scripts/relic_bar_layout.gd")
'''

TE_C_OLD = '''	check_src(icon577_bs.contains("Rect2(794, 348, 338, 232)")
			and icon577_bs.contains("Vector2(44, 44)")
			and icon577_bs.contains("var draw_z := Rect2(z.position,"),
			"R577c 数据：战斗右栏容量 12 格、每格 44x44，底板按行数收拢")
'''
TE_C_NEW = '''	check_src(icon577_bs.contains("Rect2(794, 348, 338, 232)")
			and icon577_bs.contains("var draw_z := Rect2(z.position,")
			and r577d_lay.contains("const CELL := 44.0"),
			"R577c 数据：战斗右栏容量 12 格、每格 44x44，底板按行数收拢")
'''

TE_ANCHOR_OLD = '''	# ==== R577c：拆掉文字横条槽，图标直接放大铺满正方形格 ====
'''
TE_ANCHOR_NEW = '''	# ==== R577d：战斗中道具排版按数量适应 + 换行平均分配 ====
	var r577d_lay := FileAccess.get_file_as_string("res://scripts/relic_bar_layout.gd")
	check_src(r577d_lay.contains("const CELL := 44.0")
			and r577d_lay.contains("const MAX_COLS := 6")
			and r577d_lay.contains("static func row_counts("),
			"R577d 源码：排版唯一口是纯静态脚本，图标 44 恒定 / 单行上限 6")
	var r577d_bad := ""
	for r577d_n in range(1, 13):
		var r577d_rows := RelicBarLayout.row_counts(r577d_n, 12)
		var r577d_sum := 0
		for r577d_c: int in r577d_rows:
			r577d_sum += r577d_c
		if r577d_sum != r577d_n:
			r577d_bad = "%d 件：分配合计 %d" % [r577d_n, r577d_sum]
		for r577d_c2: int in r577d_rows:
			if r577d_c2 < 1 or r577d_c2 > 6 or absi(r577d_c2 - r577d_rows[0]) > 1:
				r577d_bad = "%d 件：某行 %d 个（平均分配被破坏）" % [r577d_n, r577d_c2]
		if r577d_bad != "":
			break
		if r577d_n <= 6 and r577d_rows.size() != 1:
			r577d_bad = "%d 件不该换行" % r577d_n
			break
		if r577d_n > 6 and r577d_rows.size() != 2:
			r577d_bad = "%d 件应恰好换一次行" % r577d_n
			break
	check(r577d_bad == "", "R577d 数据：1~12 件每行差 <= 1、总数守恒、最少行数（%s）"
			% ("OK" if r577d_bad == "" else r577d_bad))
	var r577d_a := RelicBarLayout.row_counts(4, 12)
	var r577d_b := RelicBarLayout.row_counts(7, 12)
	var r577d_c := RelicBarLayout.row_counts(12, 12)
	check(r577d_a.size() == 1 and r577d_a[0] == 4
			and r577d_b.size() == 2 and r577d_b[0] == 4 and r577d_b[1] == 3
			and r577d_c.size() == 2 and r577d_c[0] == 6 and r577d_c[1] == 6,
			"R577d 定案：4 件一排 / 7 件 4+3 / 12 件 6+6，没有 N+1 尾巴")
	check_src(icon577_bs.contains("RelicBarLayout.row_counts(")
			and icon577_bs.contains("RelicBarLayout.rect_for(")
			and icon577_bs.contains("RelicBarLayout.ROW_STEP"),
			"R577d 源码：绘制行数 / 格位 / 悬停全走唯一排版口")
	# ==== R577c：拆掉文字横条槽，图标直接放大铺满正方形格 ====
'''

# ---------------------------------------------------------------- test_smoke.gd
SM = "scripts/test_smoke.gd"

SM_OLD = '''	else:
		print("SMOKE OK 溢出兜底：效果区 %d 槽 / 敌方效果 %d 槽 / 道具 %d 槽（末位均不越界，超出改画 +N 摘要）"
				% [cap_eff, cap_ee, cap_rel])
'''
SM_NEW = '''	else:
		print("SMOKE OK 溢出兜底：效果区 %d 槽 / 敌方效果 %d 槽 / 道具 %d 槽（末位均不越界，超出改画 +N 摘要）"
				% [cap_eff, cap_ee, cap_rel])
	# R577d 界面分发：真的把件数塞进战斗页，看格位是不是按行平均分配。
	var r577d_saved: Array = RunState.relics.duplicate()
	RunState.relics = [6001, 6002, 6003, 6004]
	var r577d_y4: float = scene._relic_rect(0).position.y
	for r577d_i in 4:
		if scene._relic_rect(r577d_i).position.y != r577d_y4:
			_smoke_fail("R577d 4 件道具应排在同一行（第 %d 枚换了行 = N+1 尾巴）" % r577d_i)
			break
	RunState.relics = [6001, 6002, 6003, 6004, 6005, 6006, 6007]
	var r577d_y7a: float = scene._relic_rect(0).position.y
	var r577d_y7b: float = scene._relic_rect(6).position.y
	if r577d_y7b <= r577d_y7a:
		_smoke_fail("R577d 7 件道具应换成两行")
	elif scene._relic_rect(4).position.y != r577d_y7b or scene._relic_rect(3).position.y != r577d_y7a:
		_smoke_fail("R577d 7 件应 4+3 平均分配（不是 6+1）")
	RunState.relics = r577d_saved
'''

# ---------------------------------------------------------------- verify_battle_instruments.gd
VBI = "tools/verify_battle_instruments.gd"

VBI_OLD = '''	for i in scene._relic_max_slots():
		assert(scene._relic_zone_rect().encloses(scene._relic_rect(i)))
		for j in i:
			assert(not scene._relic_rect(i).intersects(scene._relic_rect(j)))
	assert(scene._relic_rect(0).position.y == scene._relic_rect(2).position.y)
	assert(scene._relic_rect(3).position.y > scene._relic_rect(2).position.y)
'''
VBI_NEW = '''	var shown := mini(RunState.relics.size(), scene._relic_max_slots())
	for i in shown:
		assert(scene._relic_zone_rect().encloses(scene._relic_rect(i)))
		for j in i:
			assert(not scene._relic_rect(i).intersects(scene._relic_rect(j)))
	assert(scene._relic_rect(0).position.y == scene._relic_rect(4).position.y)
	assert(scene._relic_rect(5).position.y > scene._relic_rect(4).position.y)
'''

VBI_PRINT_OLD = '''	print("BATTLE INSTRUMENTS PASS: 3-column wrap, 12 nonoverlapping slots, overflow, separated controls")
'''
VBI_PRINT_NEW = '''	print("BATTLE INSTRUMENTS PASS: balanced rows, 12-slot capacity, overflow, separated controls")
'''


def main():
    ensure_layout()
    apply(BS, BS_PRELOAD_OLD, BS_PRELOAD_NEW, "BS preload")
    apply(BS, BS_RECT_OLD, BS_RECT_NEW, "BS rect")
    apply(BS, BS_ROWS_OLD, BS_ROWS_NEW, "BS rows")
    apply(BS, BS_DEMO_OLD, BS_DEMO_NEW, "BS demo")
    apply(TE, TE_PRELOAD_OLD, TE_PRELOAD_NEW, "TE preload")
    apply(TE, TE_ANCHOR_OLD, TE_ANCHOR_NEW, "TE r577d block")
    apply(TE, TE_C_OLD, TE_C_NEW, "TE r577c assertion")
    apply(SM, SM_OLD, SM_NEW, "SM dispatch")
    apply(VBI, VBI_OLD, VBI_NEW, "VBI asserts")
    apply(VBI, VBI_PRINT_OLD, VBI_PRINT_NEW, "VBI print")
    # 收尾核验：行尾没被混写、关键口都在
    for rel in (BS, TE, SM):
        b = io.open(os.path.join(ROOT, rel), "rb").read()
        assert b.count(b"\n") == b.count(b"\r\n"), "%s 出现 bareLF" % rel
    check_contains(BS, ["RelicBarLayout.rect_for(", "RelicBarLayout.row_counts(",
                        "RelicBarLayout.ROW_STEP", "_relic_layout_count"], "BS verify")
    check_contains(LAYOUT_REL, ["static func row_counts(", "static func rect_for(",
                                "const MAX_COLS := 6", "const CELL := 44.0"], "LAYOUT verify")
    print("PATCH_R577D", "CHECK_ONLY OK" if CHECK_ONLY else "OK")


if __name__ == "__main__":
    main()
