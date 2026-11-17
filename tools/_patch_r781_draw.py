# R781：把玩家回合抽卡接到 RunState.hand_draw_per_turn()（保持 CRLF 原样，不走 Edit 工具）
import io, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "scripts", "game_engine.gd")

old = b"\t\tvar drawn := _draw_many(FieldState.HAND_DRAW_PER_TURN + extra_draw)\r\n"
new = (b"\t\t# R781\uff1a\u73a9\u5bb6\u62bd\u5361\u6570\u8d70 `RunState.hand_draw_per_turn()`"
       b"\uff08\u57fa\u7840 5 + \u6bcf\u65e5\u4fee\u9970 `draw`\uff0c\u4e0b\u9650 1\uff09\u3002\r\n"
       b"\t\t# \u654c\u65b9\u62bd\u5361\u4ecd\u8bfb `FieldState.HAND_DRAW_PER_TURN`\u2014\u2014\u4fee\u9970\u53ea\u9488\u5bf9\u73a9\u5bb6\u3002\r\n"
       b"\t\tvar drawn := _draw_many(RunState.hand_draw_per_turn() + extra_draw)\r\n")

raw = open(P, "rb").read()
n = raw.count(old)
if n != 1:
    sys.exit("[R781] 锚点命中 %d 次（应为 1），中止" % n)
raw = raw.replace(old, new)
open(P, "wb").write(raw)

# 复核：仍是 CRLF，且没有裸 LF
data = open(P, "rb").read()
crlf = data.count(b"\r\n")
bare_lf = data.count(b"\n") - crlf
print("[R781] game_engine.gd 改写完成：CRLF=%d 裸LF=%d" % (crlf, bare_lf))
print("[R781] 新锚点存在 =", b"RunState.hand_draw_per_turn() + extra_draw" in data)
if bare_lf != 0:
    sys.exit("[R781] 行尾被破坏，需要人工处理")
