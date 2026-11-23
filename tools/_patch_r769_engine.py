# -*- coding: utf-8 -*-
"""R769：猴爪加「加入手牌的那张，本回合费用 -1」。

关键判断：**不新造机制，也不给 CardData 加字段**。
引擎里 `state.hand_cost_turn` 已经是「本回合手卡内减费」的既有表，链路齐：
  * 写：R276 随心组装 9144 / 森林的朋友们 9183 / 机械臂 6065 都往它写
  * 读：`cost_of()` 唯一口（显示 = 判定 = 实扣）
  * 判据：`state.hand.has(card)` —— 打出 / 弃掉即自动恢复原价，不用在离手口逐个清标记
  * 清：`end_turn` 清空
  * 迁：`_move_key` 已覆盖
所以只加一行写入，CardData / `_migrate_card_state` 一律不动（漏一处就是运行期
`Invalid access to property or key`，R756 踩过）。

game_engine.gd 是 CRLF，按字节改。
"""
P = r"E:\work\card_rogue\scripts\game_engine.gd"

raw = open(P, "rb").read()
assert raw.count(b"\r\n") > 0 and raw.count(b"\r\n") == raw.count(b"\n"), "期望纯 CRLF"


def sub(data, old, new, tag):
    n = data.count(old)
    assert n == 1, "%s: 锚点命中 %d 次（期望 1）" % (tag, n)
    return data.replace(old, new)


def crlf(*lines):
    return "\r\n".join(lines).encode("utf-8")


# ---- 1. 常量 ----
raw = sub(
    raw,
    crlf("const MONKEY_CLAW_TURNS:= 3",
         "const REGRET_CARD_ID:= 9265"),
    crlf("const MONKEY_CLAW_TURNS:= 3",
         "const MONKEY_CLAW_DISCOUNT:= 1   # R769：发进手牌的那张，本回合费用 -1",
         "const REGRET_CARD_ID:= 9265"),
    "常量")

# ---- 2. docstring ----
raw = sub(
    raw,
    crlf("\t##    卡不会凭空蒸发）；② 一张「懊悔」→ **卡组**（永久，`RunState.add_card`）。"),
    crlf("\t##    卡不会凭空蒸发），并让它在**本回合**费用 -1（R769）；",
         "\t##    ② 一张「懊悔」→ **卡组**（永久，`RunState.add_card`）。"),
    "docstring")

# ---- 3. 写入 hand_cost_turn ----
raw = sub(
    raw,
    crlf('\t\tvar got:= _grant_to_hand(copy, "猴爪")',
         '\t\t_log("猴爪：第 %d 回合，%s「%s」" % [',
         '\t\t\t\tturn_number, "手牌加入" if got else "手牌已满 → 改投弃牌区", copy.card_name])'),
    crlf('\t\tvar got:= _grant_to_hand(copy, "猴爪")',
         "\t\t# R769：加进手牌的这张，**本回合**费用 -1。复用 `state.hand_cost_turn` 既有链路",
         "\t\t# （`cost_of` 唯一口读它、判据「此刻还在手牌里」、`end_turn` 清空、`_move_key` 迁移），",
         "\t\t# 不新造卡字段 —— 所以 CardData / `_migrate_card_state` 都不用动。",
         "\t\t# 只在 `got` 时标记：满手改投弃牌区的那张不在手牌，标记无处生效。",
         "\t\tif got:",
         "\t\t\tvar cur:= int(state.hand_cost_turn.get(copy, 0))",
         "\t\t\tstate.hand_cost_turn[copy] = cur + MONKEY_CLAW_DISCOUNT",
         '\t\t_log("猴爪：第 %d 回合，%s「%s」%s" % [',
         '\t\t\t\tturn_number, "手牌加入" if got else "手牌已满 → 改投弃牌区", copy.card_name,',
         '\t\t\t\t"（本回合费用 -1）" if got else ""])'),
    "写入减费")

open(P, "wb").write(raw)
print("game_engine.gd 已改（CRLF 保持）")

# 复核
chk = open(P, "rb").read()
assert chk.count(b"\r\n") == chk.count(b"\n"), "行尾被破坏"
assert chk.count(b"MONKEY_CLAW_DISCOUNT") == 2, chk.count(b"MONKEY_CLAW_DISCOUNT")
assert b"state.hand_cost_turn[copy]" in chk
print("复核通过：常量 1 处 + 使用 1 处，行尾仍纯 CRLF")
