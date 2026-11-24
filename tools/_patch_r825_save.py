# -*- coding: utf-8 -*-
"""R825：战斗/奖励/商店检查点与地图返回入口。二进制读写，保留原行尾。"""
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
    assert count == 1, "%s anchor count=%d\n%s" % (path, count, old[:120])
    text = text.replace(old, new)
    out = text.replace("\n", "\r\n") if crlf else text
    p.write_bytes(out.encode("utf-8"))
    print("PATCH", path)


# ① 战斗胜利：所有血量 / 金币 / 奖励 / Boss 状态结算完之后，再写一份可继续的检查点。
replace("scripts/battle_scene.gd",
"""\t# 关掉奖励窗时 `_on_reward_panel_closed` 会照旧把玩家送走。
""",
"""\t# 关掉奖励窗时 `_on_reward_panel_closed` 会照旧把玩家送走。
\t# R825：函数开头 `_clear_battle_checkpoint()` 写的是「清掉战斗续点」那一瞬，
\t# 当时战后生命与奖励还没入账；若玩家在胜利 / 奖励页退出，旧档会表现为无故回血 + 吞奖励。
\t# 这里在整段结算全部完成后覆盖一份：普通胜利与「Boss 已打、尚未换层」都保留当下状态。
\tif RunState.run_active and not RunState.run_finished and not _shot_pending \\
\t\t\tand not _net_mode and DisplayServer.get_name() != "headless":
\t\tRunSave.save_run()
""")

# ② 奖励面板：待领数每次变化就落盘；关闭时再兜一次（包含不会改数量的卡组操作）。
replace("scripts/reward_panel.gd",
"""\tif _cached_n != RunState.pending_reward_count():
\t\t_refresh_btn()
""",
"""\tif _cached_n != RunState.pending_reward_count():
\t\t_refresh_btn()
\t\t_save_reward_checkpoint()
""")
replace("scripts/reward_panel.gd",
"""\t_reset_core()
\t_refresh_btn()
\tif not _closing_to_route and on_closed.is_valid():
""",
"""\t_reset_core()
\t_refresh_btn()
\t_save_reward_checkpoint()
\tif not _closing_to_route and on_closed.is_valid():
""")
replace("scripts/reward_panel.gd",
"""func _refresh_btn() -> void:
""",
"""func _save_reward_checkpoint() -> void:
\t## R825：领取 / 放弃 / 选卡之后立刻把结果落盘，别等下一张地图检查点。
\t## 出图与 headless 回归不写玩家存档；正常地图 / 战斗奖励页都走这一口。
\tif RunState.run_active and DisplayServer.get_name() != "headless" \\
\t\t\tand "--screenshot" not in OS.get_cmdline_user_args():
\t\tRunSave.save_run()


func _refresh_btn() -> void:
""")
replace("scripts/reward_panel.gd",
"""\tUiTheme.apply_chip(_btn, false, true)
\tadd_child(_btn)
""",
"""\tUiTheme.apply_chip(_btn, false, true)
\tUiTheme.apply_return_button(_btn)   # R825：与「返回同一间商店」共用 codex 按钮底
\tadd_child(_btn)
""")
replace("scripts/reward_panel.gd",
"""_btn.text = GameI18n.ui("reward", "REWARD_PENDING_ENTRY", "✦ 待领奖励 %d") % _cached_n""",
"""_btn.text = GameI18n.ui("reward", "REWARD_PENDING_ENTRY", "← 返回待领奖励 %d") % _cached_n""")

