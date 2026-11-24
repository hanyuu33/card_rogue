# -*- coding: utf-8 -*-
"""test_reward.gd 里同一条 R756 过期断言：320 -> 323。CRLF 原样回写。"""
import sys
import pathlib

P = pathlib.Path("scripts/test_reward.gd")
raw = P.read_bytes()
print("CRLF" if b"\r\n" in raw else "LF", "size=%d" % len(raw))

REPL = [
    ('check(all.size() == 320, "卡牌库 320 张（R756 +1：代偿 9252',
     'check(all.size() == 323, "卡牌库 323 张（R756 +3：常数测量员 9253 / 精密计算者 9254 / 负载增量员 9255；R756 +1：代偿 9252'),
]
pairs = [(o.encode("utf-8"), n.encode("utf-8")) for o, n in REPL]

bad = False
for i, (old, _n) in enumerate(pairs):
    c = raw.count(old)
    print("anchor[%d] hits=%d" % (i, c))
    if c != 1:
        bad = True
if bad:
    print("ABORT")
    sys.exit(2)

out = raw
for old, new in pairs:
    out = out.replace(old, new, 1)

assert out.count(b"\r\n") == raw.count(b"\r\n")
assert out.count(b"\n") == raw.count(b"\n")
P.write_bytes(out)
print("OK bytes %d -> %d" % (len(raw), len(out)))
