# -*- coding: utf-8 -*-
"""R842 补丁 ② event_scene.gd：龙石板（dragon_slab）事件。

九个挂点一个都不能漏（R793 林中的剑的清单）：
  doc / 常量 / 场景状态 / `_is_dragon_slab()` / `_is_treasure()` 兜底排除 /
  `_kind()` / `_kind_tint()` / `_ready()` 分支 / `_on_main()` / `_on_alt()` /
  `_refresh()` 白名单 / `--dragonslab` 演示参数。
文件是 LF，按 LF 写回。
"""
import io

P = "E:/work/card_rogue/scripts/event_scene.gd"


def read():
    with io.open(P, "rb") as f:
        return f.read().decode("utf-8")


def write(s):
    with io.open(P, "wb") as f:
        f.write(s.encode("utf-8"))


CONSTS = '''# R842 龙石板（第一层专属）：「雕着龙的土黄石板」——两个选项都是「你认为它是哪种龙」：
#   · 「强力的龙」→ 卡组里一张**盟友 / 工事**吃附魔「力量 +8」（`brawn`，事件独有：
#     视觉沿用商店「伤害 +8」那枚标记，但不进商店、不进随机池）；
#   · 「尊贵的龙」→ 道具「稀有价值」6090：同名卡削到 3 张，**每因此效果删除一张卡**
#     失去 5 点生命；会当场致死时这个选项不可选（按钮置灰 + 结算口再拦一次）。
const DRAGON_SLAB_RELIC_ID := 6090
const DRAGON_ENCHANT_ID := "brawn"

const DRAGON_SLAB_DESC := """荒原上斜插着一块土黄色的石板，比人还高半头。
正面浮雕着一条盘龙，鳞爪被风磨得只剩起伏的轮廓，
唯独龙眼那一小窝金漆没被吹走——太阳一照，像还醒着。
你伸手按上去，石头底下传来一声极轻的呼吸。
它没有开口，像是在等你先说出：它是一条什么样的龙。
「强力的龙」：为一张盟友或工事附魔力量 +8；
「尊贵的龙」：获得道具「稀有价值」——卡组里同名卡最多留 3 张，
多出来的会被随机撕下，每因此效果删除一张卡，失去 5 点生命。
也可以收回手，让这块石板继续站在这里。"""

const DRAGON_SLAB_MIGHT_DESC := """石面上的龙纹亮了一瞬，像有一口气从石头里呼出来。
再抬头时，指尖沾了一层金粉，石板已经裂开一道细缝——
那条龙把力气分了一点给你带着的东西。"""

const DRAGON_SLAB_NOBLE_DESC := """石板从中间裂开，土黄的碎屑簌簌落了一地。
裂口里没有龙，只有一枚打磨得极亮的鳞片，凉得像井水。
你身上那些多余的东西被它一一数过——数到第四件，就撕下来丢进裂缝里。"""

'''

