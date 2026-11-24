# -*- coding: utf-8 -*-
"""R761 补丁 4/9：卡池 / 图鉴 —— 隐藏职业的卡必须「玩家感知不到」。

口径：
  * `obtainable_cards()` / `reward_pool()` 默认**剔除隐藏职业卡**（禁卡表、随机池、事件、
    商店全都读这两口，于是「不能被随机到」一处生效）；
  * `reward_pool_for(吟游诗人)` = 含隐藏卡的完整池（他自己开局摇奖励得能摇到东西，
    而且他的玩法就是借别职业的卡）；
  * 图鉴可见性唯一判据 `gallery_visible()` 直接挡掉隐藏职业卡（两个版本都挡）。
"""
import io

ROOT = r"E:\work\card_rogue\scripts"


def edit(name, pairs):
    p = ROOT + "\\" + name
    with io.open(p, "rb") as f:
        b = f.read()
    for old, new in pairs:
        o = old.encode("utf-8")
        c = b.count(o)
        assert c == 1, "%s 锚点命中 %d 次：%r" % (name, c, old[:60])
        b = b.replace(o, new.encode("utf-8"))
    with io.open(p, "wb") as f:
        f.write(b)
    print(name, "OK")


# ---------------------------------------------------------------- card_repo.gd
edit("card_repo.gd", [
    (
        'func obtainable_cards() -> Array[CardData]:\n',
        'func obtainable_cards(include_hidden := false) -> Array[CardData]:\n',
    ),
    (
        '\t\t# R509c：event_only（事件/关卡专属，如洞穴枭熊 9213）不该进可获得池——\n'
        '\t\t# 不进随机奖励池（reward_pool 已拦），更不该出现在禁卡表里可被 ban。\n'
        '\t\tif c.event_only:\n'
        '\t\t\tcontinue\n'
        '\t\tout.append(c)\n',
        '\t\t# R509c：event_only（事件/关卡专属，如洞穴枭熊 9213）不该进可获得池——\n'
        '\t\t# 不进随机奖励池（reward_pool 已拦），更不该出现在禁卡表里可被 ban。\n'
        '\t\tif c.event_only:\n'
        '\t\t\tcontinue\n'
        '\t\t# R761：隐藏职业（吟游诗人）的卡**默认不进任何玩家可见的池** ——\n'
        '\t\t# 随机奖励 / 商店 / 事件 / 禁卡表全读这里，一处拦死。\n'
        '\t\t# `include_hidden=true` 只给「用吟游诗人本人开局」那条路（见 reward_pool_for）。\n'
        '\t\tif not include_hidden and PlayerClass.is_hidden_class(c.card_class):\n'
        '\t\t\tcontinue\n'
        '\t\tout.append(c)\n',
    ),
    (
        'func reward_pool() -> Array[CardData]:\n',
        'func reward_pool(include_hidden := false) -> Array[CardData]:\n',
    ),
    (
        '\tvar out: Array[CardData] = []\n'
        '\tfor c: CardData in obtainable_cards():\n',
        '\tvar out: Array[CardData] = []\n'
        '\tfor c: CardData in obtainable_cards(include_hidden):\n',
    ),
    (
        '\tif cid == "":\n'
        '\t\treturn reward_pool()\n'
        '\tvar out: Array[CardData] = []\n'
        '\tfor c: CardData in reward_pool():\n'
        '\t\tif is_own_class_card(c, cid):\n'
        '\t\t\tout.append(c)\n'
        '\treturn out\n',
        '\tif cid == "":\n'
        '\t\treturn reward_pool()\n'
        '\t# R761：隐藏职业（吟游诗人）没有「本职业卡池」这一说 —— 它的玩法就是借别职业的\n'
        '\t# 盟友（招募）与道具（诗），所以给**含隐藏卡的完整池**（它自己那两张也在里面）。\n'
        '\tif PlayerClass.is_hidden_class(cid):\n'
        '\t\treturn reward_pool(true)\n'
        '\tvar out: Array[CardData] = []\n'
        '\tfor c: CardData in reward_pool():\n'
        '\t\tif is_own_class_card(c, cid):\n'
        '\t\t\tout.append(c)\n'
        '\treturn out\n',
    ),
])

# ---------------------------------------------------------------- gallery_scene.gd
edit("gallery_scene.gd", [
    (
        'static func gallery_visible(c: CardData, release_mode: bool) -> bool:\n'
        '\t## R642：图鉴可见性的**唯一判据**。抽成静态是为了测试能直接调\n'
        '\t## （`preload("res://scripts/gallery_scene.gd").gallery_visible(card, true)`），\n'
        '\t## 不必把整个场景实例化起来才能验一条布尔。\n'
        '\tif release_mode and not ProfileData.is_card_seen(c.id):\n'
        '\t\treturn false\n'
        '\treturn true\n',
        'static func gallery_visible(c: CardData, release_mode: bool) -> bool:\n'
        '\t## R642：图鉴可见性的**唯一判据**。抽成静态是为了测试能直接调\n'
        '\t## （`preload("res://scripts/gallery_scene.gd").gallery_visible(card, true)`），\n'
        '\t## 不必把整个场景实例化起来才能验一条布尔。\n'
        '\t## R761：隐藏职业（吟游诗人）的卡**永远不进图鉴** —— 与版本无关，\n'
        '\t## 连「全部」列表和职业下拉都不该出现它（职业下拉是从实际卡汇总的）。\n'
        '\tif PlayerClass.is_hidden_class(c.card_class):\n'
        '\t\treturn false\n'
        '\tif release_mode and not ProfileData.is_card_seen(c.id):\n'
        '\t\treturn false\n'
        '\treturn true\n',
    ),
])
