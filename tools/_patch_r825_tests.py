# -*- coding: utf-8 -*-
"""R825：真实存档往返、地图上下文入口与截图演示回归。"""
from pathlib import Path

ROOT = Path(r"E:/work/card_rogue")


def replace(path, old, new):
    p = ROOT / path
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    if crlf:
        text = text.replace("\r\n", "\n")
    count = text.count(old)
    assert count == 1, "%s anchor count=%d\n%s" % (path, count, old[:160])
    text = text.replace(old, new)
    p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
    print("PATCH", path)


def append(path, block):
    p = ROOT / path
    raw = p.read_bytes()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    if crlf:
        text = text.replace("\r\n", "\n")
    assert "R825" not in text.split("func _test_r825")[-1] or "func _test_r825" not in text
    text = text.rstrip("\n") + "\n\n" + block.strip("\n") + "\n"
    p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))
    print("APPEND", path)


replace("scripts/test_engine.gd", "\t_test_r822()\n", "\t_test_r822()\n\t_test_r825()\n")
append("scripts/test_engine.gd", r'''
func _test_r825() -> void:
	## R825：战斗 / 奖励 / 商店共用存档的真实写盘 + 读盘，不只测 snapshot 字典。
	## 运行入口已 set_test_mode()，这里只碰 run_save_test.sav，不碰玩家真档。
	print("-- R825 存档时序与上下文恢复")
	var r825_rng := RandomNumberGenerator.new()
	r825_rng.seed = 8252026
	RunState.start_run(RogueMap.generate(r825_rng), GameLayers.LAYER_DEFAULT)
	RunState.relic_choice = []
	RunState.max_hp = 60
	RunState.hp = 17
	RunState.gold = 237
	RunState.chocolate = 4
	RunState.traps = [7001, -1, -1]
	RunState.pending_rewards = []
	RunState.queue_relic_reward(6005)
	var r825_idx := RunState.pending_rewards.size() - 1
	var r825_node := RunState.current_node_id
	var r825_shop := {"row1": [[8001, 1, 0]], "row2": [["trap", 7001, 1]],
			"row3": [["maxhp", 1], ["choco", 0]]}
	RunState.store_shop_state(r825_node, r825_shop)
	RunState.shop_mark_revisit(r825_node)
	check(RunSave.save_run(), "R825 真写盘：组合状态能写入测试存档")
	RunState.hp = 60
	RunState.gold = 0
	RunState.chocolate = 0
	RunState.traps = [-1, -1, -1]
	RunState.pending_rewards = []
	RunState.shop_states = {}
	RunState.shop_revisit_id = -1
	check(RunSave.load_run(), "R825 真读档：%s" % RunSave.last_error)
	check(RunState.hp == 17 and RunState.max_hp == 60,
			"R825 生命：读档保持战后 17/60，不恢复成满血（实际 %d/%d）" % [RunState.hp, RunState.max_hp])
	check(RunState.gold == 237 and RunState.chocolate == 4,
			"R825 资源：金币 237 / 巧克力 4 原样恢复")
	check(RunState.pending_reward_count() == 1 and not RunState.has_relic(6005),
			"R825 奖励：未领道具仍在队列，且没有提前入库")
	check(RunState.traps == [7001, -1, -1],
			"R825 工具：栏位与空格位置原样恢复（%s）" % str(RunState.traps))
	check(JSON.stringify(RunState.shop_state_of(r825_node)) == JSON.stringify(r825_shop)
			and RunState.shop_revisit_ok(r825_node),
			"R825 商店：同一货架、售罄位和重进窗口一起恢复")

	# 已领取状态也必须落盘；读档后再次领取要拒绝，不能多发一件。
	check(RunState.claim_pending_reward(r825_idx) and RunState.has_relic(6005),
			"R825 领奖：道具正常入库")
	check(RunSave.save_run(), "R825 领奖后写盘成功")
	RunState.relics = []
	RunState.pending_rewards[r825_idx]["state"] = RunState.REWARD_PENDING
	check(RunSave.load_run(), "R825 领奖后读档成功")
	check(str((RunState.pending_rewards[r825_idx] as Dictionary).get("state", "")) == RunState.REWARD_CLAIMED
			and RunState.pending_reward_count() == 0 and RunState.relics.count(6005) == 1,
			"R825 领奖后读档：claimed 与持有件数都保留")
	check(not RunState.claim_pending_reward(r825_idx) and RunState.relics.count(6005) == 1,
			"R825 防重复：已领条目不能再次发奖")

	# 时序守卫：结算后的覆盖写必须真的位于生命、金币、奖励入队之后。
	var r825_battle_src := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	var r825_show := r825_battle_src.find("func _show_over(win: bool)")
	var r825_save := r825_battle_src.find("# R825：函数开头", r825_show)
	check_src(r825_show >= 0 and r825_save > r825_battle_src.find("RunState.hp = maxi", r825_show)
			and r825_save > r825_battle_src.find("RunState.gain_gold(gold_gain)", r825_show)
			and r825_save > r825_battle_src.find("RunState.queue_battle_card_rewards", r825_show),
			"R825 战斗：最终检查点位于战后生命 / 金币 / 奖励结算之后")
	var r825_map_src := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
	check_src(r825_map_src.contains("RunState.boss_beaten and RunState.pending_reward_count() == 0")
			and r825_map_src.contains("func _on_map_reward_closed()"),
			"R825 Boss：有待领奖励时暂缓换层，关窗后交还原路由")
	var r825_reward_src := FileAccess.get_file_as_string("res://scripts/reward_panel.gd")
	check_src(r825_reward_src.contains("if _cached_n != RunState.pending_reward_count():\n\t\t_refresh_btn()\n\t\t_save_reward_checkpoint()")
			and r825_reward_src.contains("func close() -> void:")
			and r825_reward_src.contains("_save_reward_checkpoint()\n\tif not _closing_to_route"),
			"R825 奖励：待领数变化与关窗两条路都落盘")
	var r825_shop_src := FileAccess.get_file_as_string("res://scripts/shop_scene.gd")
	var r825_trap_fn := r825_shop_src.find("func _buy_trap")
	check_src(r825_trap_fn >= 0 and r825_shop_src.find("RunState.gain_trap", r825_trap_fn)
			< r825_shop_src.find("_sync_shop_state()", r825_trap_fn),
			"R825 商店：工具先发放再保存售罄状态")
''')