FUNCS = '''func _dragon_targets() -> Array:
	## 「强力的龙」的候选：**还没附魔**的盟友 / 工事（`enchant_ok()` 是资格唯一口）。
	## 返回 [{idx: deck 下标, card: 带附魔 / 本局成长的卡实例}]，顺序 = 卡组顺序。
	var repo := CardRepo.load_json()
	var out: Array = []
	for i in RunState.deck_ids.size():
		var c := RunState.card_with_mod(repo, i)
		if c == null:
			continue
		if not RunState.enchant_ok(DRAGON_ENCHANT_ID, c, i):
			continue
		out.append({"idx": i, "card": c})
	return out


func _dragon_take_might() -> void:
	## 选项 1「强力的龙」：开选卡页挑一张盟友 / 工事 → 附魔「力量 +8」。
	## ⚠️ 走 `PickOverlay` 而不是跳卡组编辑场景：这里只要**一张**、
	##    且候选已经按 `enchant_ok()` 筛过，没必要把整套编辑 UI 搬过来（运送委托同款用法）。
	if _dragon_pick != "":
		_on_leave()
		return
	var elig := _dragon_targets()
	if elig.is_empty():
		return
	_dragon_cards = elig
	var cards: Array = []
	for e in elig:
		cards.append(e["card"])
	if _dragon_overlay == null:
		_dragon_overlay = PickOverlay.new()
		_dragon_overlay.confirmed.connect(_on_dragon_confirmed)
		_dragon_overlay.cancelled.connect(_on_dragon_cancelled)
		add_child(_dragon_overlay)
	_dragon_overlay.open({
		"kind": "dragon_slab",
		"title": "龙石板 · 挑选一张盟友或工事",
		"note": "只能选还没附魔的盟友或工事（每张卡只有一个附魔位）",
		"cards": cards,
		"counts": [],
		"max_sel": 1,
		"min_sel": 1,
		"confirm_label": "附上「力量 +8」",
		"cancel_label": "再想想（收起）",
		"short": "龙石板",
	})


func _on_dragon_cancelled() -> void:
	## 收起选卡页 = 什么都没发生（不写 `_dragon_pick`），事件页可以再点一次或直接离开。
	if _dragon_overlay != null:
		_dragon_overlay.close()


func _on_dragon_confirmed(selected: Array) -> void:
	## 选卡页确认：附魔**当场**烤进那张卡 —— 与商店走同一条 `enchant_deck_card()`。
	if _dragon_pick != "" or selected.is_empty():
		return
	var grid: int = int(selected[0])
	if grid < 0 or grid >= _dragon_cards.size():
		return
	var idx: int = int((_dragon_cards[grid] as Dictionary)["idx"])
	var repo := CardRepo.load_json()
	var before := RunState.card_with_mod(repo, idx)
	if before == null:
		return
	var old_power: int = before.power
	if not RunState.enchant_deck_card(idx, RunState.enchant_mod(DRAGON_ENCHANT_ID)):
		return
	if _dragon_overlay != null:
		_dragon_overlay.close()
	var after := RunState.card_with_mod(repo, idx)
	var new_power: int = (after.power if after != null else old_power + 8)
	_dragon_pick = "might"
	_claim_reward(rest_btn)   # R147：一次访问只领一份
	_collapse_to_leave()
	desc.text = DRAGON_SLAB_MIGHT_DESC
	# R807：结果行**不插卡名**（动态中文会让 en / ja / es 永远回落中文）—— 只写数值。
	_dragon_result = "附魔「力量 +8」已烤进你选的那张卡（力量 %d → %d）" % [old_power, new_power]
	result_label.text = _dragon_result
	result_label.add_theme_color_override("font_color", Color("c8a86a"))
	_redraw()


func _dragon_take_noble() -> void:
	## 选项 2「尊贵的龙」：收道具「稀有价值」→ 同名卡削到 3 张，每因此效果删一张失 5 点生命。
	## ⚠️ 会致死时**不许选**：按钮已置灰，这里再拦一次（R793 的教训：只拦界面 = 没拦）。
	if _dragon_pick != "":
		_on_leave()
		return
	var repo := CardRepo.load_json()
	if RunState.rare_value_lethal(repo):
		return
	var res: Dictionary = RunState.rare_value_prune(repo)
	if not bool(res.get("ok", false)):
		return
	RunState.gain_relic(DRAGON_SLAB_RELIC_ID)
	_dragon_pick = "noble"
	_claim_reward(alt_btn)   # R147
	_collapse_to_leave()
	desc.text = DRAGON_SLAB_NOBLE_DESC
	var deleted: Array = res.get("deleted", [])
	var dmg: int = int(res.get("damage", 0))
	if deleted.is_empty():
		_dragon_result = "「稀有价值」已收进道具栏：没有超过 3 张的同名卡，一张也没撕"
	else:
		_dragon_result = "「稀有价值」已收进道具栏：撕掉 %d 张同名卡，失去 %d 点生命（现 %d / %d）" % [
				deleted.size(), dmg, RunState.hp, RunState.max_hp]
	result_label.text = _dragon_result
	result_label.add_theme_color_override("font_color", Color("b9a06a"))
	_redraw()


'''

