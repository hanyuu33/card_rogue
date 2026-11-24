# -*- coding: utf-8 -*-
"""R753：event_scene.gd 接入事件「奇异雕像」（LF 文件）。"""
p = 'scripts/event_scene.gd'
txt = open(p, 'rb').read().decode('utf-8')
assert txt.count('\r\n') == 0


def rep(old, new):
    global txt
    c = txt.count(old)
    assert c == 1, (c, old[:70])
    txt = txt.replace(old, new, 1)


# ---- 1：常量 + 文案 ----
rep('''# R573：蓝色大肥鱼事件已删除。只留一句旧存档兜底文案，不发任何奖励。
''', '''# R753 奇异雕像（第二层专属）：两个选项 —— 祭拜（接下来三场战斗必定掉落工具）/
# 摧毁（工具栏用「石头」7012 填满；石头 = 拖到敌方单位身上砸 15 点）。
# 雕像本体是**嵌合兽**：狮子的躯干、背上探出的山羊头、尾巴末端盘着的蛇。
# 店长口径「参考真实的嵌合兽图片」——古典嵌合兽就是这三件套，所以文案按构件写，
# 不写「三头怪 / 五头兽」那种二手转述（图上画错一眼就看得出）。
const STATUE_PLEDGE := 3          # 祭拜后必掉工具的战斗场数
const STATUE_DESC := """空地上立着一尊巨大的白石雕像，雨水把它洗得发灰。
狮子的躯干、背上探出的山羊头、尾巴末端盘着的蛇——
你在一本讲嵌合兽的旧册子上见过这个姿势，只是它不该出现在这片林子里。
石缝里全是苔，底座上的字早被磨平了。"""

const STATUE_PRAY_DESC := """你把手按在它冰凉的爪子上，什么也没说。
石头里传来一声很轻的、像是应答的震动——
接下来三场战斗，每次胜利都会从残骸里翻出一件工具。"""

const STATUE_SMASH_DESC := """你抄起一块石头砸向它的前腿。
裂纹从爪子一路爬到山羊头上，整尊雕像塌成一堆白渣——
握得住的那些，正好够塞满你的工具栏。"""

# R573：蓝色大肥鱼事件已删除。只留一句旧存档兜底文案，不发任何奖励。
''')

# ---- 2：_is_statue ----
rep('''func _is_cave() -> bool:
''', '''func _is_statue() -> bool:
	## R753 奇异雕像（第二层专属）：祭拜（接下来三场战斗必掉工具）/ 摧毁（石头填满工具栏）。
	## 两个选项都给东西，但仍留「绕过去」—— 祭拜要付出「接下来三场都得打完」的承诺，
	## 摧毁则会把工具栏占满，玩家有权什么都不做（与「赏月」那种「两样必须拿走一样」不同）。
	return _is_event_node() and _pending_kind() == "statue"


func _is_cave() -> bool:
''')

# ---- 3：_is_treasure 排除 ----
rep('''			and not _is_adventurer() and not _is_furnace() and not _is_core_contract() \\
			and not _is_flyer()
''', '''			and not _is_adventurer() and not _is_furnace() and not _is_core_contract() \\
			and not _is_flyer() and not _is_statue()
''')

# ---- 4：_kind ----
rep('''	if _is_flyer():
		return "flyer"
	if _is_treasure():
		return "treasure"
''', '''	if _is_flyer():
		return "flyer"
	if _is_statue():
		return "statue"
	if _is_treasure():
		return "treasure"
''')

# ---- 5：左右布局 ----
rep('''const SIDE_LAYOUT_KINDS := ["lake_lady", "martial", "rest", "apple_doctor"]
''', '''## R753：`statue` 加入 —— 雕像是个**竖向**主体（柱状 + 背上探出的头），
## 居中卡片正好压在它中段，怎么调都会被盖住；左右布局让它独占左栏、完整可见。
const SIDE_LAYOUT_KINDS := ["lake_lady", "martial", "rest", "apple_doctor", "statue"]
''')

# ---- 6：主题色 ----
rep('''		"whisper", "divination", "moon", "arcane", "hero":
''', '''		"whisper", "divination", "moon", "arcane", "hero", "statue":
''')

