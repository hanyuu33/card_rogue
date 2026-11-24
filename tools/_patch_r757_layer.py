# -*- coding: utf-8 -*-
"""R757 修复：battle 事件的 layer 恒为 0。

根因：`note_battle_start` 收了 `layer` 参数，写事件时却用了 `ctx_layer()`
—— 那是个永远 `return 0` 的占位函数（当初为「不反向 import RunState」留的兜底）。
后果：所有 battle 事件的层号都是 0，`run_end._deepest` 跟着恒为 0，
「死在第几层」这个最关键的漏斗指标整个失效，按层分层的胜率也没法算。

LF 文件，原样回写。
"""
import sys
import pathlib

P = pathlib.Path("scripts/telemetry.gd")
raw = P.read_bytes()
print("CRLF" if b"\r\n" in raw else "LF", "size=%d" % len(raw))

REPL = [
    # ① 用参数，不用占位函数
    ('\t\t"layer": int(ctx_layer()),\n',
     '\t\t"layer": int(layer),\n'),
    # ② 占位函数连同它的分组标题下那段说明一并删掉（死代码，留着容易被下一个人再踩一次）
    ("# ============================================================ 上下文小工具\n"
     "\n"
     "static func ctx_layer() -> int:\n"
     "\t## 当前层。**不 import RunState 反过来问**（那会形成双向依赖），由调用方给；\n"
     "\t## 这里只作为 battle_start 的兜底默认值。\n"
     "\treturn 0\n"
     "\n"
     "\n"
     "static func _diff_ids",
     "# ============================================================ 上下文小工具\n"
     "\n"
     "static func _diff_ids"),
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
P.write_bytes(out)
print("OK bytes %d -> %d" % (len(raw), len(out)))
