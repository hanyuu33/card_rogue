# -*- coding: utf-8 -*-
"""R851：给 test_engine.gd 加禁卡表触屏拖动的源码守卫。

test_engine.gd 是纯 CRLF：读入先规范化为 LF 打补丁，写回时整篇转回 CRLF。
"""
import os

P = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "scripts", "test_engine.gd")
P = os.path.abspath(P)
raw = open(P, "rb").read()
assert raw.count(b"\r\n") == raw.count(b"\n") and raw.count(b"\r\n") > 0, "test_engine.gd 应为纯 CRLF"
s = raw.decode("utf-8").replace("\r\n", "\n")


def rep(old, new, label):
    global s
    n = s.count(old)
    assert n == 1, "%s：锚点出现 %d 次（应为 1）" % (label, n)
    s = s.replace(old, new, 1)
    print("  ok:", label)


rep(
    "\t_test_r847()\n",
    "\t_test_r847()\n\t_test_r851()\n",
    "scheduler",
)

tail = (
    '\tcheck(not FieldArt.has_frame(999999),\n'
    '\t\t\t"R847 未知 id 不该有边框素材（缺图要回退程序化画法，不能静默不画）")\n'
)
new_fn = (
    '\n'
    '\n'
    'func _test_r851() -> void:\n'
    '\t## R851：禁卡表在安卓上拖不动 + 手指一滑就误禁卡。三件事各钉一条：\n'
    '\t##   ① 触屏能滚（手势唯一口）② 滑动不算点击（抬起才执行）③ 有可见拖动条（画与拖同源）。\n'
    '\tvar bs851 := FileAccess.get_file_as_string("res://scripts/ban_scene.gd")\n'
    '\tcheck_src(bs851.find("const UiDrag") >= 0\n'
    '\t\t\tand bs851.find("UiDrag.scroll_delta") >= 0,\n'
    '\t\t\t"R851 源码：禁卡表接入手势唯一口（触屏按住能拖，不再只认滚轮）")\n'
    '\tvar bs851_gui := bs851.find("func _gui_input")\n'
    '\tvar bs851_gate := bs851.find("UiDrag.drag_moved(press, mb.position)")\n'
    '\tvar bs851_toggle := bs851.find("_toggle(_cards[hit])")\n'
    '\tcheck_src(bs851_gui >= 0 and bs851_gate > bs851_gui and bs851_toggle > bs851_gate,\n'
    '\t\t\t"R851 源码：点行切换在「抬起且没拖过」判定之后（触屏一滑不误禁卡）")\n'
    '\tcheck_src(bs851.find("var _press_pos := Vector2.INF") >= 0,\n'
    '\t\t\t"R851 源码：按下点先记意图，等抬起再执行")\n'
    '\tvar bs851_refresh := bs851.find("func _refresh")\n'
    '\tvar bs851_next := bs851.find("func _max_scroll")\n'
    '\tvar bs851_reset := bs851.find("_press_pos = Vector2.INF", bs851_refresh)\n'
    '\tcheck_src(bs851_refresh >= 0 and bs851_next > bs851_refresh\n'
    '\t\t\tand bs851_reset > bs851_refresh and bs851_reset < bs851_next,\n'
    '\t\t\t"R851 源码：换职业页签清掉按下意图（旧 press 不误点新页的卡）")\n'
    '\tcheck_src(bs851.find("func _bar_thumb_rect") >= 0\n'
    '\t\t\tand bs851.find("func _draw_bar") >= 0\n'
    '\t\t\tand bs851.find("func _list_bar_hit") >= 0,\n'
    '\t\t\t"R851 源码：细滚动条几何 + 绘制 + 加宽命中区")\n'
    '\tcheck_src(bs851.find("_bar_thumb_rect(track, ratio, t)") >= 0\n'
    '\t\t\tand bs851.find("_bar_grab_offset(_list_track()") >= 0,\n'
    '\t\t\t"R851 源码：滑块画与抓共用同一矩形（不会看得见摸不到）")\n'
    '\tcheck_src(bs851.find("ScrollHint.draw") >= 0,\n'
    '\t\t\t"R851 源码：溢出时画上下双箭头（玩家知道下面还有卡）")\n'
    '\tcheck_src(bs851.find("_drag_accum / ROW_H") >= 0,\n'
    '\t\t\t"R851 源码：内容拖动按列表行高 40 折行（不是正文行距 26，安卓不会一碰就飞）")\n'
)
rep(tail, tail + new_fn, "r851-test-fn")

out = s.replace("\n", "\r\n").encode("utf-8")
open(P, "wb").write(out)
print("WROTE", P, len(out), "bytes; CRLF=", out.count(b"\r\n"))
