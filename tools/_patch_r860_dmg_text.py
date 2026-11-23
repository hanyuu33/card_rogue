# -*- coding: utf-8 -*-
"""R860：沉睡文案「被攻击/挨打」→「受到伤害」。
口径：R859 的判据是 `_demon_duck_hurt(p, cell, dealt)` 里 dealt > 0（真扣到血），
所以用「受到伤害」而不是「被攻击」——攻击落空 / 被甲吃光都不算。
只做精确串替换，不动行尾、不动结构。
"""
import io
import sys

FILES = {}

# ---- 中文：卡面（cards.json + zh_canonical.json 各两处） ----
ZH_OLD = "护甲未破时挨打不减少沉睡"
ZH_NEW = "护甲未破时受到伤害不减少沉睡"
FILES["cards.json"] = [(ZH_OLD, ZH_NEW, 2)]
FILES["i18n/zh_canonical.json"] = [(ZH_OLD, ZH_NEW, 2)]

# ---- 英文 ----
EN_A_OLD = "While the Armor holds, hits do not reduce Sleep."
EN_A_NEW = "While the Armor holds, taking damage does not reduce Sleep."
EN_B_OLD = "while the Armor holds, hits do not reduce Sleep)"
EN_B_NEW = "while the Armor holds, taking damage does not reduce Sleep)"
FILES["i18n/cards_en.json"] = [(EN_A_OLD, EN_A_NEW, 1), (EN_B_OLD, EN_B_NEW, 1)]

# ---- 日文：两处同句 ----
JA_OLD = "装甲が残っている間は攻撃を受けても睡眠は減らない"
JA_NEW = "装甲が残っている間はダメージを受けても睡眠は減らない"
FILES["i18n/cards_ja.json"] = [(JA_OLD, JA_NEW, 2)]

# ---- 西语：两处同句 ----
ES_OLD = "los golpes no reducen dormir"
ES_NEW = "recibir daño no reduce dormir"
FILES["i18n/cards_es.json"] = [(ES_OLD, ES_NEW, 2)]

# ---- 游戏内可见文本（悬停提示 + 战斗日志） ----
BS_OLD = "自己的回合结束 -1，挨打也 -1"
BS_NEW = "自己的回合结束 -1，受到伤害也 -1"
FILES["scripts/battle_scene.gd"] = [
    (BS_OLD, BS_NEW, 1),
    # 注释：徽章含义
    ("（还差 N 下挨打就醒）", "（还差 N 点伤害就醒）", 1),
]

GE_OLD = "回合结束 -1，挨打也 -1）"
GE_NEW = "回合结束 -1，受到伤害也 -1）"
FILES["scripts/game_engine.gd"] = [
    (GE_OLD, GE_NEW, 1),                        # 战斗日志
    ("#     回合结束 -1、挨打也 -1），成长用",      # 注释
     "#     回合结束 -1、受到伤害也 -1），成长用", 1),
]

# game_levels 注释
FILES["scripts/game_levels.gd"] = [
    ("## 回合结束 -1、挨打也 -1，与恶魔鸭 9116 同一套）。",
     "## 回合结束 -1、受到伤害也 -1，与恶魔鸭 9116 同一套）。", 1),
]

# 测试注释 / 标签（不影响断言逻辑，只统一术语）
FILES["scripts/test_engine.gd"] = [
    ("# ④ 沉睡：走 place 的唯一初始化口，2 点；挨打也 -1",
     "# ④ 沉睡：走 place 的唯一初始化口，2 点；受到伤害也 -1", 1),
    ('"R539 激光炮：挨打也 -1（与「沉睡」同语义，没有独立机制）"',
     '"R539 激光炮：受到伤害也 -1（与「沉睡」同语义，没有独立机制）"', 1),
]


def main() -> int:
    bad = 0
    for path, rules in FILES.items():
        with io.open(path, encoding="utf-8", newline="") as f:
            s = f.read()
        orig = s
        for old, new, expect in rules:
            n = s.count(old)
            if n != expect:
                print("FAIL %s: %r 出现 %d 次（期望 %d）" % (path, old, n, expect))
                bad += 1
                continue
            s = s.replace(old, new, expect)
        if s != orig:
            with io.open(path, "w", encoding="utf-8", newline="") as f:
                f.write(s)
            print("ok  %s" % path)
        else:
            print("--  %s 未改动" % path)
    if bad:
        print("有 %d 条规则未命中，未写盘的部分请注意" % bad)
        return 1
    print("全部替换完成")
    return 0


if __name__ == "__main__":
    sys.exit(main())
