# -*- coding: utf-8 -*-
"""R823 第二部分：只改 scripts/test_engine.gd（CRLF 文件）。
第一支补丁在这一步因 LF/CRLF 不匹配中断，前六个文件已落盘。
"""
P = "scripts/test_engine.gd"
s = open(P, "rb").read().decode("utf-8")
assert "\r\n" in s

TST = [
    (
        "\t## R769 猴爪：发进手牌的**那张**，本回合费用 -1（店长追加口径）。",
        "\t## R769 猴爪：发进手牌的**那张**，本回合费用 -2（R769 建机制 -1，R823 店长上调为 -2）。",
    ),
    (
        "\t\t# 排除回响 9102：它卡面写死「最低 1 费」，_cost_floor 会压住这 -1，断言会假红",
        "\t\t# 排除回响 9102：它卡面写死「最低 1 费」，_cost_floor 会压住这次减费，断言会假红",
    ),
    (
        '\t\t\t\t"R769 猴爪：发进手牌的那张打上「本回合费用 -1」标记")',
        '\t\t\t\t"R769 猴爪：发进手牌的那张打上「本回合费用 -%d」标记"\n'
        "\t\t\t\t% GameEngine.MONKEY_CLAW_DISCOUNT)",
    ),
    (
        "\t\tcheck(r769_after == maxi(0, r769_before - 1),",
        "\t\tcheck(r769_after == maxi(0, r769_before - GameEngine.MONKEY_CLAW_DISCOUNT),",
    ),
    (
        "\t# ④' 「-1 真生效」的硬证据：上面那张是随机摇的，可能是 0 费（0-1 被 maxi(0,…) 夹住，",
        "\t# ④' 「减费真生效」的硬证据：上面那张是随机摇的，可能是低费（减完被 maxi(0,…) 夹住，",
    ),
    (
        "\t#     断言虽过却嚼不出味道）。这里另取一张**确定 >=1 费**的别职业卡，挂同一个标记，",
        "\t#     断言虽过却嚼不出味道）。这里另取一张**确定 >= 减费量**的别职业卡，挂同一个标记，",
    ),
    (
        "\t#     直接验 cost_of 真降 1 —— 前者证接线，这条证效果。",
        "\t#     直接验 cost_of 真降 N —— 前者证接线，这条证效果。",
    ),
    (
        "\t\tif r769_e._other_class_card(pc) and pc.cost >= 1 and pc.id != GameEngine.ECHO_ID:",
        "\t\tif (r769_e._other_class_card(pc) and pc.cost >= GameEngine.MONKEY_CLAW_DISCOUNT\n"
        "\t\t\t\tand pc.id != GameEngine.ECHO_ID):",
    ),
    (
        "\t\tcheck(r769_e.cost_of(r769_inst) == r769_pick.cost - 1,",
        "\t\tcheck(r769_e.cost_of(r769_inst) == r769_pick.cost - GameEngine.MONKEY_CLAW_DISCOUNT,",
    ),
    (
        '\t\t\t\t"R769 猴爪：「%s」%d 费 → 本回合 %d 费（-1 真落地，没被 0 费夹住）"\n'
        "\t\t\t\t% [r769_pick.card_name, r769_pick.cost, r769_e.cost_of(r769_inst)])",
        '\t\t\t\t"R769 猴爪：「%s」%d 费 → 本回合 %d 费（-%d 真落地，没被 0 费夹住）"\n'
        "\t\t\t\t% [r769_pick.card_name, r769_pick.cost, r769_e.cost_of(r769_inst),\n"
        "\t\t\t\t\t\tGameEngine.MONKEY_CLAW_DISCOUNT])",
    ),
]

for old, new in TST:
    old = old.replace("\n", "\r\n")
    new = new.replace("\n", "\r\n")
    n = s.count(old)
    assert n == 1, "hit=%d for %r" % (n, old[:80])
    s = s.replace(old, new)

open(P, "wb").write(s.encode("utf-8"))
b = open(P, "rb").read()
print("PATCHED CRLF=%d bareLF=%d" % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
