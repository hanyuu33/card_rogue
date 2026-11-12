# -*- coding: utf-8 -*-
"""R637：组合产物不再继承属性槽原卡的效果（id / traits / 效果字段全清，另开 art_id 给表现层）。

用法：python tools/_patch_r637_combo_id.py
全部走字节级 exact-replace + assert count == 1，保留各文件原换行（card_data / battle_scene / shop_scene 是 CRLF）。
"""
import io
import sys

ROOT = "."


def patch(path, pairs, crlf):
    raw = open(path, "rb").read()
    for i, (old, new) in enumerate(pairs):
        if crlf:
            ob = old.replace("\n", "\r\n").encode("utf-8")
            nb = new.replace("\n", "\r\n").encode("utf-8")
        else:
            ob = old.encode("utf-8")
            nb = new.encode("utf-8")
        cnt = raw.count(ob)
        if cnt != 1:
            print("FAIL %s pair#%d count=%d\n---\n%r\n" % (path, i, cnt, old[:200]))
            sys.exit(1)
        raw = raw.replace(ob, nb)
    open(path, "wb").write(raw)
    print("OK", path, len(pairs), "pairs")


# ── 1. card_data.gd（CRLF）────────────────────────────────────────────────
card_data_pairs = [
    # ① 字段声明
    (
        'var id: int = 0\nvar card_name: String = ""\n',
        'var id: int = 0\n'
        '## R637：**卡面表现（卡图 / 未确认角标 / 数值染色基准）认的 id**；0 = 用自身 id。\n'
        '## 为什么要多一个字段：组合产物（`combine_mark`）的 `id` 现在归 0 —— 否则产物会照旧命中\n'
        '## 引擎里「按 `card.id` 派发」的母卡效果（用户实测：赤狐 9034 当属性槽 → 产物上场又抽一张\n'
        '## 技能牌并减费）。但卡图、卡面底色、染色基准都还认那张母卡，所以另开一个字段只给表现层用。\n'
        '## ⚠️ 卡图取图口一律走 `pic_id()`，别再直接传 `card.id`。\n'
        'var art_id: int = 0\n'
        'var card_name: String = ""\n',
    ),
    # ② from_dict 读字段
    (
        '\tc.id = int(d.get("id", 0))\n',
        '\tc.id = int(d.get("id", 0))\n'
        '\t# R637：取图 id 随复制 / 离场还原 / 联机 / 存档通道走（缺省 0 → 老数据全走自身 id）。\n'
        '\tc.art_id = int(d.get("art_id", 0))\n',
    ),
    # ③ from_dict 兜底：老存档 / 联机里的产物还带着母卡 id
    (
        '\tc.combine_mark = bool(d.get("combine_mark", false))\n',
        '\tc.combine_mark = bool(d.get("combine_mark", false))\n'
        '\t# R637：**组合产物一律没有自己的 id**。老存档 / 联机 / 复制通道里可能还带着母卡 id，\n'
        '\t# 在唯一反序列化口兜一次：产物（combine_mark）的 id 归 0，原 id 转成取图用的 art_id。\n'
        '\t# 不这么兜，旧存档里的产物读回来会继续执行母卡那套按 id 派发的效果。\n'
        '\tif c.combine_mark and c.id > 0:\n'
        '\t\tc.art_id = c.id\n'
        '\t\tc.id = 0\n',
    ),
    # ④ to_dict 序列化
    (
        '\t\t"id": id, "name": card_name, "kind": kind, "cost": cost,\n',
        '\t\t"id": id, "art_id": art_id, "name": card_name, "kind": kind, "cost": cost,\n',
    ),
    # ⑤ pic_id()
    (
        'func rarity_name() -> String:\n',
        'func pic_id() -> int:\n'
        '\t## R637：卡面表现（卡图 / 待确认角标 / 染色基准）该用哪个 id —— 唯一口。\n'
        '\t## 组合产物 `id` 归 0、`art_id` 记着属性槽那张卡，所以**不许**在界面上直接读 `card.id`。\n'
        '\treturn art_id if art_id > 0 else id\n'
        '\n'
        '\n'
        'func rarity_name() -> String:\n',
    ),
]

