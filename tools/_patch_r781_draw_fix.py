# R781 修正：上一版把 \uXXXX 写进了 bytes 字面量（bytes 不认 \u），注释变成了字面转义符。
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scripts", "game_engine.gd")

good = (
    "\t\t# R781：玩家抽卡数走 `RunState.hand_draw_per_turn()`（基础 5 + 每日修饰 `draw`，下限 1）。\r\n"
    "\t\t# 敌方抽卡仍读 `FieldState.HAND_DRAW_PER_TURN`——修饰只针对玩家。\r\n"
).encode("utf-8")

raw = open(P, "rb").read()
pat = re.compile(rb"\t\t# R781\\uff1a[^\r\n]*\r\n\t\t# \\u654c[^\r\n]*\r\n")
found = pat.findall(raw)
if len(found) != 1:
    sys.exit("[R781-fix] 命中 %d 处（应为 1），中止" % len(found))
raw = pat.sub(lambda m: good, raw)
open(P, "wb").write(raw)

data = open(P, "rb").read()
crlf = data.count(b"\r\n")
print("[R781-fix] CRLF=%d 裸LF=%d" % (crlf, data.count(b"\n") - crlf))
print("[R781-fix] 残留字面转义 =", b"\\uff1a" in data or b"\\u654c" in data)
