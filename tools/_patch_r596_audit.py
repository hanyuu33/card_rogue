# -*- coding: utf-8 -*-
"""R596 素材体检口径修正：
① 地图节点 NODE_TYPES 漏了 `boss` —— rogue_map.LINE_TYPES 里有 boss，TYPE_MARKS 有「王」，
   但 map_icons/boss.png 不存在，之前一直没被统计到。
② 事件不再一刀切「缺 event_/side_/bg_」：左右布局只要竖版图，居中布局只要
   「插图或整屏背景」有一个。两者都没有才是「只剩程序化底色」的真缺口。
"""
import io

P = "tools/audit_release_assets.py"
s = io.open(P, encoding="utf-8").read()

# ① 地图节点加 boss
old = 'NODE_TYPES = ["battle", "bigchest", "chest", "elite", "event", "rest", "shop", "start", "unknown"]'
new = ('# R596：补上 boss —— `rogue_map.LINE_TYPES` 里有 boss（首领），TYPE_MARKS 给的是「王」，\n'
       '# 但 map_icons/boss.png 从来没做过，地图上首领节点一直只有汉字。\n'
       'NODE_TYPES = ["battle", "bigchest", "chest", "elite", "event", "rest", "shop", "start",\n'
       '              "unknown", "boss"]')
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)

# ② 事件按布局分类
old_ev = '''ev_missing = {"event": [], "side": [], "bg": []}
for k in kinds:
    if not png_ui("event_" + k):
        ev_missing["event"].append(k)
    if not png_ui("side_" + k):
        ev_missing["side"].append(k)
    if not png_ui("bg_" + k):
        ev_missing["bg"].append(k)
report["events"] = {"kinds": kinds, "missing": ev_missing}'''
new_ev = '''# R596：左右布局只吃竖版图，居中布局吃「插图 or 整屏背景」，分开判才看得清真缺口。
side_layout = re.findall(r'"([a-z_]+)"',
                         src_ev.split("const SIDE_LAYOUT_KINDS := [")[1].split("]")[0])
ev_missing = {"event": [], "side": [], "bg": [],
              "side_no_pic": [], "center_blank": [], "center_no_bg": []}
for k in kinds:
    has_e, has_s, has_b = png_ui("event_" + k), png_ui("side_" + k), png_ui("bg_" + k)
    if not has_e:
        ev_missing["event"].append(k)
    if not has_s:
        ev_missing["side"].append(k)
    if not has_b:
        ev_missing["bg"].append(k)
    if k in side_layout:
        if not has_s:                       # 左右布局没竖版 = 整页没图，真缺
            ev_missing["side_no_pic"].append(k)
    else:
        if not has_e and not has_b:         # 居中布局两种图都没有 = 只剩程序化底色
            ev_missing["center_blank"].append(k)
        elif not has_b:                     # 有 320×240 插图但没整屏背景
            ev_missing["center_no_bg"].append(k)
report["events"] = {"kinds": kinds, "side_layout": side_layout, "missing": ev_missing}'''
assert s.count(old_ev) == 1, s.count(old_ev)
s = s.replace(old_ev, new_ev)

# ③ 汇总行改口径
old_l = '''L.append("事件插图缺 %2d ／ 竖版缺 %2d ／ 背景缺 %2d（kind 共 %d）"
         % (len(ev_missing["event"]), len(ev_missing["side"]), len(ev_missing["bg"]), len(kinds)))'''
new_l = '''L.append("事件（kind 共 %d，左右布局 %d 个）" % (len(kinds), len(side_layout)))
L.append("  ├ 左右布局缺竖版   %d   %s" % (len(ev_missing["side_no_pic"]),
                                          " ".join(ev_missing["side_no_pic"])))
L.append("  ├ 居中·只剩程序化底 %d   %s" % (len(ev_missing["center_blank"]),
                                           " ".join(ev_missing["center_blank"])))
L.append("  └ 居中·有插图无整屏bg %d   %s" % (len(ev_missing["center_no_bg"]),
                                             " ".join(ev_missing["center_no_bg"])))'''
assert s.count(old_l) == 1, s.count(old_l)
s = s.replace(old_l, new_l)

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("patched ok")