# ── 2. assemble_rules.gd（LF）─────────────────────────────────────────────
assemble_pairs = [
    (
        '\tvar result := CardData.from_dict(base.to_dict())\n',
        '\tvar result := CardData.from_dict(base.to_dict())\n'
        '\t# ── R637：属性槽**只给身材与外观**，不给效果 ──\n'
        '\t# 用户实测：赤狐 9034 当第①张 → 产物上场又「从卡组取一张技能牌，本回合费用 -1」。\n'
        '\t# 根因是产物从 `base.to_dict()` 整份复制：id / traits / 各种效果字段全带了过来，\n'
        '\t# 引擎里按 `card.id` 派发的那一整套母卡入场效果照旧命中（art_id 只给卡面取图，不参与结算）。\n'
        '\t# 口径：产物 = 费用/力量/生命/射程/移速 + 卡名卡图 + 种类/职业 + `assemble` 那一段。\n'
        '\tresult.art_id = base.id\n'
        '\tresult.id = 0\n'
        '\tresult.traits = []\n'
        '\tresult.affixes = []\n'
        '\tresult.enchant = ""\n'
        '\tresult.enchant_label = ""\n'
        '\tresult.trigger = ""\n'
        '\tresult.combo_trigger = ""\n'
        '\tresult.combo_scope = ""\n'
        '\tresult.random_born = false\n'
        '\tresult.own_copy = false\n'
        '\tresult.upper_effect = {}\n'
        '\tresult.lower_effect = {}\n'
        '\tfor f in ["field_heal", "field_poison_dmg", "field_poison_turns", "field_vortex_dmg",\n'
        '\t\t\t"regen_per_turn", "first_kill_power", "first_kill_health", "per_kill_damage",\n'
        '\t\t\t"battle_end_gold", "growth_power", "growth_health", "growth_damage",\n'
        '\t\t\t"lone_dmg_bonus", "lone_str_bonus", "upgrade_atk_bonus", "upgrade_hp_bonus",\n'
        '\t\t\t"upgrade_stacks", "diff_power", "diff_health"]:\n'
        '\t\tresult.set(f, 0)\n',
    ),
]

# ── 3. card_face.gd（LF）──────────────────────────────────────────────────
card_face_pairs = [
    (
        '\tvar tex := art_for(card.id, sleeping, phase)\n',
        '\tvar tex := art_for(card.pic_id(), sleeping, phase)\n'
        '\t# R637：取图认 `pic_id()` —— 组合产物 id 归 0，卡图仍要出属性槽那张。\n',
    ),
    (
        '\tif tex != null and is_pending_art(card.id):\n',
        '\tif tex != null and is_pending_art(card.pic_id()):\n',
    ),
    (
        '\tif _base_cache.has(card.id):\n'
        '\t\treturn _base_cache[card.id]\n',
        '\t# R637：染色基准认 `pic_id()` —— 产物 id 归 0，但它的身材来自属性槽那张，基准还是它。\n'
        '\tif _base_cache.has(card.pic_id()):\n'
        '\t\treturn _base_cache[card.pic_id()]\n',
    ),
    (
        '\tvar proto: CardData = repo.get_card(card.id) if repo != null else null\n',
        '\tvar proto: CardData = repo.get_card(card.pic_id()) if repo != null else null\n',
    ),
    (
        '\t_base_cache[card.id] = d\n',
        '\t_base_cache[card.pic_id()] = d\n',
    ),
]

# ── 4. battle_scene.gd（CRLF）─────────────────────────────────────────────
battle_pairs = [
    (
        'func _art(card: CardData, rect: Rect2) -> void:\n'
        '\tvar tex := CardFace.art_for(card.id)\n',
        'func _art(card: CardData, rect: Rect2) -> void:\n'
        '\tvar tex := CardFace.art_for(card.pic_id())   # R637：产物 id 归 0，取图认 pic_id\n',
    ),
    (
        '\tvar picture := frame.grow(-5)\n'
        '\tvar art := CardFace.art_for(card.id)\n',
        '\tvar picture := frame.grow(-5)\n'
        '\tvar art := CardFace.art_for(card.pic_id())   # R637：产物 id 归 0，取图认 pic_id\n',
    ),
]

# ── 5. reward_panel.gd（LF）/ shop_scene.gd（CRLF）────────────────────────
reward_pairs = [
    (
        '\tvar art := CardFace.art_for(card.id)\n',
        '\tvar art := CardFace.art_for(card.pic_id())   # R637：产物 id 归 0，取图认 pic_id\n',
    ),
]
shop_pairs = [
    (
        '\tvar art := CardFace.art_for(card.id, false, 0)\n',
        '\tvar art := CardFace.art_for(card.pic_id(), false, 0)\n',
    ),
]

patch("scripts/card_data.gd", card_data_pairs, True)
patch("scripts/assemble_rules.gd", assemble_pairs, False)
patch("scripts/card_face.gd", card_face_pairs, False)
patch("scripts/battle_scene.gd", battle_pairs, True)
patch("scripts/reward_panel.gd", reward_pairs, False)
patch("scripts/shop_scene.gd", shop_pairs, True)
print("ALL DONE")
