# -*- coding: utf-8 -*-
"""R805 修最后一条：注释里的 _present_win_panel( 让「不含该词」断言假红。

改成「剥离注释后再判」，这才是真正想验的东西：探索函数体内没有对胜利面板的调用。
行尾：scripts/test_engine.gd = CRLF。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scripts", "test_engine.gd")
E = "\r\n"

OLD = (
    '\tcheck_src(r805_body.contains("_reward_panel.open()")\n'
    '\t\t\tand not r805_body.contains("_present_win_panel("),\n'
    '\t\t\t"R805 事件：奖励页直连 —— 探索函数直接开奖励面板，不经过战斗胜利那一屏")'
)
NEW = (
    '\t# 注释里为了说明「战斗那边走的是 _present_win_panel」也带了这个词，\n'
    '\t# 所以先剥掉注释行再判，否则断言验的是注释而不是代码。\n'
    '\tvar r805_code := ""\n'
    '\tfor r805_ln in r805_body.split("\\n"):\n'
    '\t\tif r805_ln.strip_edges().begins_with("#"):\n'
    '\t\t\tcontinue\n'
    '\t\tr805_code += r805_ln + "\\n"\n'
    '\tcheck_src(r805_code.contains("_reward_panel.open()")\n'
    '\t\t\tand not r805_code.contains("_present_win_panel"),\n'
    '\t\t\t"R805 事件：奖励页直连 —— 探索函数（剥注释后）直接开奖励面板，不调战斗胜利面板")'
)

s = io.open(P, "rb").read().decode("utf-8")
o = OLD.replace("\n", E)
n = NEW.replace("\n", E)
c = s.count(o)
assert c == 1, "count=%d" % c
s = s.replace(o, n)
io.open(P, "wb").write(s.encode("utf-8"))

# 行尾纯度复核
b = io.open(P, "rb").read()
print("OK  test_engine.gd  CRLF=%d LF=%d %s"
      % (b.count(b"\r\n"), b.count(b"\n"),
         "PURE" if b.count(b"\r\n") == b.count(b"\n") else "MIXED!!"))