# ③ 商店：在店内也算「可回同一家店」；货架每次变化后把**完整成交结果**落盘。
replace("scripts/shop_scene.gd",
"""\t_setup_shop()   # R390：见上面那条注释 —— 必须在所有「造 run / 改当前格」的演示参数之后
""",
"""\t# R825：玩家此刻就站在这间店里；回标题 / 关进程后也应能回同一间，而不是等正常离店才登记。
\tif RunState.current_node_id >= 0:
\t\tRunState.shop_mark_revisit(RunState.current_node_id)
\t_setup_shop()   # R390：见上面那条注释 —— 必须在所有「造 run / 改当前格」的演示参数之后
\t_save_shop_checkpoint()   # 恢复分支不会走 _sync_shop_state，这里把重进标记也落一份
""")
replace("scripts/shop_scene.gd",
"""\tRunState.store_shop_state(_shop_node, {"row1": r1, "row2": r2, "row3": r3})
""",
"""\tRunState.store_shop_state(_shop_node, {"row1": r1, "row2": r2, "row3": r3})
\t_save_shop_checkpoint()   # R825：成交后立刻可续，不再只等「回到标题」那一次


func _save_shop_checkpoint() -> void:
\t## R825：商店检查点唯一写盘口。调用方必须先把商品与对应奖励 / 扣款都结算完。
\tif RunState.run_active and DisplayServer.get_name() != "headless" \\
\t\t\tand "--screenshot" not in OS.get_cmdline_user_args():
\t\tRunSave.save_run()
""")
# 这四处旧顺序是「先同步货架、后给商品」；现在同步会落盘，必须先完成实际发放。
replace("scripts/shop_scene.gd",
"""\te["sold"] = true
\t_sync_shop_state()      # R390：售罄位要进货架存档，重进店不重摇
\tRunState.gain_trap(int(t.id))
""",
"""\te["sold"] = true
\tRunState.gain_trap(int(t.id))
\t_sync_shop_state()      # R390 / R825：商品与售罄位一起进存档
""")
replace("scripts/shop_scene.gd",
"""\t\te["sold"] = true
\t\t_sync_shop_state()      # R390
\t\tRunState.gain_max_hp(5)
""",
"""\t\te["sold"] = true
\t\tRunState.gain_max_hp(5)
\t\t_sync_shop_state()      # R390 / R825：生命与售罄位一起进存档
""")
replace("scripts/shop_scene.gd",
"""\t\te["sold"] = true
\t\t_sync_shop_state()      # R390
\t\tRunState.add_chocolate(1)   # R236：体力回到 > 0 会撤销「耗尽→开 Boss」的待触发
\t\tRunState.sync_fatigue()   # R223 难度 5：巧克力回到 6 以上 → 疲惫出卡组
""",
"""\t\te["sold"] = true
\t\tRunState.add_chocolate(1)   # R236：体力回到 > 0 会撤销「耗尽→开 Boss」的待触发
\t\tRunState.sync_fatigue()   # R223 难度 5：巧克力回到 6 以上 → 疲惫出卡组
\t\t_sync_shop_state()      # R390 / R825：巧克力、疲惫与售罄位一起进存档
""")
replace("scripts/shop_scene.gd",
"""\t\te["sold"] = true
\t\t_sync_shop_state()      # R390
\t\tRunState.gain_key(RunState.DAGGER_RELIC_ID)
""",
"""\t\te["sold"] = true
\t\tRunState.gain_key(RunState.DAGGER_RELIC_ID)
\t\t_sync_shop_state()      # R390 / R825：信物与售罄位一起进存档
""")

