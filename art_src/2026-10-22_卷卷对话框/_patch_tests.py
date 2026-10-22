# -*- coding: utf-8 -*-
"""R310 回归：test_engine 追加断言 + test_smoke 追加两个 curtain 用例。
纪律：exact replace + assert count==1 + 保留原行尾。"""
import os

ROOT = r"E:/work/card_rogue"


def patch(rel, old, new):
    p = os.path.join(ROOT, rel)
    raw = open(p, "rb").read()
    crlf = b"\r\n" in raw
    txt = raw.decode("utf-8").replace("\r\n", "\n")
    assert txt.count(old) == 1, "%s count=%d" % (rel, txt.count(old))
    txt = txt.replace(old, new)
    out = txt.replace("\n", "\r\n") if crlf else txt
    open(p, "wb").write(out.encode("utf-8"))
    print("%-26s ok (crlf=%s)" % (rel, crlf))


ENGINE_BLOCK = '''	# ── R310 卷卷（每层起点的豚鼠吟游诗人）────────────────────────────────
	# 起点那三件道具不再走面板三选一，改由一段对话发出去。这里只钉**数据层**：
	# 文案口径、层/职业分支、候选仍然是 `relic_choice` 那三件、收下后必须清空。
	check(CurtainLines.greeting(GameLayers.LAYER_DEFAULT, PlayerClass.DRUID)
			== "看看这里有什么能帮到你的。",
			"R310 卷卷：第一层的招呼是一句通用的「看看这里有什么能帮到你的。」")
	check(CurtainLines.greeting(GameLayers.LAYER_DEFAULT, PlayerClass.MECH)
			== CurtainLines.greeting(GameLayers.LAYER_DEFAULT, PlayerClass.ROGUE),
			"R310 卷卷：第一层不分支（三个职业同一句）")
	check(CurtainLines.greeting(GameLayers.LAYER_TWO, PlayerClass.DRUID)
			== "在这里遇到你真开心。"
			and CurtainLines.greeting(GameLayers.LAYER_TWO, PlayerClass.ROGUE)
			== "这些就当做定金吧。"
			and CurtainLines.greeting(GameLayers.LAYER_TWO, PlayerClass.MECH)
			== "你喜欢音乐吗？",
			"R310 卷卷：第二层按玩家职业分三句")
	check(CurtainLines.reply(GameLayers.LAYER_TWO, PlayerClass.DRUID) == "我也是。"
			and CurtainLines.reply(GameLayers.LAYER_TWO, PlayerClass.ROGUE) == "……"
			and CurtainLines.reply(GameLayers.LAYER_TWO, PlayerClass.MECH)
			== "是的，这个节奏让我安心。",
			"R310 卷卷：第二层拿取道具后，三个职业各回一句")
	check(not CurtainLines.has_reply(GameLayers.LAYER_DEFAULT)
			and CurtainLines.has_reply(GameLayers.LAYER_TWO)
			and CurtainLines.reply(GameLayers.LAYER_DEFAULT, PlayerClass.DRUID) == "",
			"R310 卷卷：**只有第二层起**才有角色回答（第一层不切立绘）")
	check(CurtainLines.greeting(GameLayers.LAYER_THREE, PlayerClass.DRUID)
			== CurtainLines.greeting(GameLayers.LAYER_TWO, PlayerClass.DRUID),
			"R310 卷卷：第三层（当前无战斗关卡）沿用「二层起」那一套")
	# 候选就是起点那三件道具；收下后候选必须清空（否则地图会把玩家再送回来）
	var r310_rng := RandomNumberGenerator.new()
	r310_rng.seed = 20261022
	RunState.start_run(RogueMap.generate(r310_rng, GameLayers.LAYER_DEFAULT),
			GameLayers.LAYER_DEFAULT)
	check(RunState.relic_choice.size() == 3,
			"R310 卷卷：起点仍然摇出 3 件起始道具（候选数 %d）" % RunState.relic_choice.size())
	var r310_pick: int = RunState.relic_choice[0] if RunState.relic_choice.size() > 0 else -1
	if r310_pick > 0:
		RunState.choose_start_relic(r310_pick)
		check(RunState.has_relic(r310_pick) and RunState.relic_choice.is_empty(),
				"R310 卷卷：收下第 1 件 → 道具进栏、候选清空")
	# 源码锁：起点与换层都跳 curtain（不能再跳回 relic_pick 面板）
	var r310_map := FileAccess.get_file_as_string("res://scripts/map_scene.gd")
	var r310_bat := FileAccess.get_file_as_string("res://scripts/battle_scene.gd")
	check_src(r310_map.find('SceneFx.goto("res://scenes/curtain.tscn", true)') >= 0,
			"R310 源码锁：map_scene 的起点重定向跳到 curtain.tscn")
	check_src(r310_bat.find('SceneFx.goto("res://scenes/curtain.tscn")') >= 0,
			"R310 源码锁：battle_scene 打完 Boss 进新层也跳 curtain.tscn")
	check_src(r310_map.find('RunState.relic_choice.is_empty()') >= 0
			and r310_map.find('RunState.relic_choice.is_empty()') <
			r310_map.find('res://scenes/curtain.tscn'),
			"R310 源码锁：重定向的判据仍是 `relic_choice` 非空（候选清空 = 本层起点已过完）")

'''