# 真场景：同一地图上同时出现奖励与商店两个返回入口，奖励按钮可实际开关。
replace("scripts/test_smoke.gd", """\t\t\t_check_map_scene],
\t\t["res://scenes/battle.tscn", func():
""", """\t\t\t_check_map_scene],
\t\t# R825：待领奖励 + 当前商店同时可返回；两个按钮共用 codex 羊皮纸素材。
\t\t["res://scenes/map.tscn", func():
\t\t\t\t_reset()
\t\t\t\tRunState.start_run(_map())
\t\t\t\tRunState.relic_choice = []
\t\t\t\tRunState.queue_relic_reward(6005)
\t\t\t\tfor _r825_c: Dictionary in RunState.map_cells:
\t\t\t\t\tif int(_r825_c["id"]) == RunState.current_node_id:
\t\t\t\t\t\t_r825_c["type"] = "shop"
\t\t\t\t\t\t_r825_c["hidden"] = false
\t\t\t\t\t\t_r825_c["revealed"] = true
\t\t\t\t\t\tbreak
\t\t\t\tRunState.store_shop_state(RunState.current_node_id,
\t\t\t\t\t\t{"row1": [[8001, 0, 0]], "row2": [], "row3": []})
\t\t\t\tRunState.shop_mark_revisit(RunState.current_node_id),
\t\t\t_check_r825_map_context],
\t\t["res://scenes/battle.tscn", func():
""")
append("scripts/test_smoke.gd", r'''
func _check_r825_map_context(scene: Variant) -> void:
	## R825：玩家要的「直接按按钮回去」必须落在真实地图上，不是只有 RunState 判据。
	var rp: RewardPanel = scene._reward_panel
	var sb: Button = scene._shop_return_btn
	if rp == null or rp._btn == null or sb == null:
		_smoke_fail("R825 地图：奖励 / 商店返回按钮没有实例化")
		return
	if not rp._btn.visible or not sb.visible:
		_smoke_fail("R825 地图：有待领奖励和可重进商店时两个按钮都应显示")
		return
	if rp._btn.text != "返回待领奖励 1" or sb.text != "返回同一间商店":
		_smoke_fail("R825 地图按钮文案漂移：%s / %s" % [rp._btn.text, sb.text])
		return
	if rp._btn.text.contains("←") or sb.text.contains("←"):
		_smoke_fail("R825 地图按钮：素材已有箭头，文案不能再叠一个")
		return
	var rr := Rect2(rp._btn.position, rp._btn.size)
	var sr := Rect2(sb.position, sb.size)
	if rr.intersects(sr) or rr.size.x < 196.0 or sr.size.x < 196.0:
		_smoke_fail("R825 地图按钮：矩形重叠或宽度不足（%s / %s）" % [str(rr), str(sr)])
		return
	for b: Button in [rp._btn, sb]:
		var style := b.get_theme_stylebox("normal")
		if not (style is StyleBoxTexture) or (style as StyleBoxTexture).texture == null:
			_smoke_fail("R825 地图按钮：没有使用已导入的 codex 纹理")
			return
	if not sb.pressed.is_connected(Callable(scene, "_return_to_shop")):
		_smoke_fail("R825 商店按钮：pressed 没有接到同店返回函数")
		return
	rp._btn.pressed.emit()
	if not rp.is_open():
		_smoke_fail("R825 奖励按钮：点击后没有打开当前待领奖励")
		return
	rp.close()
	if rp.is_open():
		_smoke_fail("R825 奖励按钮：关闭后仍盖住地图")
		return
	var src := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
	if not src.is_empty():
		var a := src.find("func _return_to_shop()")
		var b := src.find("func _on_map_reward_closed()", a)
		var body := src.substr(a, b - a) if a >= 0 and b > a else ""
		if body.is_empty() or body.contains("RunState.advance(") or body.contains("forfeit_pending_rewards"):
			_smoke_fail("R825 同店返回：不许推进地图或作废待领奖励")
			return
	print("SMOKE OK R825 地图：奖励 / 同店双返回按钮、codex 纹理、奖励开关与同店无推进守卫")
''')

# 出图：与 --reshop 合用，同时摆出一条真实待领奖励。
replace("scripts/map_scene.gd", """\t\tRunState.shop_mark_revisit(RunState.current_node_id)
\t# -- --midway：演示「走过一片区域」的状态（截图核验视野规则用）
""", """\t\tRunState.shop_mark_revisit(RunState.current_node_id)
\t# R825：`--screenshot --reshop --savecontext` 同时验收奖励与同店两个返回按钮。
\tif "--savecontext" in OS.get_cmdline_user_args():
\t\tRunState.pending_rewards = []
\t\tRunState.queue_relic_reward(6005)
\t# -- --midway：演示「走过一片区域」的状态（截图核验视野规则用）
""")
print("R825 TEST PATCH OK")
