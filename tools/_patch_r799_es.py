# -*- coding: utf-8 -*-
"""R799：validate_spanish.py 的卡数 332 → 334。"""
P = "i18n/validate_spanish.py"
d = open(P, "rb").read().decode("utf-8")

old1 = "# 卡牌：332 个稳定 ID（R794 加巧克力工厂 9271；R777b 加疾风乐章 9270）；名称与效果字段完整，空效果只允许仍为空。"
new1 = "# 卡牌：334 个稳定 ID（R799 加连斩 9272 / 炮火就位 9273；R794 加巧克力工厂 9271；R777b 加疾风乐章 9270）；名称与效果字段完整，空效果只允许仍为空。"
old2 = 'check(len(CARDS_ES["cards"]) == 332, "cards 共 332 张")'
new2 = 'check(len(CARDS_ES["cards"]) == 334, "cards 共 334 张")'

for o, n in ((old1, new1), (old2, new2)):
    assert d.count(o) == 1, o[:30]
    d = d.replace(o, n)

open(P, "wb").write(d.encode("utf-8"))
b = open(P, "rb").read()
print("CRLF", b.count(b"\r\n"), "LFonly", b.count(b"\n") - b.count(b"\r\n"))
