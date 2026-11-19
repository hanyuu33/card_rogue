# -*- coding: utf-8 -*-
"""R823：猴爪 6066 的减费由 -1 上调为 -2（店长口径）。

改动面：
  1. game_engine.gd —— 常量 MONKEY_CLAW_DISCOUNT 1 -> 2；三处注释与一行 _log 串跟随；
  2. relics.json / noncard_zh_canonical.json —— 中文两处真源；
  3. noncard_en / ja / es —— 三语同改；
  4. test_engine.gd —— R769 里写死的 `- 1` 两处改为引用常量；选卡门槛 >=1 -> >= 减费量。

一律 bytes 读写，保持原行尾（game_engine/test_engine 是 CRLF，json 是 LF）。
"""
import io

FILES = {}


def load(p):
    return open(p, "rb").read().decode("utf-8")


def save(p, s):
    open(p, "wb").write(s.encode("utf-8"))


def patch(p, pairs):
    s = load(p)
    before = s
    for old, new in pairs:
        n = s.count(old)
        assert n == 1, "%s: hit=%d for %r" % (p, n, old[:70])
        s = s.replace(old, new)
    assert s != before
    save(p, s)
    print("OK", p)


# ---------------- 1) 引擎 ----------------
ENG = [
    (
        "const MONKEY_CLAW_DISCOUNT:= 1   # R769：发进手牌的那张，本回合费用 -1",
        "const MONKEY_CLAW_DISCOUNT:= 2   # R769 建机制 -1；R823 店长口径上调为 -2（发进手牌的那张，本回合费用 -2）",
    ),
    (
        "\t##    卡不会凭空蒸发），并让它在**本回合**费用 -1（R769）；",
        "\t##    卡不会凭空蒸发），并让它在**本回合**费用 -2（R769 建机制，R823 上调）；",
    ),
    (
        "\t\t# R769：加进手牌的这张，**本回合**费用 -1。复用 `state.hand_cost_turn` 既有链路",
        "\t\t# R769 建机制 / R823 上调：加进手牌的这张，**本回合**费用 -2。复用 `state.hand_cost_turn` 既有链路",
    ),
    (
        '\t\t\t\t"（本回合费用 -1）" if got else ""])',
        '\t\t\t\t("（本回合费用 -%d）" % MONKEY_CLAW_DISCOUNT) if got else ""])',
    ),
    (
        "\t\t# R799：X 费卡（连斩 9272 / 炮火就位 9273）不参与 —— 猴爪给的是「本回合费用 -1」，",
        "\t\t# R799：X 费卡（连斩 9272 / 炮火就位 9273）不参与 —— 猴爪给的是「本回合费用 -2」，",
    ),
]
patch("scripts/game_engine.gd", ENG)

# ---------------- 2) 中文两处真源 ----------------
ZH_OLD = "（该卡本回合费用-1）"
ZH_NEW = "（该卡本回合费用-2）"
patch("relics.json", [(ZH_OLD, ZH_NEW)])
patch("i18n/noncard_zh_canonical.json", [(ZH_OLD, ZH_NEW)])

# ---------------- 3) 三语 ----------------
patch("i18n/noncard_en.json", [("(it costs -1 this turn)", "(it costs -2 this turn)")])
patch("i18n/noncard_ja.json", [("（このターン中コスト-1）", "（このターン中コスト-2）")])
patch("i18n/noncard_es.json", [("(cuesta -1 este turno)", "(cuesta -2 este turno)")])

# ---------------- 4) 回归测试 ----------------
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
        '\t\t\t\t"R769 猴爪：发进手牌的那张打上「本回合费用 -%d」标记"\n\t\t\t\t% GameEngine.MONKEY_CLAW_DISCOUNT)',
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
patch("scripts/test_engine.gd", TST)

# ---------------- 行尾复核 ----------------
for p in ["scripts/game_engine.gd", "scripts/test_engine.gd", "relics.json",
          "i18n/noncard_zh_canonical.json", "i18n/noncard_en.json",
          "i18n/noncard_ja.json", "i18n/noncard_es.json"]:
    b = open(p, "rb").read()
    print("EOL", p, "CRLF=%d bareLF=%d" % (b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
