# -*- coding: utf-8 -*-
"""R846 表现层 + 组合素材补丁。

涉及：
  * scripts/card_data.gd      （CRLF）组合动作白名单 + "draw_if_third"
  * scripts/assemble_rules.gd （LF）  组合文案 effect_text 分支
  * scripts/battle_scene.gd   （CRLF）事件处理 / 目标格 / 提示 / 演示钩子
  * scripts/battle_energy_hud.gd（CRLF）删掉 dodge 参数与那行状态
"""
import io

FILES = {}


def add(path, old, new):
    FILES.setdefault(path, []).append((old, new))


# ── card_data.gd：动作白名单 ──────────────────────────────────
add("scripts/card_data.gd",
    """	# R775：三条新动作 —— 堡垒「每层改造 +生命」/ 影子猫·幽灵「从卡组随机技能卡入手」/ 幽灵「自毁」。
	"bonus_hp_per_upgrade", "fetch_skill", "self_destruct",
]""",
    """	# R775：三条新动作 —— 堡垒「每层改造 +生命」/ 影子猫·幽灵「从卡组随机技能卡入手」/ 幽灵「自毁」。
	"bonus_hp_per_upgrade", "fetch_skill", "self_destruct",
	# R846：影子猫 8006 的下半句改成「其他卡满 3 张 → 抽 N 张」（原来是 fetch_skill + if_third）。
	"draw_if_third",
]""")

# ── assemble_rules.gd：文案 ─────────────────────────────────
add("scripts/assemble_rules.gd",
    """		"fetch_skill":
			if fx.get("if_third", false):
				return "若包含这张卡本回合打出的卡达到 3 张，从抽牌库将一张随机技能卡加入手牌"
			return "从抽牌库将一张随机技能卡加入手牌"
""",
    """		"fetch_skill":
			return "从抽牌库将一张随机技能卡加入手牌"
		"draw_if_third":
			# R846：影子猫 8006 的下半句。3 = GameEngine.SHADOW_CAT_NEED（这里不能 preload
			# 引擎，静态类会成环）—— 改常量时连这里一起改，`_test_r846` 有对应源码锁。
			return "若本回合已经使用过 3 张其他卡，抽%d张牌" % n
""")

# ── battle_scene.gd ─────────────────────────────────────────
# ① 费用面板 tooltip 里那行「闪躲：友军嘲讽」
add("scripts/battle_scene.gd",
    """			if charge > 0:
				tip += "；蓄力 %d：下一张技能结算 %d 次" % [charge, charge + 1]
			if engine.taunt_all_active(GameEngine.SIDE_SELF):
				tip += "；闪躲：友军嘲讽"
""",
    """			if charge > 0:
				tip += "；蓄力 %d：下一张技能结算 %d 次" % [charge, charge + 1]
""")

# ② 费用面板绘制的调用（去掉 dodge 实参）
add("scripts/battle_scene.gd",
    """	preload("res://scripts/battle_energy_hud.gd").draw(self, _font_bold,
			_roll("energy", state.energy), engine.max_energy(), epanel,
			engine.charge_count(GameEngine.SIDE_SELF), engine.taunt_all_active(GameEngine.SIDE_SELF))
""",
    """	preload("res://scripts/battle_energy_hud.gd").draw(self, _font_bold,
			_roll("energy", state.energy), engine.max_energy(), epanel,
			engine.charge_count(GameEngine.SIDE_SELF))
""")

# ③ 状态槽注释里的闪躲
add("scripts/battle_scene.gd",
    """	##    只有两种「卡面没写嘲讽、此刻却生效」的情况要补：嘲讽来自 traits，或闪躲 9103 的
	##    全员嘲讽窗口 —— 否则那个橙色环就成了唯一线索，等于没说明。
""",
    """	##    唯一要补的是「嘲讽来自 traits」（卡面字段没写）—— 否则那个橙色环就成了唯一线索。
	##    ⚠️ R846：闪躲 9103 改成敌方降力后，不再有任何「卡面外临时嘲讽」的窗口。
""")

# ③b 技能可选目标：闪躲 / 回转 只列敌方单位
add("scripts/battle_scene.gd",
    """	elif card.id == 9004 or card.id == GameEngine.DRAGON_BREATH_ID:
		for c: Vector2i in engine.state.board:
			if engine.state.board[c].owner == GameEngine.SIDE_OPPONENT:
				out.append(c)
		out.sort()
""",
    """	elif card.id == 9004 or card.id == GameEngine.DRAGON_BREATH_ID \\
			or card.id == GameEngine.DODGE_ID or card.id == GameEngine.SPIN_DRAW_ID:
		# R846：闪躲（使敌方单位降力）/ 回转（对目标造成 X 伤）也只列**敌方单位** ——
		# 默认分支会把己方单位一起高亮，点上去引擎只会回一句「需要指定一个敌方单位」。
		for c: Vector2i in engine.state.board:
			if engine.state.board[c].owner == GameEngine.SIDE_OPPONENT:
				out.append(c)
		out.sort()
""")

