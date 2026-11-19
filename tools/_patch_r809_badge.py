# -*- coding: utf-8 -*-
"""R809：道具计数角标 + 战斗道具面板状态注口径修复。

四处改动：
  1. run_state.gd      新增 `relic_badge_text(id)` —— 角标数值的唯一取数口
  2. battle_scene.gd   `_draw_relic_bar` 每格画完弧后调 `_draw_relic_badge`
  3. battle_scene.gd   新增 `_draw_relic_badge` 绘制函数
  4. battle_scene.gd   `_relic_panel_rows` 的 note 移出 `if rspent:`（与地图面板对齐）
  5. test_engine.gd    新增 `_test_r809()` + 注册
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def patch(path, old, new, crlf):
    p = ROOT + path
    with io.open(p, encoding="utf-8", newline="") as f:
        s = f.read()
    if crlf:
        old = old.replace("\n", "\r\n")
        new = new.replace("\n", "\r\n")
    n = s.count(old)
    if n != 1:
        print("FAIL %s: anchor count=%d" % (path, n))
        sys.exit(1)
    s = s.replace(old, new)
    with io.open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("OK   %s" % path)


# ---------------- 1. run_state.gd：角标取数口 ----------------
OLD1 = '''	return rel.relic_name


static func lucky7_tick() -> bool:'''
NEW1 = '''	return rel.relic_name


static func relic_badge_text(id: int) -> String:
	## 道具图标**右下角角标**的唯一取数口（R809）。返回 "" = 不画角标。
	## 为什么要有这一层：图标模式下 `_draw_relic_bar` 只画图、不画名字，
	## 「还剩几次 / 还差几回合」原本只有悬停能看到 —— 触摸端等于看不见。
	## 口径：
	##   * 已耗尽（盆碎 / 绳用掉）→ 不画（图标画灰已经说明，再挂个「1」会骗人）。
	##   * lucky 7（6045）→ 距下次生效还剩几回合；**生效回合不画**
	##     （转动弧已经在说「就是现在」，再写 7 会被读成「还差 7 回合」）。
	##   * 火柴（6051）→ 剩余刷新次数，0 也照画（得让玩家看见已经用光）。
	##   * 洞窟绳（6048）→ 一次性，还在就是 1 次。
	##   * 雕像（6039）/ 不锈钢盆（6041）→ 剩余次数
	##     （`relic_display_name` 那对括号只在「缺图、退回文字」时才看得见）。
	##   * 其余道具 → 没有可数的东西。
	if not relics.has(id) or is_relic_spent(id):
		return ""
	match id:
		LUCKY7_RELIC_ID:
			return "" if lucky7_is_due() else str(lucky7_left())
		MATCH_RELIC_ID:
			return str(maxi(0, match_charge))
		CAVE_ROPE_RELIC_ID:
			return "1"
		RELIC_STATUE_ID:
			return str(statue_charge) if statue_charge > 0 else ""
		BASIN_RELIC_ID:
			return str(basin_charge) if basin_charge > 0 else ""
	return ""


static func lucky7_tick() -> bool:'''

patch("scripts/run_state.gd", OLD1, NEW1, False)


# ---------------- 2. battle_scene.gd：绘制调用 ----------------
OLD2 = '''		# R577f：唯一动态层 —— 暖黄渐隐拖尾弧，画在蓝边之后，每格错相 22°。
		if lit577f:
			_draw_relic_sweep(rect, i)'''
NEW2 = '''		# R577f：唯一动态层 —— 暖黄渐隐拖尾弧，画在蓝边之后，每格错相 22°。
		if lit577f:
			_draw_relic_sweep(rect, i)
		# R809：计数角标 —— 图标模式下不画名字，「还剩几次 / 还差几回合」得有地方露脸。
		_draw_relic_badge(rect, int(ids[i]))'''

patch("scripts/battle_scene.gd", OLD2, NEW2, True)


# ---------------- 3. battle_scene.gd：绘制函数 ----------------
OLD3 = '''			Vector2(draw_z.position.x + 6.0, draw_z.position.y + draw_z.size.y + 20.0), Color("d9a8ff"))


## R117：这里原本是 `_draw_opponent_hand()`（顶部一排**卡背** + 「（对手手牌区）」占位字）。'''
NEW3 = '''			Vector2(draw_z.position.x + 6.0, draw_z.position.y + draw_z.size.y + 20.0), Color("d9a8ff"))


func _draw_relic_badge(rect: Rect2, id: int) -> void:
	## R809：道具图标右下角的计数角标（lucky 7 剩余回合 / 火柴剩余刷新 / 洞窟绳 1 次 /
	## 雕像与不锈钢盆的余量）。数值唯一口 = `RunState.relic_badge_text()` ——
	## 界面不另算一遍，免得「角标写 3、悬停说 4」变成两套账。
	## 样式跟着 UI 的暖金描边走：深底 + 1px 金边 + 浅米字，压在弧与蓝边之上。
	var txt := RunState.relic_badge_text(id)
	if txt == "":
		return
	var fs := 12
	var tw := _font_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bw := maxf(14.0, tw + 6.0)
	var bh := 14.0
	# 贴图标右下角、往外探 1px：完全内缩时角标会被读成「图标缺了一角」。
	var br := Rect2(rect.position.x + rect.size.x - bw + 1.0,
			rect.position.y + rect.size.y - bh + 1.0, bw, bh)
	draw_rect(br.grow(1.0), Color(0.06, 0.05, 0.04, 0.55), true)   # 外描边：深色图标上也要立得住
	draw_rect(br, Color(0.11, 0.10, 0.08, 0.94), true)
	draw_rect(br, Color(0.96, 0.84, 0.48, 1.0), false, 1.0)
	# ⚠️ `_draw_string_center` 内部已经加了 `px * 0.36` 的基线补偿 ——
	#   这里传**视觉中心**（框中心），别再加一次偏移，否则数字会贴底被切。
	_draw_string_center(_font_bold, fs, txt,
			Vector2(br.position.x + bw * 0.5, br.position.y + bh * 0.5),
			Color(1.0, 0.96, 0.82), -1)


## R117：这里原本是 `_draw_opponent_hand()`（顶部一排**卡背** + 「（对手手牌区）」占位字）。'''

patch("scripts/battle_scene.gd", OLD3, NEW3, True)


# ---------------- 4. battle_scene.gd：面板 note 移出 spent 分支 ----------------
OLD4 = '''		# R367：已耗尽的留在列表里，名字后缀 + 标签前缀 + 色块压灰，正文补一句状态。
		var rspent := RunState.is_relic_spent(int(ids[i]))
		if rspent:
			nm += "（已耗尽）"
			tag = "已耗尽 · " + tag
			scol = Color("8a8f98")
			var s_note := RunState.relic_state_note(int(ids[i]))
			if s_note != "":
				desc += "  （%s）" % s_note'''
NEW4 = '''		# R367：已耗尽的留在列表里，名字后缀 + 标签前缀 + 色块压灰，正文补一句状态。
		var rspent := RunState.is_relic_spent(int(ids[i]))
		if rspent:
			nm += "（已耗尽）"
			tag = "已耗尽 · " + tag
			scol = Color("8a8f98")
		# R809：状态注**不再只给已耗尽的**。旧版把这段写在 `if rspent:` 里面，
		# 于是活着的 lucky 7 / 火柴在战斗内点开面板看不到倒计时；
		# 而 `map_scene._relic_panel_rows()` 一直是无条件拼 note —— 同一个名字两套口径。
		# 已耗尽时 note 本身就是「已耗尽，效果不再生效。」，与旧行为逐字一致。
		var s_note := RunState.relic_state_note(int(ids[i]))
		if s_note != "":
			desc += "  （%s）" % s_note'''

patch("scripts/battle_scene.gd", OLD4, NEW4, True)


# ---------------- 5. test_engine.gd：注册 + 测试函数 ----------------
OLD5 = '''	_test_r807()

	print("== 结果：'''
NEW5 = '''	_test_r807()
	_test_r809()

	print("== 结果：'''

patch("scripts/test_engine.gd", OLD5, NEW5, True)

OLD6 = '''func _test_r807() -> void:'''
NEW6 = '''func _test_r809() -> void:
	## R809：道具计数角标 —— lucky 7 / 火柴 / 洞窟绳（+ 雕像、盆）在**图标上**就能看到数字。
	## 修的两件事：
	##   ① 图标模式不画名字，「还剩几次 / 还差几回合」原本只有悬停能看到（触摸端看不见）；
	##   ② 战斗道具面板只在「已耗尽」时才补状态注，活着的 lucky 7 / 火柴读不到倒计时
	##      （地图面板一直是无条件的 —— 同名函数两套口径）。
	RunState.relics = []
	RunState.spent_relics = []
	RunState.lucky7_turns = 0
	RunState.match_charge = 0
	RunState.statue_charge = 0
	RunState.basin_charge = 0

	check(RunState.relic_badge_text(6045) == "",
			"R809 角标：未持有 lucky 7 → 不画")

	RunState.relics = [6045]
	for r809_pair in [[0, "7"], [1, "6"], [3, "4"], [6, "1"], [8, "6"], [13, "1"]]:
		RunState.lucky7_turns = int(r809_pair[0])
		check(RunState.relic_badge_text(6045) == str(r809_pair[1]),
				"R809 角标：lucky 7 计数 %d → 「%s」（实际「%s」）" % [
						int(r809_pair[0]), str(r809_pair[1]),
						RunState.relic_badge_text(6045)])
	RunState.lucky7_turns = 7
	check(RunState.relic_badge_text(6045) == "",
			"R809 角标：lucky 7 生效回合不画数字（转动弧已经在说「就是现在」）")
	RunState.lucky7_turns = 14
	check(RunState.relic_badge_text(6045) == "",
			"R809 角标：lucky 7 第 14 回合（第二次生效）同样不画")

	RunState.relics = [6051]
	RunState.match_charge = 2
	check(RunState.relic_badge_text(6051) == "2",
			"R809 角标：火柴剩 2 次 → 「2」（实际「%s」）" % RunState.relic_badge_text(6051))
	RunState.match_charge = 0
	check(RunState.relic_badge_text(6051) == "0",
			"R809 角标：火柴用光 → 照画「0」，别让玩家以为还能刷")

	RunState.relics = [6048]
	RunState.spent_relics = []
	check(RunState.relic_badge_text(6048) == "1",
			"R809 角标：洞窟绳只有一个「1」（实际「%s」）" % RunState.relic_badge_text(6048))
	RunState.spend_relic(6048)
	check(RunState.relic_badge_text(6048) == "",
			"R809 角标：洞窟绳用掉（画灰）→ 角标收掉，别留着「1」骗人")

	RunState.relics = [6039, 6041]
	RunState.spent_relics = []
	RunState.statue_charge = 3
	RunState.basin_charge = 7
	check(RunState.relic_badge_text(6039) == "3" and RunState.relic_badge_text(6041) == "7",
			"R809 角标：雕像 3 / 盆 7 —— 图标上看得见余量（名字那对括号只在缺图时才露）")
	RunState.statue_charge = 0
	RunState.basin_charge = 0
	check(RunState.relic_badge_text(6039) == "" and RunState.relic_badge_text(6041) == "",
			"R809 角标：计数归零 → 不画（免得顶着「0」）")

	# 没有可数东西的道具一律不画（别全栏挂上角标）
	RunState.relics = [6013, 6044]
	check(RunState.relic_badge_text(6013) == "" and RunState.relic_badge_text(6044) == "",
			"R809 角标：叠鸭 / 储物箱这种没有「次数」的不画角标")

	# 面板口径：活着的 lucky 7 也要有状态注（旧版只在已耗尽时才补）
	RunState.relics = [6045]
	RunState.spent_relics = []
	RunState.lucky7_turns = 3
	check(RunState.relic_state_note(6045).contains("4"),
			"R809 面板：活着的 lucky 7 状态注写「还差 4 回合」（%s）"
				% RunState.relic_state_note(6045))

	# 源码守卫：面板里那句 note 必须在 `if rspent:` **外面**（缩进 2 个 tab）
	var r809_src := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	var r809_tabs := -1
	for ln in r809_src.split("\\n"):
		if ln.contains("RunState.relic_state_note(int(ids[i]))"):
			r809_tabs = 0
			for ch in ln:
				if ch == "\\t":
					r809_tabs += 1
				else:
					break
	check_src(r809_tabs == 2,
			"R809 面板：状态注在 spent 分支外面（缩进 %d 个 tab，应为 2）" % r809_tabs)
	check_src(r809_src.contains("_draw_relic_badge(rect, int(ids[i]))"),
			"R809 角标：道具栏每格都接上了 `_draw_relic_badge`")
	check_src(r809_src.contains("RunState.relic_badge_text(id)"),
			"R809 角标：绘制口走唯一取数口，不自己算数字")

	RunState.relics = []
	RunState.spent_relics = []
	RunState.lucky7_turns = 0
	RunState.match_charge = 0
	RunState.statue_charge = 0
	RunState.basin_charge = 0


func _test_r807() -> void:'''

patch("scripts/test_engine.gd", OLD6, NEW6, True)

print("ALL DONE")