# ④ 地图：Boss 奖励尚未处理时不许自动换层；关窗后再由原入口推进。
replace("scripts/map_scene.gd",
"""\tif RunState.run_active and RunState.boss_beaten:
\t\tvar nxt := GameLayers.next_layer(RunState.current_layer)
""",
"""\t# R825：Boss 战后直接退出再读档时，先留在本层让玩家领奖励；
\t# 旧顺序会先 advance_layer → forfeit_pending_rewards，奖励就被换层规则误吞了。
\tif RunState.run_active and RunState.boss_beaten and RunState.pending_reward_count() == 0:
\t\tvar nxt := GameLayers.next_layer(RunState.current_layer)
""")
replace("scripts/map_scene.gd",
"""var _reward_panel: RewardPanel = null
""",
"""var _reward_panel: RewardPanel = null
var _shop_return_btn: Button = null   # R825：地图左上「返回同一间商店」
""")
replace("scripts/map_scene.gd",
"""\t_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
\t# R442：暗动力（6054）的代价""",
"""\t_reward_panel = RewardPanel.attach(self, Vector2(12, 40))
\t_reward_panel.on_closed = _on_map_reward_closed
\t# R825：商店返回不再只靠「点脚下那格」；读档回来也有明确按钮，货架仍读 shop_states。
\t_shop_return_btn = Button.new()
\t_shop_return_btn.position = Vector2(12, 90)
\t_shop_return_btn.size = Vector2(196, 46)
\t_shop_return_btn.custom_minimum_size = Vector2(196, 46)
\t_shop_return_btn.text = GameI18n.ui("map", "MAP_RETURN_TO_SHOP", "← 返回同一间商店")
\t_shop_return_btn.tooltip_text = ""
\t_shop_return_btn.pressed.connect(_return_to_shop)
\tUiTheme.apply_return_button(_shop_return_btn)
\tadd_child(_shop_return_btn)
\t_refresh_shop_return_btn()
\t# R442：暗动力（6054）的代价""")
replace("scripts/map_scene.gd",
"""func _process(delta: float) -> void:
\t_t += delta
""",
"""func _process(delta: float) -> void:
\t_t += delta
\t_refresh_shop_return_btn()
""")
replace("scripts/map_scene.gd",
"""func _open_reward_panel() -> void:
""",
"""func _refresh_shop_return_btn() -> void:
\t## R825：只有「脚下这间店仍可重进」才显示；一旦真正走去新格，advance 会关掉窗口。
\tif _shop_return_btn != null:
\t\t_shop_return_btn.visible = RunState.run_active \\
\t\t\t\tand RunState.shop_revisit_ok(RunState.current_node_id)


func _return_to_shop() -> void:
\t## R825：回当前格对应的同一间店；不 advance、不扣巧克力、不作废待领奖励、不重摇货架。
\tif not RunState.shop_revisit_ok(RunState.current_node_id):
\t\treturn
\tvar cell := _cur_cell()
\tif cell.is_empty():
\t\treturn
\tRunState.pending_node = cell
\tSceneFx.goto("res://scenes/shop.tscn")


func _on_map_reward_closed() -> void:
\t## R825：读档时被暂缓的 Boss 换层，在这批奖励处理完后交还给地图原路由。
\tif RunState.run_active and RunState.boss_beaten and RunState.pending_reward_count() == 0 \\
\t\t\tand GameLayers.next_layer(RunState.current_layer) > 0:
\t\tSceneFx.goto("res://scenes/map.tscn")


func _open_reward_panel() -> void:
""")

# ⑤ 共用返回按钮样式；素材未导入时退回既有羊皮纸按钮，绝不空按钮。
replace("scripts/ui_theme.gd",
"""static func adventure_panel_style(padding := 24.0, dark := false) -> StyleBox:
""",
"""static func apply_return_button(btn: Button) -> void:
\t## R825：地图「返回奖励 / 返回同一间商店」共用的 codex 羊皮纸按钮底。
\t## 文字仍由 Godot 按当前语言绘制；素材缺失 / 未导入时回退到既有 button_paper。
\tif btn == null:
\t\treturn
\tvar tex: Texture2D = UiAssets.get_tex("return_context_button")
\tfor state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
\t\tif tex == null:
\t\t\tbtn.add_theme_stylebox_override(state, adventure_button_style(false, state, 12, 6))
\t\t\tcontinue
\t\tvar sb := StyleBoxTexture.new()
\t\tsb.texture = tex
\t\tsb.texture_margin_left = 44
\t\tsb.texture_margin_right = 34
\t\tsb.texture_margin_top = 6
\t\tsb.texture_margin_bottom = 6
\t\tsb.content_margin_left = 28
\t\tsb.content_margin_right = 12
\t\tsb.content_margin_top = 2
\t\tsb.content_margin_bottom = 2
\t\tif state == "hover" or state == "hover_pressed":
\t\t\tsb.modulate_color = Color(1.10, 1.10, 1.06)
\t\telif state == "pressed":
\t\t\tsb.modulate_color = Color(0.86, 0.88, 0.82)
\t\tbtn.add_theme_stylebox_override(state, sb)
\tbtn.add_theme_stylebox_override("focus", _btn_box(Color.TRANSPARENT, ADVENTURE_BRASS_LIT, 2, RADIUS_SM))
\tfor role in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
\t\tbtn.add_theme_color_override(role, PAGE_INK)
\tbtn.add_theme_color_override("font_disabled_color", PAGE_MUTED)
\tbtn.add_theme_font_override("font", font())
\tbtn.add_theme_font_size_override("font_size", FS_LABEL)
\tUiPressFx.attach(btn)


static func adventure_panel_style(padding := 24.0, dark := false) -> StyleBox:
""")

print("R825 CORE PATCH OK")
