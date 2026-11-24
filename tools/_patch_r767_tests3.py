# -*- coding: utf-8 -*-
"""R767 补充：给 _test_r767 加一条「预热链接线锁」（删了不会报错，只会悄悄变卡）。"""
import sys

P = "scripts/test_engine.gd"
raw = open(P, "rb").read()
assert raw.count(b"\r\n") == raw.count(b"\n"), "期望纯 CRLF"
if b"R767 \xe9\xa2\x84\xe7\x83\xad\xe9\x93\xbe" in raw:
    print("已打过，跳过")
    sys.exit(0)

OLD = '''	# 还原
	RunState.daily_fx = r767_sv_fx
	RunState.set_difficulty(r767_sv_diff)
'''.replace("\n", "\r\n").encode("utf-8")

NEW = '''	# ⑩ 接线锁：预热链与转场收口（这两处删掉都不会报错，只会悄悄变回「卡一下」）
	var r767_title_src := FileAccess.get_file_as_string("res://scripts/title_scene.gd")
	var r767_mode_src := FileAccess.get_file_as_string("res://scripts/mode_select_scene.gd")
	var r767_pick_src := FileAccess.get_file_as_string("res://scripts/class_pick_scene.gd")
	var r767_fx_src := FileAccess.get_file_as_string("res://scripts/scene_fx.gd")
	check_src(r767_title_src.contains("SceneWarm.warm_all(")
			and r767_mode_src.contains("SceneWarm.warm_all(")
			and r767_pick_src.contains("SceneWarm.warm_all("),
			"R767 预热链：标题 / 模式选择 / 选人页三处都挂了后台预加载")
	check_src(r767_fx_src.contains("SceneWarm.take(path) as PackedScene")
			and r767_fx_src.contains("_t0 = -1"),
			"R767 转场：优先用预加载成品，且擦入从新场景出现那一帧起表")

	# 还原
	RunState.daily_fx = r767_sv_fx
	RunState.set_difficulty(r767_sv_diff)
'''.replace("\n", "\r\n").encode("utf-8")

if raw.count(OLD) != 1:
    print("锚点异常:", raw.count(OLD))
    sys.exit(1)
raw = raw.replace(OLD, NEW, 1)
open(P, "wb").write(raw)
out = open(P, "rb").read()
print("CRLF ok:", out.count(b"\r\n") == out.count(b"\n"))
