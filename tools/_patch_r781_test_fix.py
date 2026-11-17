# -*- coding: utf-8 -*-
"""R781 修正：源码守卫里 `rest_to_battle` 属于 rogue_map.gd，不在 event_scene.gd。"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scripts", "test_engine.gd")

old = (
    '\tvar r781_es := FileAccess.get_file_as_string("res://scripts/event_scene.gd")\r\n'
    '\tcheck_src(r781_es.contains("func _rest_after_pick(") and r781_es.contains("RunState.rest_pick_quota()")\r\n'
    '\t\t\tand r781_es.contains("REST_WARM_NOTE") and r781_es.contains("RunState.rest_to_battle()"),\r\n'
    '\t\t\t"R781 火堆：收尾统一走 _rest_after_pick，且配额 / 换战斗都读 RunState 取数口")\r\n'
).encode("utf-8")

new = (
    '\tvar r781_es := FileAccess.get_file_as_string("res://scripts/event_scene.gd")\r\n'
    '\tvar r781_map_src := FileAccess.get_file_as_string("res://scripts/rogue_map.gd")\r\n'
    '\tcheck_src(r781_es.contains("func _rest_after_pick(") and r781_es.contains("RunState.rest_pick_quota()")\r\n'
    '\t\t\tand r781_es.contains("REST_WARM_NOTE") and r781_map_src.contains("RunState.rest_to_battle()"),\r\n'
    '\t\t\t"R781 火堆：收尾统一走 _rest_after_pick；地图侧只读 RunState.rest_to_battle()")\r\n'
).encode("utf-8")

raw = open(P, "rb").read()
if raw.count(old) != 1:
    sys.exit("[R781-fix] 锚点命中 %d 次" % raw.count(old))
raw = raw.replace(old, new, 1)
open(P, "wb").write(raw)
data = open(P, "rb").read()
crlf = data.count(b"\r\n")
print("[R781-fix] CRLF=%d 裸LF=%d" % (crlf, data.count(b"\n") - crlf))
