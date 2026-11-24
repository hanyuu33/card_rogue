# -*- coding: utf-8 -*-
"""解决 rebase 冲突：test_engine.gd 两处都是「函数追加点撞车」。
统一规则 —— 两侧全留（远端 _test_r805/_test_r806 在前，我的 _test_r807 在后），只删标记行。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scripts", "test_engine.gd")

s = io.open(P, "rb").read().decode("utf-8")
lines = s.split("\n")

out = []
state = 0  # 0=正常 1=冲突A段 2=冲突B段
blocks = 0
for ln in lines:
    t = ln.rstrip("\r")
    if t == "<<<<<<< HEAD":
        assert state == 0
        state = 1
        blocks += 1
        continue
    if t == "=======" and state == 1:
        state = 2
        continue
    if t.startswith(">>>>>>> ") and state == 2:
        state = 0
        continue
    out.append(ln)

assert state == 0, "冲突块没闭合"
assert blocks == 2, "冲突块数 %d != 2" % blocks

s2 = "\n".join(out)
assert "<<<<<<<" not in s2 and "\n=======" not in s2 and ">>>>>>>" not in s2

# 顺带确认两套函数都在、且没有同名重复
for name in ["_test_r805(", "_test_r806(", "_test_r807("]:
    c = s2.count("func " + name)
    assert c == 1, "%s 定义 %d 次" % (name, c)
for name in ["\t_test_r805()", "\t_test_r806()", "\t_test_r807()"]:
    c = s2.count(name + "\r\n")
    assert c == 1, "%s 调用 %d 次" % (name, c)

if not s2.endswith("\n"):
    s2 += "\n"
io.open(P, "wb").write(s2.encode("utf-8"))

b = io.open(P, "rb").read()
print("OK  blocks=%d  CRLF=%d LF=%d %s"
      % (blocks, b.count(b"\r\n"), b.count(b"\n"),
         "PURE-CRLF" if b.count(b"\r\n") == b.count(b"\n") else "MIXED!!"))
