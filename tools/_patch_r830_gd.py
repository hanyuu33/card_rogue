# -*- coding: utf-8 -*-
"""R830：首饰盒 6088（一层初始道具）—— run_state.gd + relic_repo.gd 逻辑落地。

LF 文件，exact-replace + assert count==1。跑完 `python tools/_patch_r830_gd.py`。
"""
import io

ROOT = "E:/work/card_rogue"


def patch(path, repls):
    data = open(path, "rb").read().decode("utf-8")
    for old, new in repls:
        c = data.count(old)
        assert c == 1, "锚点出现 %d 次（期望 1）：%r" % (c, old[:60])
        data = data.replace(old, new, 1)
    open(path, "w", encoding="utf-8", newline="\n").write(data)
    print("patched:", path)


# ---- run_state.gd ----
rs = ROOT + "/scripts/run_state.gd"
patch(rs, [
    # ① 常量区：CAVE_ROPE 之后新增 JEWELRY_BOX_RELIC_ID
    (
        "const CAVE_ROPE_RELIC_ID := 6048\n"
        "# R342 采集刀（6050，**传奇**奖励池）：「战斗后额外获得一份卡牌奖励」。",
        "const CAVE_ROPE_RELIC_ID := 6048\n"
        "# R830 新道具：首饰盒（6088，初始池）—— 获得时随机一张**史诗卡**加入卡组。\n"
        "# 与湖中仙女·诚实共用同一条抽卡口（LAKE_EPIC_RARITY = 2 = 史诗）；随机源走 run_rng。\n"
        "const JEWELRY_BOX_RELIC_ID := 6088\n"
        "# R342 采集刀（6050，**传奇**奖励池）：「战斗后额外获得一份卡牌奖励」。",
    ),
    # ② gain_relic match 分支：FLINT 之后新增首饰盒
    (
        "\t\tFLINT_RELIC_ID:  # 燧石（R447）：要玩家在地图上点一格走过的房间 → 回地图后进选格模式\n"
        "\t\t\tpending_relic = relic.id\n"
        "\n\n"
        "static func _grant_linked_card",
        "\t\tFLINT_RELIC_ID:  # 燧石（R447）：要玩家在地图上点一格走过的房间 → 回地图后进选格模式\n"
        "\t\t\tpending_relic = relic.id\n"
        "\t\tJEWELRY_BOX_RELIC_ID:   # 首饰盒（R830）：随机一张史诗卡加入卡组\n"
        "\t\t\t_grant_random_epic()\n"
        "\n\n"
        "static func _grant_linked_card",
    ),
    # ③ 新增 _grant_random_epic()：放在 _grant_linked_card 之后
    (
        "\tvar cid := rel.granted_card()\n"
        "\tif cid <= 0:\n"
        "\t\tcid = fallback\n"
        "\tif cid > 0:\n"
        "\t\tadd_card(cid)\n"
        "\n\n"
        "static func _apply_pot",
        "\tvar cid := rel.granted_card()\n"
        "\tif cid <= 0:\n"
        "\t\tcid = fallback\n"
        "\tif cid > 0:\n"
        "\t\tadd_card(cid)\n"
        "\n\n"
        "static func _grant_random_epic() -> void:\n"
        "\t## 首饰盒（6088，R830）：随机一张**史诗卡**（本职业奖励池里稀有度 2 的卡）加入卡组。\n"
        "\t## 复用湖中仙女·诚实的同一条抽卡口（LAKE_EPIC_RARITY = 2）；随机源走 run_rng → 同种子一致。\n"
        "\tvar rolled := CardReward.roll_rarity(CardRepo.load_json(), LAKE_EPIC_RARITY, 1, run_rng)\n"
        "\tif rolled.is_empty():\n"
        "\t\treturn\n"
        "\tvar c: CardData = rolled[0]\n"
        "\tadd_card(c.id)\n"
        "\n\n"
        "static func _apply_pot",
    ),
])

# ---- relic_repo.gd ----
rr = ROOT + "/scripts/relic_repo.gd"
patch(rr, [
    # initial_ids()：10 → 11 件，加 6088
    (
        "\t# R745：新增「工具箱」6068（立即给一个随机工具、每进新层再给一个）。\n"
        "\tvar out: Array[int] = [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068]\n"
        "\treturn _demo_ids(out)",
        "\t# R745：新增「工具箱」6068（立即给一个随机工具、每进新层再给一个）。\n"
        "\t# R830：新增「首饰盒」6088（获得即随机一张史诗卡加入卡组）。\n"
        "\tvar out: Array[int] = [6001, 6002, 6004, 6021, 6030, 6031, 6032, 6047, 6048, 6068, 6088]\n"
        "\treturn _demo_ids(out)",
    ),
])

print("ALL DONE")
