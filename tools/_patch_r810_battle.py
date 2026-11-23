# -*- coding: utf-8 -*-
"""R810 战斗界面：太阳指环 / 海妖鱼叉 / 缺陷时钟 的演出接线。

三件都**不新增贴图**：太阳指环复用技能「圣光」族图（`FxArt.SKILL_HOLY`）+ 金色冲击环，
海妖鱼叉复用火花爆点 + 金色飘字，缺陷时钟用现成的横幅 / 震屏 / 钟表色脉冲。
"""
import io

P = "E:/work/card_rogue/scripts/battle_scene.gd"
s = io.open(P, encoding="utf-8", newline="").read()


def sub(old, new):
    global s
    old, new = old.replace("\n", "\r\n"), new.replace("\n", "\r\n")
    assert s.count(old) == 1, (old[:60], s.count(old))
    s = s.replace(old, new)


sub('''				_floaters.append({"pos": _cell_center(wc) + Vector2(0, -24),
						"sc": _grid_scroll, "text": "风妖精 -%d" % wf_d,
						"col": Color("7fd2a0"), "size": 15, "start": n, "dur": 1500})
		"boss_phase":''', '''				_floaters.append({"pos": _cell_center(wc) + Vector2(0, -24),
						"sc": _grid_scroll, "text": "风妖精 -%d" % wf_d,
						"col": Color("7fd2a0"), "size": 15, "start": n, "dur": 1500})
		"sun_ring":
			# R810 太阳指环（6082）：每个我方回合开始，对所有敌方单位 3 点伤害。
			# 与风妖精同一套「全体 ping」演出，只换色：日轮 = 金 + 象牙白。
			# ⚠️ 每回合都会放 → **不弹横幅、不拉镜头**（那是大事件的位置），
			#    节奏靠逐格 60ms 错开：看得见「一圈扫过去」，又不至于卡住操作。
			sfx.play("spell")
			var sr_d := int(data.get("dmg", 0))
			var sr_n := int(data.get("hits", 0))
			_say("☀ 太阳指环：对所有敌方单位造成 %d 点伤害（%d 个目标）" % [sr_d, sr_n])
			var sr_i := 0
			for sc: Vector2i in (data.get("cells", []) as Array):
				var sr_at := n + sr_i * 60
				_fx_push_cell(FxArt.SKILL_HOLY, sc, sr_at, 560, 132.0)
				_bursts.append({"pos": _cell_center(sc), "sc": _grid_scroll,
						"start": sr_at, "dur": 520, "col": Color("f2c14e"), "big": false})
				_floaters.append({"pos": _cell_center(sc) + Vector2(0, -24),
						"sc": _grid_scroll, "text": "太阳指环 -%d" % sr_d,
						"col": Color("f0c24e"), "size": 15, "start": sr_at, "dur": 1400})
				sr_i += 1
		"harpoon":
			# R810 海妖鱼叉（6083）：同一回合第 3 次命中同一敌人 → 追加 6 点。
			# 这一下是**追加伤害**，`fx_impact` 可能被「同格 700ms 只演一次」吞掉，
			# 所以这里单独给一次更重的爆点 + 自己的飘字，保证「追加的那 6 点」看得见。
			sfx.play("hit")
			var hp_cell: Vector2i = data.get("cell", Vector2i(-1, -1))
			var hp_d := int(data.get("amount", 0))
			var hp_n := int(data.get("hits", 0))
			if hp_cell.x >= 0:
				# 45ms 往后挪一点：让它压在「第 3 次命中」那一下之后，读作「追加」而不是「同一击」。
				var hp_at := n + 45
				_bursts.append({"pos": _cell_center(hp_cell), "sc": _grid_scroll,
						"start": hp_at, "dur": 620, "col": Color("37b3c8"), "big": true})
				_floaters.append({"pos": _cell_center(hp_cell) + Vector2(0, -34),
						"sc": _grid_scroll, "text": "海妖鱼叉 +%d" % hp_d,
						"col": Color("6fe0ea"), "size": 17, "start": hp_at, "dur": 1500})
			_say("🔱 海妖鱼叉：本回合第 %d 次命中 → 追加 %d 点伤害" % [hp_n, hp_d])
		"defect_clock":
			# R810 缺陷时钟（6084）：第 12 张牌打完 → 结束本回合、**跳过敌方回合**、
			# 直接开始新的我方回合。这是「白赚一个回合」的大事件，必须明确提示，
			# 否则玩家只会看到手牌突然全换掉、以为出 bug。
			# 不新增贴图：横幅 + 震屏 + 表盘金脉冲（棋盘中线一圈），全部复用现成件。
			sfx.play("turn")
			_show_banner("缺陷时钟 · 跳过敌方回合", Color("c8a24a"), 1700)
			_shake(6.0, 320)
			_bursts.append({"pos": Vector2(GRID_X + GRID_W * 0.5, GRID_Y + GRID_H * 0.5),
					"start": n, "dur": 780, "col": Color("e8d08a"), "big": true})
			_say("⏳ 缺陷时钟：本场第 %d 张牌 → 回合结束，立即开始新的我方回合" % int(data.get("at", 0)))
		"boss_phase":''')

io.open(P, "w", encoding="utf-8", newline="").write(s)
print("BATTLE OK, CRLF:", "\r\n" in s)