PAIRS = [
    # ① doc
    (
        '##   * event + sword    林中的剑（R793，第一层专属）：拔剑 -13 最大生命 → 道具「圣剑」，\n'
        '##                      或转身离开；\n',
        '##   * event + sword    林中的剑（R793，第一层专属）：拔剑 -13 最大生命 → 道具「圣剑」，\n'
        '##                      或转身离开；\n'
        '##   * event + dragon_slab 龙石板（R842，第一层专属）：认为它是「强力的龙」→ 一张盟友 /\n'
        '##                      工事附魔力量 +8；认为它是「尊贵的龙」→ 道具「稀有价值」（同名卡\n'
        '##                      削到 3 张，每因此效果删一张失 5 点生命，会致死时不可选）；\n',
    ),
    # ② 常量
    (
        'const SWORD_TAKEN_DESC := """石头从中间裂开。剑离地的那一刻轻得不像话，\n'
        '像它一直在等你来拿。\n'
        '握柄贴上掌心，林子静了一瞬——「圣剑」已收进行囊。"""\n',
        'const SWORD_TAKEN_DESC := """石头从中间裂开。剑离地的那一刻轻得不像话，\n'
        '像它一直在等你来拿。\n'
        '握柄贴上掌心，林子静了一瞬——「圣剑」已收进行囊。"""\n'
        '\n' + CONSTS,
    ),
    # ③ 场景状态
    (
        'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）\n',
        'var _sword_result := ""         # R793 林中的剑：收尾那行结果（重绘要能复现）\n'
        'var _dragon_pick := ""          # R842 龙石板：本次领了哪一份（"" / "might" / "noble"）\n'
        'var _dragon_result := ""        # R842 龙石板：收尾那行结果（重绘要能复现）\n'
        'var _dragon_cards: Array = []   # R842 龙石板：选卡页网格下标 → deck 下标的映射表\n'
        'var _dragon_overlay: PickOverlay = null  # R842 龙石板：选盟友 / 工事的浮层（懒建）\n',
    ),
    # ④ _is_dragon_slab
    (
        'func _is_sword() -> bool:\n'
        '\t## R793 林中的剑（第一层专属）：拔剑（-13 最大生命 → 道具「圣剑」）/ 离开。\n'
        '\t## 与「挣扎」（-21 当前生命 → 卡「金属龙」）是一对：一个扣血、一个扣上限。\n'
        '\treturn _is_event_node() and _pending_kind() == "sword"\n',
        'func _is_sword() -> bool:\n'
        '\t## R793 林中的剑（第一层专属）：拔剑（-13 最大生命 → 道具「圣剑」）/ 离开。\n'
        '\t## 与「挣扎」（-21 当前生命 → 卡「金属龙」）是一对：一个扣血、一个扣上限。\n'
        '\treturn _is_event_node() and _pending_kind() == "sword"\n'
        '\n'
        '\n'
        'func _is_dragon_slab() -> bool:\n'
        '\t## R842 龙石板（第一层专属）：一块刻着盘龙的土黄石板，你来断定它是哪种龙。\n'
        '\t## 两个选项都给东西（附魔 / 道具），所以必须留「离开」——不然玩家没法什么都不做。\n'
        '\treturn _is_event_node() and _pending_kind() == "dragon_slab"\n',
    ),
    # ⑤ _is_treasure 兜底排除
    (
        '\t\t\tand not _is_flyer() and not _is_statue() and not _is_sword() \\\n',
        '\t\t\tand not _is_flyer() and not _is_statue() and not _is_sword() \\\n'
        '\t\t\tand not _is_dragon_slab() \\\n',
    ),
    # ⑥ _kind()
    (
        '\tif _is_sword():\n'
        '\t\treturn "sword"\n',
        '\tif _is_sword():\n'
        '\t\treturn "sword"\n'
        '\tif _is_dragon_slab():\n'
        '\t\treturn "dragon_slab"\n',
    ),
    # ⑦ _kind_tint
    (
        '\t\t"whisper", "divination", "moon", "arcane", "hero", "statue":\n',
        '\t\t"whisper", "divination", "moon", "arcane", "hero", "statue", "dragon_slab":\n',
    ),
    # ⑧ _ready 分支
    (
        '\telif _is_haunted_house():\n',
        '\telif _is_dragon_slab():\n'
        '\t\tevent_name.text = "龙 石 板"\n'
        '\t\tif _dragon_pick == "might":\n'
        '\t\t\tdesc.text = DRAGON_SLAB_MIGHT_DESC\n'
        '\t\t\t_collapse_to_leave()\n'
        '\t\t\tresult_label.text = _dragon_result\n'
        '\t\t\tresult_label.add_theme_color_override("font_color", Color("c8a86a"))\n'
        '\t\telif _dragon_pick == "noble":\n'
        '\t\t\tdesc.text = DRAGON_SLAB_NOBLE_DESC\n'
        '\t\t\t_collapse_to_leave()\n'
        '\t\t\tresult_label.text = _dragon_result\n'
        '\t\t\tresult_label.add_theme_color_override("font_color", Color("b9a06a"))\n'
        '\t\telse:\n'
        '\t\t\tdesc.text = DRAGON_SLAB_DESC\n'
        '\t\t\t# R842 选项 1：有合格目标才可点（判据与选卡页同源 `_dragon_targets()`）。\n'
        '\t\t\trest_btn.visible = true\n'
        '\t\t\tif _dragon_targets().is_empty():\n'
        '\t\t\t\trest_btn.text = "卡组里没有可附魔的盟友或工事"\n'
        '\t\t\t\trest_btn.disabled = true\n'
        '\t\t\telse:\n'
        '\t\t\t\trest_btn.text = "「强力的龙」：为一张盟友或工事附魔力量 +8"\n'
        '\t\t\t\trest_btn.disabled = false\n'
        '\t\t\t# R842 选项 2：会当场倒下就置灰（店长口径「如果选此选项会立即死亡则不能选」）。\n'
        '\t\t\talt_btn.visible = true\n'
        '\t\t\tif RunState.rare_value_lethal(CardRepo.load_json()):\n'
        '\t\t\t\talt_btn.text = "生命不足（这样选会当场倒下）"\n'
        '\t\t\t\talt_btn.disabled = true\n'
        '\t\t\telse:\n'
        '\t\t\t\talt_btn.text = "「尊贵的龙」：获得「稀有价值」"\n'
        '\t\t\t\talt_btn.disabled = false\n'
        '\t\t\tbbq_btn.visible = false\n'
        '\t\t\tleave_btn.visible = true\n'
        '\t\t\tleave_btn.text = "离开（不碰这块石板）"\n'
        '\t\t\tleave_btn.disabled = false\n'
        '\t\t\tresult_label.text = ""\n'
        '\telif _is_haunted_house():\n',
    ),
    # ⑨ _refresh 白名单
    (
        '\t\t\tor _is_core_contract() or _is_flyer() or _is_statue() or _is_sword() \\\n',
        '\t\t\tor _is_core_contract() or _is_flyer() or _is_statue() or _is_sword() \\\n'
        '\t\t\tor _is_dragon_slab() \\\n',
    ),
    # ⑩ 事件函数（插在 _refresh 之前）
    (
        'func _refresh() -> void:\n',
        FUNCS + 'func _refresh() -> void:\n',
    ),
    # ⑪ _on_main
    (
        'func _on_main() -> void:\n'
        '\t## 主按钮：小宝箱 → 免费转交卡牌奖励（R372）；鸭鸭低语 / 鸭之凝视 → 收下事件道具；\n'
        '\t## 宝箱层 → 开箱获得 1 个随机奖励道具。\n'
        '\t## R224：休息处的「休息」已移除（只剩 bbq_btn 的「烤肉」），不再有休息分支。\n'
        '\tsfx.play("click")\n',
        'func _on_main() -> void:\n'
        '\t## 主按钮：小宝箱 → 免费转交卡牌奖励（R372）；鸭鸭低语 / 鸭之凝视 → 收下事件道具；\n'
        '\t## 宝箱层 → 开箱获得 1 个随机奖励道具。\n'
        '\t## R224：休息处的「休息」已移除（只剩 bbq_btn 的「烤肉」），不再有休息分支。\n'
        '\tsfx.play("click")\n'
        '\tif _is_dragon_slab():\n'
        '\t\tif _dragon_pick != "":\n'
        '\t\t\t_on_leave()\n'
        '\t\t\treturn\n'
        '\t\t_dragon_take_might()\n'
        '\t\treturn\n',
    ),
    # ⑫ _on_alt
    (
        'func _on_alt() -> void:\n'
        '\t## R305 卡片商人 · **随机折价**（第三选项）：随机失去一张非诅咒卡，换 100 金币。\n'
        '\t## R351 赏月也用它当「拿硬币」的按钮。\n'
        '\tsfx.play("click")\n',
        'func _on_alt() -> void:\n'
        '\t## R305 卡片商人 · **随机折价**（第三选项）：随机失去一张非诅咒卡，换 100 金币。\n'
        '\t## R351 赏月也用它当「拿硬币」的按钮。\n'
        '\tsfx.play("click")\n'
        '\tif _is_dragon_slab():\n'
        '\t\tif _dragon_pick != "":\n'
        '\t\t\t_on_leave()\n'
        '\t\t\treturn\n'
        '\t\t_dragon_take_noble()\n'
        '\t\treturn\n',
    ),
    # ⑬ --dragonslab 演示参数
    (
        '\t\tif args[i] == "--sword":  # R793 演示：伪装 run 林中的剑事件（截图验证）\n'
        '\t\t\tRunState.run_active = true\n'
        '\t\t\tRunState.pending_node = {"type": "event"}\n'
        '\t\t\tRunState.pending_event = "sword"\n',
        '\t\tif args[i] == "--sword":  # R793 演示：伪装 run 林中的剑事件（截图验证）\n'
        '\t\t\tRunState.run_active = true\n'
        '\t\t\tRunState.pending_node = {"type": "event"}\n'
        '\t\t\tRunState.pending_event = "sword"\n'
        '\t\tif args[i] == "--dragonslab":  # R842 演示：伪装 run 龙石板事件（截图验证）\n'
        '\t\t\tRunState.run_active = true\n'
        '\t\t\tRunState.pending_node = {"type": "event"}\n'
        '\t\t\tRunState.pending_event = "dragon_slab"\n',
    ),
]


def main():
    s = read()
    assert "\r\n" not in s, "event_scene.gd 应该是 LF"
    for i, (old, new) in enumerate(PAIRS):
        c = s.count(old)
        assert c == 1, "第 %d 条锚点出现 %d 次：%r" % (i + 1, c, old[:70])
        s = s.replace(old, new)
    write(s)
    print("OK event_scene.gd  %d 处" % len(PAIRS))


main()