# ---- 7：状态变量 ----
rep('''var _fly_result := ""           # R555 飞行器：收尾态那行结果（重绘要能复现）
''', '''var _fly_result := ""           # R555 飞行器：收尾态那行结果（重绘要能复现）
var _statue_pick := ""          # R753 奇异雕像：本次选的是 "pray" / "smash" / 空
var _statue_result := ""        # R753 奇异雕像：收尾那行结果（重绘要能复现）
''')

# ---- 8：_refresh 分支 ----
rep('''	elif _is_cave():
		event_name.text = "洞 穴"
''', '''	elif _is_statue():
		event_name.text = "奇 异 雕 像"
		desc.text = STATUE_PRAY_DESC if _statue_pick == "pray" \\
				else (STATUE_SMASH_DESC if _statue_pick == "smash" else STATUE_DESC)
		if _statue_pick != "":
			_collapse_to_leave()
			result_label.text = _statue_result
			result_label.add_theme_color_override("font_color", Color("c8a86a"))
		else:
			rest_btn.visible = true
			rest_btn.text = "祭拜（接下来三场战斗必定掉落工具）"
			rest_btn.disabled = false
			bbq_btn.visible = false
			alt_btn.visible = true
			alt_btn.text = "摧毁（工具栏用「石头」填满）"
			alt_btn.disabled = false
			leave_btn.visible = true
			leave_btn.text = "绕过去（什么都不做）"
			leave_btn.disabled = false
			result_label.text = ""
	elif _is_cave():
		event_name.text = "洞 穴"
''')

# ---- 9：_on_rest（祭拜） ----
rep('''	if _is_adventurer():
		if _adv_pick != "":
			_on_leave()
			return
''', '''	if _is_statue():
		if _statue_pick != "":
			_on_leave()
			return
		# 唯一口：`RunState.bless_tool_drops()`（取 max，不会被连拜叠成六场）。
		RunState.bless_tool_drops(STATUE_PLEDGE)
		_statue_pick = "pray"
		_claim_reward(rest_btn)
		_collapse_to_leave()
		desc.text = STATUE_PRAY_DESC
		_statue_result = "已祭拜：接下来 %d 场战斗，每次胜利都必定掉落一件工具。" % STATUE_PLEDGE
		result_label.text = _statue_result
		result_label.add_theme_color_override("font_color", Color("8fc0d8"))
		_redraw()
		return
	if _is_adventurer():
		if _adv_pick != "":
			_on_leave()
			return
''')

# ---- 10：_on_alt（摧毁） ----
rep('''	if _is_snow_leopard():
		if _snow_pick != "":
			return
		RunState.add_card(SNOW_LEOPARD_CARD_ID)
''', '''	if _is_statue():
		if _statue_pick != "":
			return
		# 唯一口：只填空槽、不覆盖手里已有的工具（与快送鸭同一条口径）。
		var stones := RunState.fill_toolbar_with_stones()
		_statue_pick = "smash"
		_claim_reward(alt_btn)
		_collapse_to_leave()
		desc.text = STATUE_SMASH_DESC
		if stones > 0:
			_statue_result = "雕像塌了：工具栏里塞进 %d 块「石头」（拖到敌人身上砸 15 点伤害）。" % stones
		else:
			_statue_result = "雕像塌了，可你的工具栏已经满了 —— 碎块只能留在原地。"
		result_label.text = _statue_result
		result_label.add_theme_color_override("font_color", Color("c8a86a"))
		_redraw()
		return
	if _is_snow_leopard():
		if _snow_pick != "":
			return
		RunState.add_card(SNOW_LEOPARD_CARD_ID)
''')

# ---- 11：刷新白名单 ----
rep('''			or _is_core_contract() or _is_flyer():
''', '''			or _is_core_contract() or _is_flyer() or _is_statue():
''')

# ---- 12：演示参数 ----
rep('''		if args[i] == "--apple":  # 演示：伪装 run 苹果与医生事件（R244 截图验证）
''', '''		if args[i] == "--statue":  # 演示：伪装 run 奇异雕像事件（R753 截图验证）
			RunState.run_active = true
			RunState.pending_node = {"type": "event"}
			RunState.pending_event = "statue"
		if args[i] == "--apple":  # 演示：伪装 run 苹果与医生事件（R244 截图验证）
''')

open(p, 'wb').write(txt.encode('utf-8'))
nb = open(p, 'rb').read()
print('lf', nb.count(b'\n'), 'crlf', nb.count(b'\r\n'))
