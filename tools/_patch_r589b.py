# -*- coding: utf-8 -*-
"""R589 第二批：引擎侧 —— 主动发动通用化 / 使用后分发 / 生命归零钩子 / 七个动作。

用法：
    python tools/_patch_r589b.py --check-only
    python tools/_patch_r589b.py
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv
PATCHES = []


def read(rel):
    with io.open(os.path.join(ROOT, rel), "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(rel, text):
    with io.open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as f:
        f.write(text)


def patch(rel, old, new, note):
    PATCHES.append((rel, old, new, note))


# ══════════════════════════════════════════════════════════════════════════
# ① 主动发动：从「熊专属」升级成通用扳机
# ══════════════════════════════════════════════════════════════════════════
patch("scripts/game_engine.gd",
      '''func can_activate(cell: Vector2i, side:= SIDE_SELF) -> bool:
\t## 主动发动（熊 8004「回春」）：该单位尚未行动完（未横置）、带 BEAR_TRAIT，
\t## 且这次在场还没发动过 → 可发动。
\tvar p:= state.unit_at(cell)
\tif p == null or p.owner != side or p.tapped:
\t\treturn false
\tif not p.card.traits.has(BEAR_TRAIT):
\t\treturn false
\treturn not p.ability_used


func activate(cell: Vector2i, side:= SIDE_SELF) -> bool:
\t## 主动发动：代替行动回复 BEAR_HEAL 点生命（不超过生命上限），之后横置。
\tvar p:= state.unit_at(cell)
\tif not can_activate(cell, side):
\t\treturn false
\tp.ability_used = true
\tvar before:= p.health
\tp.health = mini(p.card.health, p.health + BEAR_HEAL)
\tvar gained:= p.health - before
\t_log("%s 发动回春：回复 %d 点生命（当前 %d）" % [p.card.card_name, gained, p.health])
\taction.emit("bear_heal", {"cell": cell, "amount": gained, "side": side,
\t\t\t"name": p.card.card_name})
\t_tap(p, "发动回春")
\treturn true''',
      '''func _has_active_ability(card: CardData) -> bool:
\t## R589：「主动发动」从「熊专属」升级成**通用扳机** —— 组合产物的上半扳机选了 `active`，
\t## 产物就自带这条能力，效果由它上/下半的动作表决定（可能是回复、也可能是伤害 / 抽牌）。
\t## 判据只有这一处：战斗页的徽标、点击、按 F 全部经 `can_activate()`，不另写白名单。
\t##   · 组合产物：`assemble.trigger == "active"`；
\t##   · 熊 8004 本体：卡库原生卡没有 assemble 段，仍按 trait「回春」认（老口径不变）。
\tif card == null:
\t\treturn false
\tif not card.assemble.is_empty() and str(card.assemble.get("trigger", "")) == "active":
\t\treturn true
\treturn card.traits.has(BEAR_TRAIT)


func can_activate(cell: Vector2i, side:= SIDE_SELF) -> bool:
\t## 主动发动：该单位尚未行动完（未横置）、具备主动能力，且这次在场还没发动过 → 可发动。
\tvar p:= state.unit_at(cell)
\tif p == null or p.owner != side or p.tapped:
\t\treturn false
\tif not _has_active_ability(p.card):
\t\treturn false
\treturn not p.ability_used


func activate(cell: Vector2i, side:= SIDE_SELF) -> bool:
\t## 主动发动：花掉这次行动（之后横置），每单位在场只能发动一次 ——
\t## 与 `AssembleRules.TRIGGER_RULES["active"]` 印在产物卡面上的规则句是**同一条口径**。
\tvar p:= state.unit_at(cell)
\tif not can_activate(cell, side):
\t\treturn false
\tp.ability_used = true
\tvar before:= p.health
\tif p.card.assemble.is_empty():
\t\t# 熊 8004 本体：卡库原生卡没有 assemble 段，走它自己的回春数值。
\t\tp.health = mini(p.card.health, p.health + BEAR_HEAL)
\t\tvar gained:= p.health - before
\t\t_log("%s 发动回春：回复 %d 点生命（当前 %d）" % [p.card.card_name, gained, p.health])
\t\taction.emit("bear_heal", {"cell": cell, "amount": gained, "side": side,
\t\t\t\t"name": p.card.card_name})
\telse:
\t\t# R589：组合产物 —— 上/下半动作全部由 `_assemble_execute` 那一套循环结算。
\t\t# 不在这里重写第二份：重写必然和组合页上的文案漂移。
\t\t_assemble_execute(p, cell, "active")
\t\taction.emit("assemble_active", {"cell": cell, "side": side,
\t\t\t\t"name": p.card.card_name, "amount": p.health - before})
\t_tap(p, "主动发动")
\treturn true''',
      "主动发动通用化")

# ② 七个动作的母卡实现口加参数（唯一口，组合与母卡共用）
patch("scripts/game_engine.gd",
      '''func _sprite_trigger() -> void :
\tstate.self_next_effect_reduction = SPRITE_EFFECT_DISCOUNT
\t_log("小精灵：本回合下一张效果卡费用 -%d" % SPRITE_EFFECT_DISCOUNT)''',
      '''func _sprite_trigger(n: int = SPRITE_EFFECT_DISCOUNT, source: String = "小精灵") -> void :
\t## 小精灵 9074「使用后，你使用的下一张效果卡费用减少 2」的**唯一实现口**。
\t## R589：组合动作 `next_effect_discount` 也走这里，不再各写一份。
\t## ⚠️ 这个减费**跨回合保留**，只有用掉那一张效果卡时才清零（见 end_turn 处的注释）。
\tstate.self_next_effect_reduction = n
\t_log("%s：本回合下一张效果卡费用 -%d" % [source, n])''',
      "_sprite_trigger 加参")

patch("scripts/game_engine.gd",
      '''func _dove_trigger() -> void :
\tstate.self_next_ally_reduction = TURTLE_DOVE_DISCOUNT
\t_log("斑鸠：本回合下一个盟友费用 -%d" % TURTLE_DOVE_DISCOUNT)''',
      '''func _dove_trigger(n: int = TURTLE_DOVE_DISCOUNT, source: String = "斑鸠") -> void :
\t## 斑鸠 9052「使用后，本回合使用下一个盟友时费用 -1」的**唯一实现口**。
\t## ⚠️ 这个减费只作用于**下一个**盟友：`play_from_hand` 里盟友上场时先把
\t## `self_next_ally_reduction` 清零，再走本函数 —— 顺序反了就是「永远 -1」。
\tstate.self_next_ally_reduction = n
\t_log("%s：本回合下一个盟友费用 -%d" % [source, n])''',
      "_dove_trigger 加参")

patch("scripts/game_engine.gd",
      '''func _demon_fetch(_p: Placement) -> void :''',
      '''func _demon_fetch(_p: Placement, discount: int = DEMON_FETCH_DISCOUNT,
\t\tsource: String = "水元素") -> void :
\t## 水元素 9068「使用时，从卡组将一张效果卡加入手卡，费用减少 2」的**唯一实现口**。
\t## R589：组合动作 `add_effect_from_deck` 也走这里（张数由调用方循环）。''',
      "_demon_fetch 签名加参")

patch("scripts/game_engine.gd",
      '''\tif cand.is_empty():
\t\t_log("水元素：卡组里没有效果卡")
\t\treturn
\tvar pick: int = cand[rng.randi() % cand.size()]
\tvar chosen: CardData = state.deck[pick]
\tstate.deck.remove_at(pick)
\t# R281：这条路径**绕开了 `FieldState.draw()`**，取到的是卡库共享实例 —— 直接给「它」''',
      '''\tif cand.is_empty():
\t\t_log("%s：卡组里没有效果卡" % source)
\t\treturn
\tvar pick: int = cand[rng.randi() % cand.size()]
\tvar chosen: CardData = state.deck[pick]
\tstate.deck.remove_at(pick)
\t# R281：这条路径**绕开了 `FieldState.draw()`**，取到的是卡库共享实例 —— 直接给「它」''',
      "_demon_fetch 空卡组日志")

patch("scripts/game_engine.gd",
      '''\t_grant_to_hand(chosen, "水元素")
\tstate.card_discount[chosen] = int(state.card_discount.get(chosen, 0)) + DEMON_FETCH_DISCOUNT
\t_log("水元素：从卡组取到效果卡「%s」，它的费用 -%d" % [
\t\tchosen.card_name, DEMON_FETCH_DISCOUNT])''',
      '''\t_grant_to_hand(chosen, source)
\tstate.card_discount[chosen] = int(state.card_discount.get(chosen, 0)) + discount
\t_log("%s：从卡组取到效果卡「%s」，它的费用 -%d" % [
\t\tsource, chosen.card_name, discount])''',
      "_demon_fetch 主体改用 source/discount")

patch("scripts/game_engine.gd",
      '''func _rat_trigger() -> void :''',
      '''func _rat_trigger(source: String = "巨鼠") -> void :
\t## R589：组合动作 `fetch_cheapest_ally` 复用同一个入口（`source` 只影响日志）。''',
      "_rat_trigger 加参")

patch("scripts/game_engine.gd",
      '''\tif cand.is_empty():
\t\t_log("巨鼠：抽牌库里没有盟友")
\t\treturn''',
      '''\tif cand.is_empty():
\t\t_log("%s：抽牌库里没有盟友" % source)
\t\treturn''',
      "_rat_trigger 空池日志")

patch("scripts/game_engine.gd",
      '''\t_grant_to_hand(chosen, "巨鼠")
\t_log("巨鼠：从抽牌库取到 %d 费盟友 %s" % [min_cost, chosen.card_name])''',
      '''\t_grant_to_hand(chosen, source)
\t_log("%s：从抽牌库取到 %d 费盟友 %s" % [source, min_cost, chosen.card_name])''',
      "_rat_trigger 主体改用 source")

# ③ 影魔：抽成唯一口
patch("scripts/game_engine.gd",
      '''func _shadow_demon_enter(p: Placement) -> void:
\t## 影魔（8007）打出时：手卡中所有技能牌本回合费用 -1；
\t## 手卡每有一张费用为 0 的技能卡 → 这张卡 +3 生命。
\tvar zero := 0
\tfor c: CardData in state.hand:
\t\tif c.is_spell():
\t\t\tstate.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + 1
\t\t\tif not c.x_cost and c.cost == 0:
\t\t\t\tzero += 1
\tif zero > 0:
\t\tp.health += SHADOW_DEMON_HP_PER * zero
\t_log("影魔：手卡技能牌本回合 -1 费；0 费技能卡 %d 张 → 生命 +%d（当前 %d）" % [
\t\t\tzero, SHADOW_DEMON_HP_PER * zero, p.health])''',
      '''func _discount_hand_skills(p: Placement, n: int, hp_per: int, source: String) -> int:
\t## 影魔 8007 的**唯一实现口**（R589 起组合动作 `hand_skill_discount` /
\t## `hp_per_zero_skill` 都走这里）：
\t##   · 手卡中所有技能牌本回合费用 -n（走 `turn_card_discount`，回合结束自动清空）；
\t##   · 手卡每有一张**费用为 0** 的技能卡 → `p` 获得 +hp_per 生命。
\t## ⚠️ 0 费判定必须排除 X 费卡（`x_cost` 的 cost 也记 0，但它不是「0 费卡」）。
\t## ⚠️ n = 0 时不写减费表 —— 否则攒一堆「+0」条目，排查时看着像减了费。
\tvar zero := 0
\tfor c: CardData in state.hand:
\t\tif not c.is_spell():
\t\t\tcontinue
\t\tif n > 0:
\t\t\tstate.turn_card_discount[c] = int(state.turn_card_discount.get(c, 0)) + n
\t\tif not c.x_cost and c.cost == 0:
\t\t\tzero += 1
\tif hp_per > 0 and zero > 0:
\t\tp.health += hp_per * zero
\t_log("%s：手卡技能牌本回合 -%d 费；0 费技能卡 %d 张 → 生命 +%d（当前 %d）" % [
\t\t\tsource, n, zero, hp_per * zero, p.health])
\treturn zero


func _shadow_demon_enter(p: Placement) -> void:
\t## 影魔（8007）打出时：手卡中所有技能牌本回合费用 -1；
\t## 手卡每有一张费用为 0 的技能卡 → 这张卡 +3 生命。
\tvar zero := _discount_hand_skills(p, 1, SHADOW_DEMON_HP_PER, "影魔")''',
      "影魔抽成 _discount_hand_skills")

# ④ 生命降到 0 或更低：组合产物与忒修斯本体共用跨越判定
patch("scripts/game_engine.gd",
      '''\tif p == null or p.card == null or p.card.id != THESEUS_ID:
\t\treturn
\tif hp_before <= 0 or p.health > 0:
\t\treturn''',
      '''\t## R589：同一处承接**组合产物**的 `lethal` 扳机 —— 判据从「id == 9222」放宽成
\t## 「assemble.trigger == "lethal" 或 id == 9222」，两类单位共用这一条跨越判定。
\t## 扣血处不许再写第二份（写两份就会出现「本体触发、产物不触发」或反过来）。
\tif p == null or p.card == null:
\t\treturn
\tif hp_before <= 0 or p.health > 0:
\t\treturn
\tif not p.card.assemble.is_empty() \\
\t\t\tand str(p.card.assemble.get("trigger", "")) == "lethal":
\t\t_assemble_execute(p, _cell_of(p), "lethal")
\t\treturn
\tif p.card.id != THESEUS_ID:
\t\treturn''',
      "_theseus_on_blood 扩 lethal 扳机")

# ⑤ 「使用后」在「使用」同一处结算
patch("scripts/game_engine.gd",
      '''\t_assemble_execute(p, cell, "use")
\t_note_card_played(SIDE_SELF, card)''',
      '''\t_assemble_execute(p, cell, "use")
\t# R589：「使用后」与「使用」同处结算 —— 母卡原文写「使用后」的那批（小精灵 / 巨鼠 /
\t# 乌鸦 / 斑鸠）在卡面上是「使用后」，引擎里没有第二套时序，只是文案不同。
\t# 两跳各认各的 key，产物只有一个扳机，不会双触发。
\t_assemble_execute(p, cell, "use_after")
\t_note_card_played(SIDE_SELF, card)''',
      "use_after 分发")

# ⑥ 七个动作的结算分支
patch("scripts/game_engine.gd",
      '''\t\t\t"buff_allies_atk":
\t\t\t\t# R570b：老虎 9038「自己场上其他盟友攻击 +N」（共用 `_buff_other_allies_atk`）。
\t\t\t\t_buff_other_allies_atk(p, value, "组合")''',
      '''\t\t\t"buff_allies_atk":
\t\t\t\t# R570b：老虎 9038「自己场上其他盟友攻击 +N」（共用 `_buff_other_allies_atk`）。
\t\t\t\t_buff_other_allies_atk(p, value, "组合")
\t\t\t# ── R589：七条新动作。每条都复用母卡那一个实现口，别在这里重写一份。 ──
\t\t\t"next_effect_discount":
\t\t\t\t# 小精灵 9074（共用 `_sprite_trigger`）。
\t\t\t\t_sprite_trigger(value, "组合")
\t\t\t"next_ally_discount":
\t\t\t\t# 斑鸠 9052（共用 `_dove_trigger`）。
\t\t\t\t_dove_trigger(value, "组合")
\t\t\t"add_effect_from_deck":
\t\t\t\t# 水元素 9068（共用 `_demon_fetch`）：value = 张数，discount = 每张减费。
\t\t\t\tfor _j in maxi(1, value):
\t\t\t\t\t_demon_fetch(p, int(fx.get("discount", 0)), "组合")
\t\t\t"hand_skill_discount":
\t\t\t\t# 影魔 8007 前半（共用 `_discount_hand_skills`）：只减费、不算生命。
\t\t\t\t_discount_hand_skills(p, value, 0, "组合")
\t\t\t"hp_per_zero_skill":
\t\t\t\t# 影魔 8007 后半：只算生命、不再减一次费（n = 0）。
\t\t\t\t_discount_hand_skills(p, 0, value, "组合")
\t\t\t"fetch_cheapest_ally":
\t\t\t\t# 巨鼠 9046（共用 `_rat_trigger`）。
\t\t\t\t_rat_trigger("组合")
\t\t\t"recall_ally_from_discard":
\t\t\t\t# 乌鸦 9039（共用 `crow_trigger`）：设 `crow_pending`，由战斗页弹选择面板。
\t\t\t\tcrow_trigger()''',
      "七个动作结算分支")

# ⑦ 战斗页：组合产物主动发动的演出
patch("scripts/battle_scene.gd",
      '''\t\t"wild_form_guard":''',
      '''\t\t"assemble_active":
\t\t\t# R589：组合产物的「主动发动」（上半扳机 = active）。与回春同样式，
\t\t\t# 但台词不写具体效果 —— 效果由玩家组合出来的动作决定，可能根本不是回血。
\t\t\tsfx.play("place")
\t\t\tvar aa_pos := _cell_center(data.get("cell", Vector2i(-1, -1)))
\t\t\t_bursts.append({"pos": aa_pos, "sc": _grid_scroll, "start": n, "dur": 520,
\t\t\t\t\t"col": Color("4caf50"), "big": false})
\t\t\tvar aa_amt := int(data.get("amount", 0))
\t\t\tif aa_amt != 0:
\t\t\t\t_floaters.append({"pos": aa_pos + Vector2(0, -12), "sc": _grid_scroll,
\t\t\t\t\t\t"text": "主动发动 +%d" % aa_amt, "col": UiTheme.KIND_EFFECT,
\t\t\t\t\t\t"start": n, "dur": 1400, "size": 18})
\t\t\t_say("❦ %s 主动发动，之后横置" % str(data.get("name", "组合产物")))
\t\t"wild_form_guard":''',
      "battle_scene assemble_active 演出")


def main():
    ok = True
    files = {}
    for rel, old, new, note in PATCHES:
        if rel not in files:
            files[rel] = read(rel)
        cnt = files[rel].count(old)
        use_old, use_new = old, new
        if cnt == 0:
            crlf_old = old.replace("\n", "\r\n")
            if files[rel].count(crlf_old) == 1:
                use_old, use_new = crlf_old, new.replace("\n", "\r\n")
                cnt = 1
        if cnt != 1:
            print("[FAIL] %s：锚点命中 %d 次（要求 1）—— %s" % (rel, cnt, note))
            ok = False
            continue
        files[rel] = files[rel].replace(use_old, use_new, 1)
        print("[ok] %s：%s" % (rel, note))
    if not ok:
        print("\n有锚点没命中，未写任何文件。")
        return 1
    if CHECK:
        print("\n--check-only：锚点全中，未写文件。")
        return 0
    for rel, text in files.items():
        write(rel, text)
        print("[write] %s" % rel)
    return 0


if __name__ == "__main__":
    sys.exit(main())
