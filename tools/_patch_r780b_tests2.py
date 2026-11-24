# -*- coding: utf-8 -*-
"""R780b：9188 卡面不再是空文本（新增伤害上限一句），R483 那条旧断言同步。"""
import io
import sys

ROOT = "E:/work/card_rogue/"
NL = "\r\n"
p = ROOT + "scripts/test_engine.gd"
s = io.open(p, encoding="utf-8", newline="").read()

old1 = '\tcheck(r397_carrier.effect_text == "",'
new1 = '\tcheck(r397_carrier.effect_text == "每回合最多受到 20 点伤害。",'
old2 = '\t\t"R483 量产型赫尔墨斯没有效果 → 卡面不写效果文字（effect_text 为空；卡面绘制 `eff != \\"\\"` 才起笔）")'
new2 = ('\t\t"R780b 9188 卡面只写「每回合最多受到 20 点伤害」一句'
        '（R483 那条「卡面为空」已被取代 —— 它现在有被动，仍没有发动式效果）")')

for o, nm, tag in ((old1, new1, "9188 文本判据"), (old2, new2, "R483 消息")):
    c = s.count(o)
    if c != 1:
        sys.exit("%s 计数 %d —— %r" % (tag, c, o[:60]))
    s = s.replace(o, nm, 1)

io.open(p, "w", encoding="utf-8", newline="").write(s)

s2 = io.open(p, encoding="utf-8", newline="").read()
if 'r397_carrier.effect_text == ""' in s2:
    sys.exit("回读：旧空串断言还在")
if s2.count("R780b 9188 卡面只写") != 1:
    sys.exit("回读：新消息未落地")
b = io.open(p, "rb").read()
print("FIX_OK CRLF", b.count(b"\r\n"), "bareLF", b.count(b"\n") - b.count(b"\r\n"))