# ④ 闪躲的演示钩子（截图用）—— 改成新口径
add("scripts/battle_scene.gd",
    """	if "--dodge" in args and engine != null:
		# 演示（2026-10-02，R48；R542 改效果）：闪躲（9103）—— 0 费普通；本回合所有友方单位获得嘲讽。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.DODGE_ID).to_dict()))
		engine.state.energy = 5
		engine.state.place(CardData.from_dict(repo.get_card(8005).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.use_spell(0, null)                  # 闪躲：全员嘲讽
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "闪躲：本回合所有友方单位获得嘲讽（含后上场的单位）"
		_shot_t0 = _now()
		queue_redraw()
""",
    """	if "--dodge" in args and engine != null:
		# 演示（2026-10-02，R48；R846 改效果）：闪躲（9103）—— 0 费**稀有**；
		#   使一个敌方单位力量 -X，X = 本回合打出的牌数。先垫 3 张牌再打它 → X = 3。
		RunState.player_class = PlayerClass.ROGUE
		engine.state.hand.clear()
		engine.state.energy = 9
		engine.state.place(CardData.from_dict(repo.get_card(8005).to_dict()),
				Vector2i(4, 1), GameEngine.SIDE_SELF)
		engine.state.place(CardData.from_dict(repo.get_card(1051).to_dict()),
				Vector2i(2, 1), GameEngine.SIDE_OPPONENT)
		engine.state.self_card_plays = 3           # 本回合已经打过 3 张
		engine.state.hand.append(CardData.from_dict(repo.get_card(GameEngine.DODGE_ID).to_dict()))
		engine.use_spell(0, Vector2i(2, 1))        # 闪躲：敌方力量 -3
		_demo_hover_idx = 0
		_hover_hand = 0
		status_text = "闪躲：敌方力量 -X（X = 本回合已打出的牌数）"
		_shot_t0 = _now()
		queue_redraw()
""")

# ⑤ "dodge" 事件：从「全员嘲讽」改成降力飘字
add("scripts/battle_scene.gd",
    """		"dodge":
			sfx.play("spell")
			_floaters.append({"pos": Vector2(GRID_X + GRID_W / 2, GRID_Y - 62),
					"text": "闪躲：所有友方单位获得嘲讽",
					"col": UiTheme.KIND_EFFECT, "size": 16, "outline": 6,
					"start": n, "dur": 2200})
			_say("闪躲：本回合所有友方单位获得嘲讽")
""",
    """		"dodge":
			# 闪躲（9103，R846）：敌方单位力量 -X —— 与敲晕 / 威慑同一条降力表现（紫字 + 暗影图）。
			var dd_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var dd_n := int(data.get("amount", 0))
			sfx.play("spell")
			if dd_cell.x >= 0:
				_floaters.append({"pos": _cell_center(dd_cell) + Vector2(0, -6),
						"sc": _grid_scroll, "text": "力量 -%d" % dd_n,
						"col": Color("b06ad0"), "size": 16, "start": n, "dur": 1400})
			_say("闪躲：敌方力量 -%d（本回合已打出 %d 张）" % [dd_n, dd_n])
""")

# ⑥ "shadow_cat" 事件：从「加入手卡」改成「抽 N 张」
add("scripts/battle_scene.gd",
    """		"shadow_cat":
			var sc_c = data.get("card")
			_say("🐈 影子猫：%s" % (("「%s」加入手卡" % sc_c.card_name) if sc_c != null else "卡组里没有技能卡"))
""",
    """		"shadow_cat":
			# 影子猫（8006，R846）：本回合其他卡满 3 张 → 抽 2 张；不满就落空。
			var sc_got := int(data.get("draw", 0))
			if sc_got > 0:
				_say("🐈 影子猫：本回合已打 %d 张 → 抽 %d 张" % [
						int(data.get("plays", 0)), sc_got])
			else:
				_say("🐈 影子猫：本回合其他卡不足 3 张 → 没有抽牌")
""")

# ── battle_energy_hud.gd：去掉 dodge ───────────────────────
add("scripts/battle_energy_hud.gd",
    """static func draw(canvas: CanvasItem, font: Font, current: int, maximum: int, rect: Rect2, charge: int, dodge: bool) -> void:""",
    """static func draw(canvas: CanvasItem, font: Font, current: int, maximum: int, rect: Rect2, charge: int) -> void:""")

add("scripts/battle_energy_hud.gd",
    """		canvas.draw_string(font, rect.position + Vector2(0, 111), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, status_fs, UiTheme.PAGE_INK)
	if dodge:
		canvas.draw_string(font, rect.position + Vector2(0, 124), GameI18n.ui("battle", "BATTLE_ENERGY_DODGE", "闪躲：友军嘲讽"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 10, UiTheme.PAGE_INK)
""",
    """		canvas.draw_string(font, rect.position + Vector2(0, 111), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, status_fs, UiTheme.PAGE_INK)
""")


def main():
    for path, pairs in FILES.items():
        raw = io.open(path, "r", encoding="utf-8", newline="").read()
        crlf = raw.count("\r\n")
        pure_crlf = (crlf > 0 and raw.count("\n") == crlf)
        txt = raw.replace("\r\n", "\n") if pure_crlf else raw
        for old, new in pairs:
            n = txt.count(old)
            assert n == 1, "%s 锚点命中 %d 次（应为 1）：\n%s" % (path, n, old[:120])
            txt = txt.replace(old, new)
        out = txt.replace("\n", "\r\n") if pure_crlf else txt
        io.open(path, "w", encoding="utf-8", newline="").write(out)
        print("%-32s %s 改动 %d 处" % (path, "CRLF" if pure_crlf else "LF", len(pairs)))

    # 复核
    bs = io.open("scripts/battle_scene.gd", encoding="utf-8", newline="").read()
    assert "taunt_all_active" not in bs, "battle_scene 还引用 taunt_all_active"
    assert '"draw": got, "plays": plays' in io.open(
        "scripts/game_engine.gd", encoding="utf-8", newline="").read()
    hud = io.open("scripts/battle_energy_hud.gd", encoding="utf-8", newline="").read()
    assert "dodge" not in hud, "HUD 还留着 dodge"
    print("UI_OK")


if __name__ == "__main__":
    main()