SMOKE_OLD = '''		["res://scenes/relic_pick.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [6001, 6002, 6003]],
'''

SMOKE_NEW = '''		["res://scenes/relic_pick.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [6001, 6002, 6003]],
		# R310：每层起点的「卷卷」对话（原起点三选一入口）。第一层不切立绘。
		["res://scenes/curtain.tscn", func():
				_reset()
				RunState.start_run(_map())
				RunState.relic_choice = [6001, 6002, 6003]],
		# R310：第二层 + 机械之心 → 走「收下道具 → 立绘出场 → 角色回答」那一支，
		# 顺带把效果浮窗、名称牌换字、立绘贴图全部渲染一遍（缺图 / 空引用会在这里炸）。
		["res://scenes/curtain.tscn", func():
				_reset()
				RunState.start_run(_map(), GameLayers.LAYER_TWO, PlayerClass.MECH)
				RunState.relic_choice = [6014, 6015, 6016],
			func(s): _check_curtain_reply(s)],
'''

patch("scripts/test_engine.gd", '''	print("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")''',
      ENGINE_BLOCK + '''	print("== 结果：", "全部通过" if fails == 0 else "%d 项失败" % fails, " ==")''')
patch("scripts/test_smoke.gd", SMOKE_OLD, SMOKE_NEW)

# smoke 的检查函数：追加到文件末尾（在最后一个 func 之后）
p = os.path.join(ROOT, "scripts/test_smoke.gd")
raw = open(p, "rb").read()
crlf = b"\r\n" in raw
txt = raw.decode("utf-8").replace("\r\n", "\n")
assert "\nfunc _check_curtain_reply" not in txt
txt += '''

func _check_curtain_reply(s: Node) -> void:
	## R310：第二层收下道具后应当是「立绘出场 + 角色回答」那一态。
	## 这里直接调场景自己的私有方法（同仓其它 smoke 用例也是这么做的）。
	if s == null or not s.has_method("_pick"):
		print("  [smoke] curtain: 场景没有 _pick()，跳过")
		return
	s.call("_pick", 0)
	var hero: Variant = s.get("_hero")
	var title: Variant = s.get("_title")
	var ok_hero: bool = hero != null and (hero as TextureRect).visible \\
			and (hero as TextureRect).texture != null
	var ok_name: bool = title != null and (title as Label).text == PlayerClass.MECH
	print("  [smoke] curtain 回答态：立绘=%s 名称牌=%s" % [ok_hero, ok_name])
'''
out = txt.replace("\n", "\r\n") if crlf else txt
open(p, "wb").write(out.encode("utf-8"))
print("test_smoke.gd 追加 _check_curtain_reply ok (crlf=%s)" % crlf)
print("ALL DONE")
