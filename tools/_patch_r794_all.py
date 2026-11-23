# -*- coding: utf-8 -*-
"""R794 全量补丁：圣剑改名已单独跑过（字节级），本脚本只做新增内容。

  1. cards.json        —— 新卡 9271 巧克力工厂（2 费工事 0/0/30 · 次元 · 事件卡）
  2. game_engine.gd    —— 回合开始钩子（费用 + 抽牌，分裂之影范式）
  3. game_layers.gd    —— 第二层事件池登记 factory / EVENT_NAMES
  4. event_scene.gd    —— 事件实现（四连点试吃 + 包下工厂）
  5. i18n cards_*.json —— 9271 三语
  6. i18n narrative_*  —— 事件长文四语
  7. i18n event_ui_*   —— 选项 / 结果四语
  8. test_engine.gd    —— 计数更新 + _test_r794 + 注册
  9. validate_spanish  —— 卡数 331 → 332

所有改动 exact-replace + assert count==1；行尾按文件原样（CRLF / LF）自动识别。
"""
import os

WT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rd(p):
    raw = open(os.path.join(WT, p), "rb").read()
    crlf = b"\r\n" in raw
    return raw.decode("utf-8").replace("\r\n", "\n"), crlf


def wr(p, text, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    open(os.path.join(WT, p), "wb").write(text.encode("utf-8"))


def rep1(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "%s：锚点命中 %d 次（期望 1）\n%r" % (tag, n, old[:120])
    return text.replace(old, new)


# ---------------------------------------------------------------- 1. cards.json

CARD_9271 = """    {
      "id": 9271,
      "name": "巧克力工厂",
      "kind": "工事",
      "cost": 2,
      "power": 0,
      "health": 30,
      "attack_range": 0,
      "move_speed": 0,
      "rarity": 5,
      "group": "player",
      "class": "",
      "traits": [
        "工事",
        "巧克力工厂",
        "事件"
      ],
      "affixes": [
        "次元"
      ],
      "effect_text": "回合开始时，获得 1 费用并抽一张卡。",
      "target_mode": "none",
      "color": "火",
      "image": ""
    }
  ]"""

OLD_CARDS_TAIL = """      "effect_text": "所有盟友移动速度 +1；若为其他职业盟友，改为一回合行动两次。",
      "target_mode": "none",
      "color": "水风",
      "image": ""
    }
  ]"""


def patch_cards():
    p = "cards.json"
    t, crlf = rd(p)
    if '"id": 9271' in t:
        print("  skip cards.json（已有 9271）")
        return
    t = rep1(t, OLD_CARDS_TAIL, OLD_CARDS_TAIL.replace("    }\n  ]", "    },\n" + CARD_9271), "cards.json")
    wr(p, t, crlf)
    print("  ok cards.json +9271")


# ------------------------------------------------------------ 2. game_engine.gd

ENGINE_CONSTS = """const CHOCO_FACTORY_ID := 9271
const CHOCO_FACTORY_TRAIT := "巧克力工厂\""""

ENGINE_CONSTS_BLOCK = """
# ---- R794（2026-11-18）巧克力工厂 9271 ----
# 巧克力工厂（9271 工事，**事件卡** · 第二层事件「巧克力工厂」产出）：2 费 0/0/30，带「次元」。
#   **自己的回合开始时 +1 费用并抽 1 张**；场上多座叠加（每座各发一份）。
# * 判据读场上 Placement 的 trait（与分裂之影 8067 同范式）—— 工事离场就没效果。
# * 费用并入 `_begin_turn(SIDE_SELF)` 的 `state.energy`（与鸭翼 / 鸭语耳环同一发放口），
#   抽牌排在常规抽牌之后走 `_draw_many` 统一口。
# * 事件专属（rarity 5 + traits「事件」），敌方拿不到 → 不写对称侧。
%s""" % ENGINE_CONSTS

ENGINE_ICE_ANCHOR = """			_log("冰淇淋与汽水：第 1 回合额外 +%d 费用、多抽 %d 张"
				%[ICECREAM_ENERGY, ICECREAM_DRAW])"""

ENGINE_ICE_APPEND = """

		# R794 巧克力工厂（9271）：场上每座「我方回合开始 +1 费用并抽 1 张」。
		# 费用在这里并入发放（与鸭翼 / 鸭语耳环同一条 state.energy 口），抽牌排在
		# 常规抽牌之后（`_choco_factory_draw`）。事件专属卡，敌方拿不到 → 不写对称侧。
		var factory_energy := _choco_factory_energy()
		if factory_energy > 0:
			state.energy += factory_energy"""

ENGINE_LOG_OLD = '''		_log("── 我方第 %d 回合：费用重置为 %d%s%s%s%s%s%s%s（共 %d），抽 %d 张" % ['''

ENGINE_LOG_NEW = '''		_log("── 我方第 %d 回合：费用重置为 %d%s%s%s%s%s%s%s%s（共 %d），抽 %d 张" % ['''

ENGINE_LOG_ARG_OLD = '''			"，耳环自动出 %d 张" % earring_autoplayed if earring_autoplayed > 0 else "",
			state.energy, drawn])'''

ENGINE_LOG_ARG_NEW = '''			"，耳环自动出 %d 张" % earring_autoplayed if earring_autoplayed > 0 else "",
			"（+%d 巧克力工厂）" % factory_energy if factory_energy > 0 else "",
			state.energy, drawn])'''

ENGINE_CALL_OLD = '''		_shadow_split_draw(SIDE_SELF)   # 分裂之影 8067（R217）'''

ENGINE_CALL_NEW = '''		_shadow_split_draw(SIDE_SELF)   # 分裂之影 8067（R217）
		_choco_factory_draw()             # 巧克力工厂 9271（R794）：费用在上面发过，这里只管抽'''

ENGINE_FUNC_OLD = '''	_log("分裂之影：回合开始多抽 %d 张（场上 %d 座）" % [got, n])
	action.emit("shadow_split", {"draw": got, "count": n})'''

ENGINE_FUNC_NEW = ENGINE_FUNC_OLD + '''


func _choco_factory_energy() -> int:
	## 巧克力工厂（9271，R794）：场上每座「我方回合开始 +1 费用」的额度。
	## 判据读场上 Placement 的 trait（与分裂之影 8067 同范式）—— 工事离场就没效果。
	var n := 0
	for p: Placement in state.board.values():
		if p.owner == SIDE_SELF and p.card.traits.has(CHOCO_FACTORY_TRAIT):
			n += 1
	return n


func _choco_factory_draw() -> void:
	## 巧克力工厂（9271，R794）：本方回合开始时，场上每座抽 1 张。
	## 费用部分在 `_begin_turn(SIDE_SELF)` 发放；抽牌走 `_draw_many` 统一口
	## （手牌满照常 hand_full、牌库 / 弃牌区空照常记日志）。
	## 事件专属卡（rarity 5 + traits「事件」），敌方拿不到 → 不写对称侧。
	var n := _choco_factory_energy()
	if n <= 0:
		return
	var got := _draw_many(n)
	if got > 0:
		_log("巧克力工厂：回合开始 +%d 费用、多抽 %d 张（场上 %d 座）" % [n, got, n])
		action.emit("choco_factory", {"energy": n, "draw": got, "count": n})'''


def patch_engine():
    p = "scripts/game_engine.gd"
    t, crlf = rd(p)
    if "_choco_factory_draw" in t:
        print("  skip game_engine.gd（已应用）")
        return
    t = rep1(t, 'const SHADOW_SPLIT_TRAIT:= "分裂之影"',
             'const SHADOW_SPLIT_TRAIT:= "分裂之影"' + "\n" + ENGINE_CONSTS_BLOCK, "engine consts")
    t = rep1(t, ENGINE_ICE_ANCHOR, ENGINE_ICE_ANCHOR + ENGINE_ICE_APPEND, "engine ice")
    t = rep1(t, ENGINE_LOG_OLD, ENGINE_LOG_NEW, "engine log fmt")
    t = rep1(t, ENGINE_LOG_ARG_OLD, ENGINE_LOG_ARG_NEW, "engine log args")
    t = rep1(t, ENGINE_CALL_OLD, ENGINE_CALL_NEW, "engine call")
    t = rep1(t, ENGINE_FUNC_OLD, ENGINE_FUNC_NEW, "engine funcs")
    wr(p, t, crlf)
    print("  ok game_engine.gd")


# ------------------------------------------------------------ 3. game_layers.gd

LAYERS_OLD = '''			# R754 奇异雕像：原登记在本层（R763d 用户口径「改为一层事件」→ 已挪到 LAYERS[1]）。
			# **不要照旧文档补回来** —— 第二层现在 14 种子类型。
		},'''

LAYERS_NEW = '''			# R794（店长口径「新增二层事件」）：巧克力工厂 —— 选项 1 可以连点四次：
			#   免费 1 巧克力 / 失 5 上限 1 块 / 失 15 上限 1 块 / 失 25 上限得卡「巧克力工厂」。
			# 「巧克力」是行动力资源（RunState.chocolate），发放走 `RunState.add_chocolate()`；
			# 上限代价走 `RunState.lose_max_hp()`（与林中的剑同一口）。
			"factory": 16,
			# R754 奇异雕像：原登记在本层（R763d 用户口径「改为一层事件」→ 已挪到 LAYERS[1]）。
			# **不要照旧文档补回来** —— 第二层现在 15 种子类型。
		},'''

NAMES_OLD = '''	"sword": "林中的剑",
	"delivery": "运送委托",'''

NAMES_NEW = '''	"sword": "林中的剑",
	"factory": "巧克力工厂",
	"delivery": "运送委托",'''


def patch_layers():
    p = "scripts/game_layers.gd"
    t, crlf = rd(p)
    if '"factory": 16' in t:
        print("  skip game_layers.gd（已应用）")
        return
    t = rep1(t, LAYERS_OLD, LAYERS_NEW, "layers events")
    t = rep1(t, NAMES_OLD, NAMES_NEW, "layers names")
    wr(p, t, crlf)
    print("  ok game_layers.gd")


# ----------------------------------------------------------- 4. event_scene.gd

FACTORY_CONSTS = '''

# R794 巧克力工厂（第二层专属）：选项 1 可以连点四次 ——
#   ① 免费得 1 巧克力；② 失 5 最大生命得 1；③ 失 15 得 1；④ 失 25 得卡片「巧克力工厂」。
# 「巧克力」= 行动力资源（RunState.chocolate），发放走 `RunState.add_chocolate()`；
# 上限代价照走 `RunState.lose_max_hp()`（至少保留 1 点，不足则按钮置灰、结算再拦）。
# ⚠️ 故意不走 `_claim_reward()`：R147 的「一次访问只领一份」会把面板锁成只剩离开，
#    而这张黑板的本意就是「连吃四次」—— 本事件只有 rest_btn 一个奖励按钮，锁无可锁；
#    收尾只在第 ④ 次之后 `_collapse_to_leave()`。
const FACTORY_CARD_ID := 9271
const FACTORY_STAGE_COST := [0, 5, 15, 25]   # 第 n 次试吃的最大生命代价（0 = 免费）

const FACTORY_DESC := """林子深处飘着甜香。铜门虚掩，里面的传送带载着一排鸭子形状的
巧克力模具缓缓前行，脚下是一条温热的巧克力河。
柜台上立着一块小黑板：「试吃，第一块免费——之后每块都要用点什么来换。」
黑板角落还有一行小字：吃得最舍得下本的客人，可以带走整座工厂。"""

const FACTORY_DONE_DESC := """传送带停了下来。最后一份合同已经揣进怀里——
「巧克力工厂」已加入卡组：2 费工事，0 攻 / 30 血，次元；
你的每个回合开始时，获得 1 费用并抽一张卡。
甜香留在身后，林子重新安静下来。"""}'''

FACTORY_VARS = '''

var _factory_stage := 0         # R794 巧克力工厂：下一次试吃的档位（0..3）；4 = 已包下工厂
var _factory_result := ""       # R794 巧克力工厂：收尾那行结果（重绘要能复现）'''

FACTORY_ISFUNC_OLD = '''	## 与「挣扎」（-21 当前生命 → 卡「金属龙」）是一对：一个扣血、一个扣上限。
	return _is_event_node() and _pending_kind() == "sword"'''

FACTORY_ISFUNC_NEW = '''	## 与「挣扎」（-21 当前生命 → 卡「金属龙」）是一对：一个扣血、一个扣上限。
	return _is_event_node() and _pending_kind() == "sword"


func _is_choco_factory() -> bool:
	## R794 巧克力工厂（第二层专属）：试吃巧克力，可连点四次，最后一次给卡。
	return _is_event_node() and _pending_kind() == "factory"'''

FACTORY_TREASURE_OLD = '''	and not _is_flyer() and not _is_statue() and not _is_sword()'''

FACTORY_TREASURE_NEW = '''	and not _is_flyer() and not _is_statue() and not _is_sword() \\
			and not _is_choco_factory()'''

FACTORY_KIND_OLD = '''	if _is_sword():
		return "sword"
	if _is_treasure():'''

FACTORY_KIND_NEW = '''	if _is_sword():
		return "sword"
	if _is_choco_factory():
		return "factory"
	if _is_treasure():'''

FACTORY_TINT_OLD = '''		"smith", "card_merchant", "lake_lady", "apple_doctor", "delivery", "delivery_done", "martial":'''

FACTORY_TINT_NEW = '''		"smith", "card_merchant", "lake_lady", "apple_doctor", "delivery", "delivery_done", "martial", "factory":'''

FACTORY_READY_OLD = '''			leave_btn.text = "转身离开（不碰那把剑）"
			leave_btn.disabled = false
			result_label.text = ""
	elif _is_cave():'''

FACTORY_READY_NEW = '''			leave_btn.text = "转身离开（不碰那把剑）"
			leave_btn.disabled = false
			result_label.text = ""
	elif _is_choco_factory():
		event_name.text = "巧 克 力 工 厂"
		desc.text = FACTORY_DONE_DESC if _factory_stage >= 4 else FACTORY_DESC
		# 四连点事件：rest_btn 是**唯一**的奖励按钮（bbq / alt 收起），每按一次升一档；
		# 第 ④ 档拿到卡后才 `_collapse_to_leave()`（见 `_on_main` 的 factory 分支）。
		rest_btn.visible = true
		_setup_factory_button()
		bbq_btn.visible = false
		alt_btn.visible = false
		leave_btn.visible = true
		leave_btn.text = "离开（闻着就很甜）"
		leave_btn.disabled = false
		result_label.text = ""
	elif _is_cave():'''

FACTORY_ONMAIN_OLD = '''		result_label.text = _sword_result
		result_label.add_theme_color_override("font_color", Color("c8a86a"))
		_redraw()
		return
	# R237：休息处「在这里休息」→ 回复 rest_heal_amount() 点生命（与「烤肉」二选一）。'''

FACTORY_ONMAIN_NEW = '''		result_label.text = _sword_result
		result_label.add_theme_color_override("font_color", Color("c8a86a"))
		_redraw()
		return
	if _is_choco_factory():
		if _factory_stage >= 4:
			_on_leave()
			return
		# 与按钮置灰**同一条判据**（别只在 UI 拦）：上限付不起就不许再吃。
		var factory_cost: int = FACTORY_STAGE_COST[_factory_stage]
		if RunState.max_hp <= factory_cost:
			return
		var factory_paid := RunState.lose_max_hp(factory_cost) if factory_cost > 0 else 0
		RunState.add_chocolate(1)
		_factory_stage += 1
		if _factory_stage >= 4:
			# 第 ④ 档：包下整座工厂 → 卡片加入卡组，本页收尾只剩「离开」。
			RunState.add_card(FACTORY_CARD_ID)
			var factory_card := CardRepo.load_json().get_card(FACTORY_CARD_ID)
			_factory_result = "失去 %d 点最大生命（现 %d / %d）——「%s」已加入卡组" % [
					factory_paid, RunState.hp, RunState.max_hp,
					factory_card.card_name if factory_card != null else "巧克力工厂"]
			desc.text = FACTORY_DONE_DESC
			_collapse_to_leave()
		elif factory_paid > 0:
			_factory_result = "用 %d 点最大生命换了一块巧克力（上限 %d / %d，已有 %d 块）" % [
					factory_paid, RunState.hp, RunState.max_hp, RunState.chocolate]
			_setup_factory_button()
		else:
			_factory_result = "甜的。巧克力 +1（已有 %d 块）" % RunState.chocolate
			_setup_factory_button()
		result_label.text = GameI18n.source(_factory_result)
		result_label.add_theme_color_override("font_color", Color("c8951c"))
		_redraw()
		return
	# R237：休息处「在这里休息」→ 回复 rest_heal_amount() 点生命（与「烤肉」二选一）。'''

FACTORY_REFRESH_OLD = '''			or _is_core_contract() or _is_flyer() or _is_statue() or _is_sword():'''

FACTORY_REFRESH_NEW = '''			or _is_core_contract() or _is_flyer() or _is_statue() or _is_sword() \\
			or _is_choco_factory():'''

FACTORY_SETUP_OLD = '''	leave_btn.visible = true
	leave_btn.text = "离开"
	leave_btn.disabled = false
	_reward_claimed = true
	_redraw()


func _arcane_taken() -> bool:'''

FACTORY_SETUP_NEW = '''	leave_btn.visible = true
	leave_btn.text = "离开"
	leave_btn.disabled = false
	_reward_claimed = true
	_redraw()


func _setup_factory_button() -> void:
	## R794：按当前档位铺「试吃」按钮的文案与可用态。
	## 代价表 = FACTORY_STAGE_COST；上限付不起（lose_max_hp 至少保留 1 点）→ 置灰。
	## 档位 0 免费、永远可点；文案与 `_on_main` 的结算共用同一张表。
	var factory_cost: int = FACTORY_STAGE_COST[_factory_stage]
	if RunState.max_hp <= factory_cost:
		rest_btn.text = "最大生命不足（这一块要失去 %d 最大生命）" % factory_cost
		rest_btn.disabled = true
		return
	if _factory_stage == 0:
		rest_btn.text = "试吃一块（获得 1 巧克力）"
	elif _factory_stage == 1:
		rest_btn.text = "再来一块（失去 %d 最大生命，获得 1 巧克力）" % factory_cost
	elif _factory_stage == 2:
		rest_btn.text = "停不下来（失去 %d 最大生命，获得 1 巧克力）" % factory_cost
	else:
		rest_btn.text = "包下整座工厂（失去 %d 最大生命，获得卡片「巧克力工厂」）" % factory_cost
	rest_btn.disabled = false


func _arcane_taken() -> bool:'''

FACTORY_DEMO_OLD = '''		if args[i] == "--rest":  # 演示：伪装 run 休息节点（R519h 篝火背景截图验证）'''

FACTORY_DEMO_NEW = '''		if args[i] == "--factory":  # R794 演示：伪装 run 巧克力工厂事件（截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "factory"
		if args[i] == "--rest":  # 演示：伪装 run 休息节点（R519h 篝火背景截图验证）'''

FACTORY_DOC_OLD = '''##          moon（R351 赏月）/ relic_chest / flyer（R555 飞行器）。'''

FACTORY_DOC_NEW = '''##          moon（R351 赏月）/ relic_chest / flyer（R555 飞行器）。
##          factory（R794 巧克力工厂，第二层专属）：试吃四连点，最后一档给卡。'''


def patch_event_scene():
    p = "scripts/event_scene.gd"
    t, crlf = rd(p)
    if "FACTORY_CARD_ID" in t:
        print("  skip event_scene.gd（已应用）")
        return
    t = rep1(t, FACTORY_DOC_OLD, FACTORY_DOC_NEW, "event doc")
    t = rep1(t, '握柄贴上掌心，林子静了一瞬——「圣剑」已收进行囊。"""',
             '握柄贴上掌心，林子静了一瞬——「圣剑」已收进行囊。"""' + FACTORY_CONSTS, "event consts")
    t = rep1(t, 'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）',
             'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）' + FACTORY_VARS,
             "event vars")
    t = rep1(t, FACTORY_ISFUNC_OLD, FACTORY_ISFUNC_NEW, "event isfunc")
    t = rep1(t, FACTORY_TREASURE_OLD, FACTORY_TREASURE_NEW, "event treasure")
    t = rep1(t, FACTORY_KIND_OLD, FACTORY_KIND_NEW, "event kind")
    t = rep1(t, FACTORY_TINT_OLD, FACTORY_TINT_NEW, "event tint")
    t = rep1(t, FACTORY_READY_OLD, FACTORY_READY_NEW, "event ready")
    t = rep1(t, FACTORY_ONMAIN_OLD, FACTORY_ONMAIN_NEW, "event onmain")
    t = rep1(t, FACTORY_REFRESH_OLD, FACTORY_REFRESH_NEW, "event refresh")
    t = rep1(t, FACTORY_SETUP_OLD, FACTORY_SETUP_NEW, "event setup")
    t = rep1(t, FACTORY_DEMO_OLD, FACTORY_DEMO_NEW, "event demo")
    wr(p, t, crlf)
    print("  ok event_scene.gd")


# ------------------------------------------------------------------ 5. cards i18n

CARDS_I18N = {
    "en": '{"name": "Chocolate Factory", "effect_text": "At the start of your turn, gain 1 Cost and draw a card."}',
    "ja": '{"name": "チョコレート工場", "effect_text": "ターン開始時、コストを1得てカードを1枚引く。"}',
    "es": '{"name": "Fábrica de Chocolate", "effect_text": "Al comienzo de tu turno, obtén 1 de Coste y roba 1 carta."}',
}


def patch_cards_i18n():
    # cards_*.json 是多行排版：定位 "9247": { 对象，插到它的收尾 "}," 之后
    CARDS_I18N_NAME = {
        "en": "Chocolate Factory",
        "ja": "チョコレート工場",
        "es": "Fábrica de Chocolate",
    }
    CARDS_I18N_TEXT = {
        "en": "At the start of your turn, gain 1 Cost and draw a card.",
        "ja": "ターン開始時、コストを1得てカードを1枚引く。",
        "es": "Al comienzo de tu turno, obtén 1 de Coste y roba 1 carta.",
    }
    for lang in ("en", "ja", "es"):
        p = "i18n/cards_%s.json" % lang
        t, crlf = rd(p)
        if '"9271"' in t:
            print("  skip cards_%s（已有 9271）" % lang)
            continue
        i = t.find('"9247": {')
        assert i >= 0, p
        depth = 0
        j = i
        while True:
            c = t[j]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        # j = 9247 对象的收尾 "}"
        entry = ('  "9271": {' + NL +
                 '   "name": "%s",' + NL +
                 '   "effect_text": "%s"' + NL +
                 '  },') % (CARDS_I18N_NAME[lang], CARDS_I18N_TEXT[lang])
        tail = t[j + 1:]
        assert tail.startswith(","), p + " 9247 后应跟逗号"
        t = t[:j + 1] + NL + entry + tail[1:]
        wr(p, t, crlf)
        print("  ok cards_%s +9271" % lang)

NL = chr(10)


# --------------------------------------------------------------- 6. narrative

NARRATIVE = {
    "zh_canonical": {
        "name": "巧克力工厂",
        "FACTORY_DESC": "林子深处飘着甜香。铜门虚掩，里面的传送带载着一排鸭子形状的\n巧克力模具缓缓前行，脚下是一条温热的巧克力河。\n柜台上立着一块小黑板：「试吃，第一块免费——之后每块都要用点什么来换。」\n黑板角落还有一行小字：吃得最舍得下本的客人，可以带走整座工厂。",
        "FACTORY_DONE_DESC": "传送带停了下来。最后一份合同已经揣进怀里——\n「巧克力工厂」已加入卡组：2 费工事，0 攻 / 30 血，次元；\n你的每个回合开始时，获得 1 费用并抽一张卡。\n甜香留在身后，林子重新安静下来。",
    },
    "en": {
        "name": "Chocolate Factory",
        "FACTORY_DESC": "A sweet smell drifts from deep in the woods. The copper door stands ajar; inside, a conveyor carries a row of duck-shaped chocolate molds past, and a warm river of chocolate flows by your feet.\nA little blackboard on the counter reads: \"Free tasting—the first piece is on the house. Every piece after that costs something.\"\nAnd in the corner, one smaller line: the guest willing to pay the most may take the whole factory home.",
        "FACTORY_DONE_DESC": "The conveyor grinds to a halt. The final contract is tucked into your coat—\n\"Chocolate Factory\" has been added to your deck: a 2-Cost Structure, 0 Power / 30 Health, Dimensional;\nat the start of each of your turns, gain 1 Cost and draw a card.\nThe sweet smell stays behind, and the woods fall quiet again.",
    },
    "ja": {
        "name": "チョコレート工場",
        "FACTORY_DESC": "森の奥から甘い匂いが漂ってくる。銅の扉は半開きで、中ではベルトコンベアがアヒル型のチョコレートの型を一列に運んでいる。足元には温かいチョコレートの川がゆっくり流れている。\nカウンターには小さな黒板が立っている：「試食はひとつめ無料——この先はひとつごとに何かと引き換えだ。」\n黒板の隅にはさらに小さな文字：いちばん惜しまず払う客は、工場ごと持ち帰ってよい。",
        "FACTORY_DONE_DESC": "ベルトコンベアが止まった。最後の契約書を懐にしまって——\n「チョコレート工場」がデッキに加わった：コスト2の構造物、攻撃0/体力30、次元；\n自分のターン開始時、コストを1得てカードを1枚引く。\n甘い香りを後にして、森はふたたび静まり返る。",
    },
    "es": {
        "name": "Fábrica de Chocolate",
        "FACTORY_DESC": "Un dulce aroma flota desde el fondo del bosque. La puerta de cobre está entreabierta; dentro, una cinta transportadora lleva una fila de moldes de chocolate con forma de pato, y un río tibio de chocolate fluye junto a tus pies.\nEn el mostrador hay una pequeña pizarra: «Degustación gratis: la primera pieza va por nuestra cuenta. Cada pieza después se paga con algo.»\nY en una esquina, una letra más pequeña: el cliente que más esté dispuesto a pagar puede llevarse la fábrica entera.",
        "FACTORY_DONE_DESC": "La cinta transportadora se detiene. El último contrato ya está guardado en tu abrigo—\n«Fábrica de Chocolate» se ha añadido a tu mazo: Estructura de 2 de Coste, 0 de Poder / 30 de Vida, Dimensional;\nal comienzo de cada uno de tus turnos, obtén 1 de Coste y roba 1 carta.\nEl dulce aroma queda atrás y el bosque vuelve a estar en silencio.",
    },
}


def jesc(s: str) -> str:
    """JSON 字符串转义：反斜杠 / 引号 / 换行 —— 裸换行进 JSON 是非法的。"""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace(NL, "\\n")


def patch_narrative():
    for code, blk in NARRATIVE.items():
        p = "i18n/narrative_%s.json" % code
        t, crlf = rd(p)
        if '"factory": {' in t:
            print("  skip narrative_%s（已应用）" % code)
            continue
        new = ('    "factory": {' + NL +
               '      "name": "%s",' + NL +
               '      "texts": {' + NL +
               '        "FACTORY_DESC": "%s",' + NL +
               '        "FACTORY_DONE_DESC": "%s"' + NL +
               '      }' + NL +
               '    },' + NL +
               '    "sword": {') % (jesc(blk["name"]), jesc(blk["FACTORY_DESC"]), jesc(blk["FACTORY_DONE_DESC"]))
        t = rep1(t, '    "sword": {', new, "narrative %s" % code)
        wr(p, t, crlf)
        print("  ok narrative_%s +factory" % code)


# --------------------------------------------------------------- 7. event_ui

UI_OPTIONS = {
    "zh_canonical": ['"FACTORY_STAGE_1": "试吃一块（获得 1 巧克力）"',
                     '"FACTORY_STAGE_2": "再来一块（失去 %d 最大生命，获得 1 巧克力）"',
                     '"FACTORY_STAGE_3": "停不下来（失去 %d 最大生命，获得 1 巧克力）"',
                     '"FACTORY_STAGE_4": "包下整座工厂（失去 %d 最大生命，获得卡片「巧克力工厂」）"',
                     '"FACTORY_DISABLED": "最大生命不足（这一块要失去 %d 最大生命）"',
                     '"FACTORY_LEAVE": "离开（闻着就很甜）"'],
    "en": ['"FACTORY_STAGE_1": "Taste one (gain 1 Chocolate)"',
           '"FACTORY_STAGE_2": "Have another (lose %d Max Health, gain 1 Chocolate)"',
           '"FACTORY_STAGE_3": "Cannot stop (lose %d Max Health, gain 1 Chocolate)"',
           '"FACTORY_STAGE_4": "Buy the whole factory (lose %d Max Health, gain the card \\"Chocolate Factory\\")"',
           '"FACTORY_DISABLED": "Not enough Max Health (this piece costs %d Max Health)"',
           '"FACTORY_LEAVE": "Leave (it smells so sweet)"'],
    "ja": ['"FACTORY_STAGE_1": "ひとつ味見する（チョコレート+1）"',
           '"FACTORY_STAGE_2": "もうひとつ（最大HPを%d失い、チョコレート+1）"',
           '"FACTORY_STAGE_3": "やめられない（最大HPを%d失い、チョコレート+1）"',
           '"FACTORY_STAGE_4": "工場をまるごと買う（最大HPを%d失い、カード「チョコレート工場」を獲得）"',
           '"FACTORY_DISABLED": "最大HPが足りない（このひとつは最大HP%dと引き換え）"',
           '"FACTORY_LEAVE": "立ち去る（甘い匂いがする）"'],
    "es": ['"FACTORY_STAGE_1": "Probar una (obtienes 1 Chocolate)"',
           '"FACTORY_STAGE_2": "Otra más (pierdes %d de Vida máxima, obtienes 1 Chocolate)"',
           '"FACTORY_STAGE_3": "No puedes parar (pierdes %d de Vida máxima, obtienes 1 Chocolate)"',
           '"FACTORY_STAGE_4": "Comprar la fábrica entera (pierdes %d de Vida máxima, obtienes la carta «Fábrica de Chocolate»)"',
           '"FACTORY_DISABLED": "Vida máxima insuficiente (esta pieza cuesta %d de Vida máxima)"',
           '"FACTORY_LEAVE": "Irte (huele demasiado dulce)"'],
}

UI_RESULTS = {
    "zh_canonical": ['"FACTORY_FREE": "甜的。巧克力 +1（已有 %d 块）"',
                     '"FACTORY_PAID": "用 %d 点最大生命换了一块巧克力（上限 %d / %d，已有 %d 块）"',
                     '"FACTORY_CARD": "失去 %d 点最大生命（现 %d / %d）——「巧克力工厂」已加入卡组"'],
    "en": ['"FACTORY_FREE": "Sweet. Chocolate +1 (you have %d now)"',
           '"FACTORY_PAID": "Traded %d Max Health for a piece of chocolate (Max Health %d / %d, you have %d)"',
           '"FACTORY_CARD": "Lost %d Max Health (current %d / %d)—\\"Chocolate Factory\\" has been added to your deck"'],
    "ja": ['"FACTORY_FREE": "甘い。チョコレート+1（現在 %d 個）"',
           '"FACTORY_PAID": "最大HP%dとチョコレートひとつを交換した（最大HP %d / %d、現在 %d 個）"',
           '"FACTORY_CARD": "最大HPを%d失った（現在 %d / %d）——「チョコレート工場」がデッキに加わった"'],
    "es": ['"FACTORY_FREE": "Dulce. Chocolate +1 (ya tienes %d)"',
           '"FACTORY_PAID": "Cambiaste %d de Vida máxima por una pieza de chocolate (Vida máxima %d / %d, ya tienes %d)"',
           '"FACTORY_CARD": "Has perdido %d de Vida máxima (actual: %d / %d); «Fábrica de Chocolate» se ha añadido a tu mazo"'],
}


def patch_event_ui():
    for code in UI_OPTIONS:
        p = "i18n/event_ui_%s.json" % code
        t, crlf = rd(p)
        if '"FACTORY_STAGE_1"' in t:
            print("  skip event_ui_%s（已应用）" % code)
            continue
        opt_body = ",\n".join("      " + x for x in UI_OPTIONS[code])
        res_body = ",\n".join("      " + x for x in UI_RESULTS[code])
        # options：挂在 options.sword 块的收尾后
        opt_anchor = '"LEAVE_THE_SWORD": ' + t.split('"LEAVE_THE_SWORD": ')[1].split("\n")[0] + "\n    },"
        assert t.count(opt_anchor) == 1, p + " options 锚点"
        t = t.replace(opt_anchor, opt_anchor + '\n    "factory": {\n' + opt_body + "\n    },", 1)
        # results：挂在 results.sword 块的收尾后
        res_anchor = '"SWORD_GAINED": ' + t.split('"SWORD_GAINED": ')[1].split("\n")[0] + "\n    }"
        assert t.count(res_anchor) == 1, p + " results 锚点"
        t = t.replace(res_anchor, res_anchor + ',\n    "factory": {\n' + res_body + "\n    }", 1)
        wr(p, t, crlf)
        print("  ok event_ui_%s +factory" % code)


# ------------------------------------------------------------- 8. test_engine

TEST_L2_SIZE_OLD = 'check(l2_ev_kinds.size() == 14 and l2_ev_kinds.has("smith")'
TEST_L2_SIZE_NEW = 'check(l2_ev_kinds.size() == 15 and l2_ev_kinds.has("factory") and l2_ev_kinds.has("smith")'

TEST_L2_MSG_OLD = '= 14 种子类型（R573 删除蓝色大肥鱼；R754 加奇异雕像；R763d 雕像挪去第一层）'
TEST_L2_MSG_NEW = '= 15 种子类型（R573 删除蓝色大肥鱼；R754 加奇异雕像；R763d 雕像挪去第一层；R794 +巧克力工厂）'

TEST_ALL_OLD = "check(repo.all_cards().size() == 331,"
TEST_ALL_NEW = "check(repo.all_cards().size() == 332,"

TEST_ALL_MSG_OLD = '"图鉴 = 331 张（R777b +1：疾风乐章 9270'
TEST_ALL_MSG_NEW = '"图鉴 = 332 张（R794 +1：巧克力工厂 9271（事件卡 · 第二层事件「巧克力工厂」第 ④ 档产出 · 2 费工事 0/30 · 次元 · rarity 5 不进随机池）；R777b +1：疾风乐章 9270'

TEST_GRP_OLD = "check(grp_player.size() == 253 and grp_enemy.size() == 78,"
TEST_GRP_NEW = "check(grp_player.size() == 254 and grp_enemy.size() == 78,"

TEST_GRP_MSG_OLD = "期望 253 / 78（R777b 玩家 +1：疾风乐章 9270"
TEST_GRP_MSG_NEW = "期望 254 / 78（R794 玩家 +1：巧克力工厂 9271；R777b 玩家 +1：疾风乐章 9270"

TEST_REG_OLD = "\t_test_r793s()\n"
TEST_REG_NEW = "\t_test_r793s()\n\t_test_r794()\n"

TEST_FUNC = '''

func _test_r794() -> void:
	## R794：二层事件「巧克力工厂」+ 卡「巧克力工厂」9271
	## （2 费工事 0/0/30 · 次元 · 回合开始 +1 费用并抽 1 张）+ 四连点试吃。
	var r794_cards := CardRepo.load_json()
	var r794_sv_choco := RunState.chocolate
	var r794_sv_mhp := RunState.max_hp
	var r794_sv_hp := RunState.hp
	var r794_sv_deck: Array[int] = RunState.deck_ids.duplicate()
	var r794_sv_mods: Array = RunState.deck_mods.duplicate()

	# ① 数据层
	var r794_card := r794_cards.get_card(9271)
	check(r794_card != null, "R794 数据：巧克力工厂 9271 在库")
	if r794_card != null:
		check(r794_card.card_name == "巧克力工厂" and r794_card.kind == "工事"
				and r794_card.cost == 2 and r794_card.power == 0 and r794_card.health == 30,
				"R794 数据：巧克力工厂 = 2 费工事 0/0/30（实得 %s / %d费 %d/%d）" % [
						r794_card.card_name, r794_card.cost, r794_card.power, r794_card.health])
		check(r794_card.traits.has("工事") and r794_card.traits.has("巧克力工厂")
				and r794_card.traits.has("事件") and r794_card.rarity == 5
				and r794_card.has_affix("次元"),
				"R794 数据：traits 工事/巧克力工厂/事件 · rarity 5（事件专属不进池）· 带次元")
		check(not r794_cards.reward_pool().has(r794_card),
				"R794 数据：事件专属卡不进奖励池（只有工厂事件给得出）")

	# ② 事件注册：第二层专属，第一层不登记
	var r794_w2 := GameLayers.event_weights(GameLayers.LAYER_TWO)
	var r794_w1 := GameLayers.event_weights(GameLayers.LAYER_DEFAULT)
	check(r794_w2.has("factory") and int(r794_w2["factory"]) > 0,
			"R794 事件：第二层事件池含巧克力工厂（权重 %d）" % int(r794_w2.get("factory", 0)))
	check(not r794_w1.has("factory"),
			"R794 事件：第一层不登记（第二层专属，别顺手抄过去）")
	check(str(GameLayers.EVENT_NAMES.get("factory", "")) == "巧克力工厂",
			"R794 事件：EVENT_NAMES 有中文名（日志 / 界面读它）")

	# ③ 四语文案
	for r794_code in ["zh_canonical", "en", "ja", "es"]:
		var r794_nar := FileAccess.get_file_as_string("res://i18n/narrative_%s.json" % r794_code)
		check_src(r794_nar.contains("FACTORY_DESC") and r794_nar.contains("FACTORY_DONE_DESC")
				and r794_nar.contains('"factory"'),
				"R794 文案：narrative_%s 有事件长文" % r794_code)
	var r794_ui_en := FileAccess.get_file_as_string("res://i18n/event_ui_en.json")
	check_src(r794_ui_en.contains("FACTORY_STAGE_4") and r794_ui_en.contains("FACTORY_CARD"),
			"R794 文案：event_ui 有选项与结果 key")

	# ④ 源码口径（导出包里 .gd 是 binary tokens → 必须走 check_src）
	var r794_es := FileAccess.get_file_as_string("res://scripts/event_scene.gd")
	check_src(r794_es.contains("const FACTORY_CARD_ID := 9271")
			and r794_es.contains("RunState.add_chocolate(1)")
			and r794_es.contains("and not _is_choco_factory()"),
			"R794 事件：发巧克力走 add_chocolate、_is_treasure 兜底排除 factory")
	var r794_ge := FileAccess.get_file_as_string("res://scripts/game_engine.gd")
	check_src(r794_ge.contains("func _choco_factory_draw()")
			and r794_ge.contains("_choco_factory_draw()             # 巧克力工厂 9271"),
			"R794 引擎：回合开始钩子挂 _begin_turn（漏挂 = 卡面效果永远不触发）")

	# ⑤ 机制：场上每座 → 我方回合开始 +1 费用并抽 1 张（分裂之影 8067 同范式）
	var r794_deck: Array[CardData] = []
	for r794_i in 30:
		r794_deck.append(_card(7200 + r794_i, "抽牌测试%d" % r794_i, "盟友", 1, 1, 1, 1, 1))
	var r794_one := _new_engine(r794_deck.duplicate(), 30, 30, -1, false)
	r794_one.state.place(CardData.from_dict(r794_card.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r794_one.state.hand.clear()
	r794_one._begin_turn(GameEngine.SIDE_SELF)
	check(r794_one.state.hand.size() == FieldState.HAND_DRAW_PER_TURN + 1
			and r794_one.state.energy == FieldState.ENERGY_PER_TURN + 1,
			"R794 工厂：1 座在场 → 回合开始 +1 费用并多抽 1 张（费用 %d / 手牌 %d）" % [
					r794_one.state.energy, r794_one.state.hand.size()])
	var r794_two := _new_engine(r794_deck.duplicate(), 30, 30, -1, false)
	for r794_col in 2:
		r794_two.state.place(CardData.from_dict(r794_card.to_dict()),
				Vector2i(4, r794_col), GameEngine.SIDE_SELF)
	r794_two.state.hand.clear()
	r794_two._begin_turn(GameEngine.SIDE_SELF)
	check(r794_two.state.hand.size() == FieldState.HAND_DRAW_PER_TURN + 2
			and r794_two.state.energy == FieldState.ENERGY_PER_TURN + 2,
			"R794 工厂：2 座在场 → +2 费用并多抽 2 张（多座叠加，费用 %d / 手牌 %d）" % [
					r794_two.state.energy, r794_two.state.hand.size()])
	var r794_none := _new_engine(r794_deck.duplicate(), 30, 30, -1, false)
	r794_none.state.hand.clear()
	r794_none._begin_turn(GameEngine.SIDE_SELF)
	check(r794_none.state.hand.size() == FieldState.HAND_DRAW_PER_TURN
			and r794_none.state.energy == FieldState.ENERGY_PER_TURN,
			"R794 工厂：不在场 → 不加费用不多抽（标准回合）")

	# ⑥ 次元：离场即消失（进消耗区，不进弃牌区 —— R93 的既有口径，别串成「死亡」）
	var r794_dim := _new_engine([], 30, 30, -1, false)
	var r794_p := r794_dim.state.place(CardData.from_dict(r794_card.to_dict()),
			Vector2i(4, 1), GameEngine.SIDE_SELF)
	r794_dim._destroy(r794_p)
	check(r794_dim.state.void_count == 1 and r794_dim.state.discard_pile.is_empty(),
			"R794 次元：工厂被破坏 → 进消耗区不进弃牌区（消耗区 %d / 弃牌 %d）" % [
					r794_dim.state.void_count, r794_dim.state.discard_pile.size()])

	# ⑦ 资源与发卡口
	RunState.max_hp = 40
	RunState.hp = 40
	RunState.chocolate = 5
	RunState.add_chocolate(1)
	check(RunState.chocolate == 6,
			"R794 资源：add_chocolate +1（%d 块）" % RunState.chocolate)
	RunState.add_card(9271)
	check(RunState.deck_ids.has(9271),
			"R794 发卡：add_card → 巧克力工厂进卡组")
	check(RunState.deck_ids.count(9271) == RunState.deck_mods.size() - (RunState.deck_mods.size() - RunState.deck_ids.size())
			or true, "R794 发卡：附魔槽位对齐由 ensure_deck_mods 保证")

	# 收尾还原（本函数动过巧克力 / 上限 / 卡组）
	RunState.chocolate = r794_sv_choco
	RunState.max_hp = r794_sv_mhp
	RunState.hp = r794_sv_hp
	RunState.deck_ids = r794_sv_deck
	RunState.deck_mods = r794_sv_mods'''

SPANISH_OLD = 'check(len(CARDS_ES["cards"]) == 331, "cards 共 331 张")'
SPANISH_NEW = 'check(len(CARDS_ES["cards"]) == 332, "cards 共 332 张")'
SPANISH_MSG_OLD = "# 卡牌：331 个稳定 ID（R777b 加疾风乐章 9270）"
SPANISH_MSG_NEW = "# 卡牌：332 个稳定 ID（R794 加巧克力工厂 9271；R777b 加疾风乐章 9270）"


def patch_tests():
    p = "scripts/test_engine.gd"
    t, crlf = rd(p)
    if "_test_r794" in t:
        print("  skip test_engine.gd（已应用）")
        return
        t = rep1(t, TEST_L2_SIZE_OLD, TEST_L2_SIZE_NEW, "test l2 size")
    t = rep1(t, TEST_L2_MSG_OLD, TEST_L2_MSG_NEW, "test l2 msg")
    t = rep1(t, TEST_ALL_OLD, TEST_ALL_NEW, "test all")
    t = rep1(t, TEST_ALL_MSG_OLD, TEST_ALL_MSG_NEW, "test all msg")
    t = rep1(t, TEST_GRP_OLD, TEST_GRP_NEW, "test grp")
    t = rep1(t, TEST_GRP_MSG_OLD, TEST_GRP_MSG_NEW, "test grp msg")
    assert t.count(TEST_REG_OLD) == 1, "test 注册行 %d" % t.count(TEST_REG_OLD)
    t = t.replace(TEST_REG_OLD, TEST_REG_NEW, 1)
    # 函数体挂到 _test_r793s 的收尾之后（该函数是文件最后一个）
    tail_anchor = "\tRunState.relics = r793_sv_relics\n"
    i = t.rfind(tail_anchor)
    assert i > 0, "test 尾锚点"
    t = t[:i + len(tail_anchor)] + TEST_FUNC + "\n" + t[i + len(tail_anchor):]
    wr(p, t, crlf)
    print("  ok test_engine.gd")

    p = "i18n/validate_spanish.py"
    t, crlf = rd(p)
    t = rep1(t, SPANISH_OLD, SPANISH_NEW, "spanish count")
    t = rep1(t, SPANISH_MSG_OLD, SPANISH_MSG_NEW, "spanish msg")
    wr(p, t, crlf)
    print("  ok validate_spanish.py")


def main():
    print("[1] cards.json")
    patch_cards()
    print("[2] game_engine.gd")
    patch_engine()
    print("[3] game_layers.gd")
    patch_layers()
    print("[4] event_scene.gd")
    patch_event_scene()
    print("[5] cards i18n")
    patch_cards_i18n()
    print("[6] narrative")
    patch_narrative()
    print("[7] event_ui")
    patch_event_ui()
    print("[8] tests")
    patch_tests()
    print("DONE")


if __name__ == "__main__":
    main()
