# -*- coding: utf-8 -*-
"""修掉 here-doc 把 \\r\\n 吃成 /r/n 的那行（R799 猴爪 x_cost 跳过）。"""
P = "scripts/game_engine.gd"
raw = open(P, "rb").read().decode("utf-8")
bad = "if c.x_cost:/r/n\t\t\tcontinue"
print("bad occurrences:", raw.count(bad))
assert raw.count(bad) == 1
raw = raw.replace(bad, "if c.x_cost:\r\n\t\t\tcontinue")
open(P, "wb").write(raw.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
print("still /r/n:", b.count(b"/r/n"))
