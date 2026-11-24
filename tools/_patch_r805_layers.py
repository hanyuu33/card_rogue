# -*- coding: utf-8 -*-
"""R805：game_layers.gd 注册「诡异洋房」haunted_house（第二层）。保持 LF。"""
import io

P = "E:/work/card_rogue/scripts/game_layers.gd"
d = open(P, "rb").read().decode("utf-8")
assert d.count("\r\n") == 0, "game_layers.gd 不是纯 LF"


def rep(old, new, cnt=1):
    global d
    assert d.count(old) == cnt, "锚点命中 %d 次（应 %d）：%r" % (d.count(old), cnt, old[:70])
    d = d.replace(old, new)


# ① 第二层 events 表：接在 factory 之后
rep(
    '\t\t\t"factory": 16,\n'
    '\t\t\t# R754 奇异雕像：原登记在本层（R763d 用户口径「改为一层事件」→ 已挪到 LAYERS[1]）。\n'
    '\t\t\t# **不要照旧文档补回来** —— 第二层现在 15 种子类型。\n',
    '\t\t\t"factory": 16,\n'
    '\t\t\t# R805（店长口径「新增事件 诡异洋房」）：一栋不该有人住却亮着灯的洋房。\n'
    '\t\t\t#   探索 → 当场开一次奖励页（一件随机**传奇**道具 + 一组**史诗**卡牌，\n'
    '\t\t\t#   走 `pending_rewards` / `RewardPanel`，**不挂战斗胜利面板**）\n'
    '\t\t\t#   ＋ 强制塞一张诅咒「诅咒娃娃」9276 进卡组；\n'
    '\t\t\t#   离开 → 什么都不发生。\n'
    '\t\t\t#   收益是全场最高的那一档（传奇道具 + 必定史诗），代价是**贯穿整局**的持续掉血，\n'
    '\t\t\t#   所以只在第二层登记。\n'
    '\t\t\t"haunted_house": 16,\n'
    '\t\t\t# R754 奇异雕像：原登记在本层（R763d 用户口径「改为一层事件」→ 已挪到 LAYERS[1]）。\n'
    '\t\t\t# **不要照旧文档补回来** —— 第二层现在 16 种子类型。\n'
)

# ② 显示名
rep(
    '\t"factory": "巧克力工厂",\n',
    '\t"factory": "巧克力工厂",\n'
    '\t"haunted_house": "诡异洋房",\n'
)

io.open(P, "wb").write(d.encode("utf-8"))
print("ok lines=%d" % d.count("\n"))
