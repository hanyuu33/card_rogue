# -*- coding: utf-8 -*-
"""R761 补丁 6/9：battle_scene.gd（CRLF）—— 招募 9264 的选卡页接线。

四处接线（与「神秘牌」7011 的 toolpick 同构）：
  * `_pick_active_kind()`  认得 recruit；
  * `_build_pick_cfg()`    标题 / 说明 / 候选；
  * `_on_pick_confirmed()` 确认 → `engine.recruit_pick()`；
  * `_on_end_turn()`       没选完不许过回合（面板自动弹回来）。
"""
import io

p = r"E:\work\card_rogue\scripts\battle_scene.gd"
with io.open(p, "rb") as f:
    b = f.read()


def crlf(s):
    return s.replace("\r\n", "\n").replace("\n", "\r\n")


def rep(old, new, n=1):
    global b
    o = crlf(old).encode("utf-8")
    c = b.count(o)
    assert c == n, "命中 %d 次（期望 %d）：%r" % (c, n, old[:70])
    b = b.replace(o, crlf(new).encode("utf-8"))


# ---- 1. 活跃 kind ----
rep('''	# R331：惊喜运单（8079）回合开始 —— 候选是**卡组**（与淘汰 9174 同形态）。
	if engine.surprise_pending:
		return "surprise"
''', '''	# R331：惊喜运单（8079）回合开始 —— 候选是**卡组**（与淘汰 9174 同形态）。
	if engine.surprise_pending:
		return "surprise"
	# R761：招募（9264）—— 候选是**三个其他职业的盟友**（引擎在出牌那一刻就摇定了）。
	if engine.recruit_pending:
		return "recruit"
''')

# ---- 2. cfg ----
rep('''		"merge":
			# R298 合体（9167）：候选 = 卡组里**所有素体**（8025）。
''', '''		"recruit":
			# R761 招募（9264）：候选 = 三个其他职业的盟友各一张（引擎出牌时摇定）。
			# `opts[i]` = 候选下标（与 toolpick 同构：确认时原样交回引擎）。
			var rc_cards: Array = engine.recruit_cards()
			var rc_opts: Array = []
			for rc_i in rc_cards.size():
				rc_opts.append(rc_i)
			return {"kind": k, "short": "招募", "opts": rc_opts,
					"title": "招募：从这 %d 张里选一张加入手卡" % rc_cards.size(),
					"note": "点卡选中，再点确认 —— 它是**其他职业**的盟友，加入你的手牌",
					"cards": rc_cards, "max_sel": 1, "confirm_label": "确认招募",
					"cancel_label": ""}
		"merge":
			# R298 合体（9167）：候选 = 卡组里**所有素体**（8025）。
''')

# ---- 3. 确认 ----
rep('''		"merge":
			# R298 合体（9167）：确认 → 素体**本场消失**（进消耗区）→ 再调 use_spell 真正打出。
''', '''		"recruit":
			# R761 招募（9264）：确认 → 那张盟友的独立副本加入手卡。
			var rci := int(opts[sel[0]])
			var rc_all: Array = engine.recruit_cards()
			var rcnm := "?"
			if rci >= 0 and rci < rc_all.size():
				rcnm = (rc_all[rci] as CardData).card_name
			if engine.recruit_pick(rci):
				status_text = "招募：%s 加入手卡" % rcnm
				_say("「%s」加入手牌" % rcnm)
			else:
				_say("招募：卡没能进入手牌（手牌可能已满）")
			_clear_selection()
		"merge":
			# R298 合体（9167）：确认 → 素体**本场消失**（进消耗区）→ 再调 use_spell 真正打出。
''')

# ---- 4. 过回合守卫 ----
rep('''	if engine.rebirth_pending:
		_ensure_pick_visible("rebirth")
		_say("新生：请先从手牌里选一张使其消失（不能不选）")
		return
''', '''	if engine.rebirth_pending:
		_ensure_pick_visible("rebirth")
		_say("新生：请先从手牌里选一张使其消失（不能不选）")
		return
	if engine.recruit_pending:
		_ensure_pick_visible("recruit")
		_say("招募：请先从这三张里选一张加入手牌")
		return
''')

with io.open(p, "wb") as f:
    f.write(b)
print("battle_scene.gd OK")
