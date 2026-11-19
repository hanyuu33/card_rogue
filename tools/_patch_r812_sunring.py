# -*- coding: utf-8 -*-
"""R812：太阳指环 6082 —— 「每个我方回合开始」改为「**每场战斗一次**」。

口径变化只落在触发次数上：
- 触发时机不动（仍是 `_begin_turn(SIDE_SELF)`，在所有召唤 / 成长 / 战吼之后、回合头日志之前）；
- 新增 `_sun_ring_used` 一个保险丝，放完即置位。**引擎实例 = 一场战斗**，所以不需要
  额外做战斗开始的复位（同缺陷时钟 `_clock_plays` 的理由）。
- **空场不白烧额度**：场上一个敌人都没有时直接 return，不置位 —— 免得「开场没敌人」
  的关卡把这一场的一次性效果空放掉。
- 演出由「每回合都放」升级为「一场就这一下」：爆点放大、加一次轻抖，仍**不弹横幅**
  （回合头本来就有「我方回合 · 第 N 回合」的横幅，再压一条会被它盖掉）。
"""
import io

ROOT = "E:/work/card_rogue/"


def read(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def write(rel, text):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(text)


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次（应为 1）" % (tag, n)
    return text.replace(old, new)


# ─────────────────────────── ① 引擎：保险丝 + 守卫 ───────────────────────────
p = "scripts/game_engine.gd"
s = read(p)

s = sub(s,
        "var _sun_ring_busy:= false\r\n",
        "var _sun_ring_busy:= false\r\n"
        "var _sun_ring_used:= false   # R812：每场战斗只放一次（引擎即一场战斗，天然复位）\r\n",
        "field")

s = sub(s,
        "# R810 太阳指环（6082，一般档）：**每个我方回合开始**，对所有敌方单位各 SUN_RING_DMG 点伤害。\r\n"
        "#   与风妖精 6042 同一套写法（`_hit_unit` → `_destroy_dead` → `action` 演出），\r\n"
        "#   差别只在触发时机。伤害走 `_hit_unit` → 护盾 / 减伤 / 光环 / 鱼叉计数全部照常生效。\r\n",
        "# R810 太阳指环（6082，一般档）：对所有敌方单位各 SUN_RING_DMG 点伤害。\r\n"
        "#   ⚠️ R812 起触发次数改为**每场战斗一次**（原先每个我方回合都放）。\r\n"
        "#   与风妖精 6042 同一套写法（`_hit_unit` → `_destroy_dead` → `action` 演出），\r\n"
        "#   差别只在触发时机与次数。伤害走 `_hit_unit` → 护盾 / 减伤 / 光环 / 鱼叉计数全部照常生效。\r\n",
        "consts")

s = sub(s,
        "\t\t# R810 太阳指环（6082）：**每个我方回合开始**，对所有敌方单位 3 点伤害。\r\n",
        "\t\t# R810 太阳指环（6082）：**每场战斗一次**，对所有敌方单位 3 点伤害（R812 由每回合改来）。\r\n",
        "callsite")

OLD_DOC = ("func _sun_ring_tick() -> int:\r\n"
           "\t## R810 太阳指环（6082）：**每个我方回合开始**，对所有敌方单位各 SUN_RING_DMG 点伤害。\r\n"
           "\t## 与风妖精 6042 逐款同构（伤害走 `_hit_unit`、致死统一交 `_destroy_dead()`、\r\n"
           "\t## 最后 `action.emit` 让界面演出），差别只有触发时机。\r\n"
           "\t## ⚠️ 格子先 `sort()`：Dictionary 迭代顺序不可依赖，回放 / 同种子必须一致。\r\n"
           "\t## ⚠️ 只打**场上的敌方单位**，不直击敌方 HP（没有单位时效果落空）。\r\n"
           "\tif not self_relics.has(SUN_RING_ID) or _sun_ring_busy:\r\n"
           "\t\treturn 0\r\n")
NEW_DOC = ("func _sun_ring_tick() -> int:\r\n"
           "\t## R810 太阳指环（6082）：对所有敌方单位各 SUN_RING_DMG 点伤害。\r\n"
           "\t## **R812：每场战斗只放一次**（原先每个我方回合都放）—— 保险丝是 `_sun_ring_used`。\r\n"
           "\t## 为什么不用另做一个「战斗开始复位」：`GameEngine` 实例本身就是一场战斗，\r\n"
           "\t## 字段跟着实例走，换一场新战斗就是新实例（同缺陷时钟 `_clock_plays` 的理由）。\r\n"
           "\t## 与风妖精 6042 逐款同构（伤害走 `_hit_unit`、致死统一交 `_destroy_dead()`、\r\n"
           "\t## 最后 `action.emit` 让界面演出），差别只有触发时机与次数。\r\n"
           "\t## ⚠️ 格子先 `sort()`：Dictionary 迭代顺序不可依赖，回放 / 同种子必须一致。\r\n"
           "\t## ⚠️ 只打**场上的敌方单位**，不直击敌方 HP（没有单位时效果落空）。\r\n"
           "\tif not self_relics.has(SUN_RING_ID) or _sun_ring_busy or _sun_ring_used:\r\n"
           "\t\treturn 0\r\n")
s = sub(s, OLD_DOC, NEW_DOC, "doc")

# 空场不烧额度：只在真有目标时置位
s = sub(s,
        "\tif cells.is_empty():\r\n"
        "\t\t_sun_ring_busy = false\r\n"
        "\t\treturn 0\r\n"
        "\tcells.sort()\r\n",
        "\tif cells.is_empty():\r\n"
        "\t\t_sun_ring_busy = false\r\n"
        "\t\treturn 0\r\n"
        "\t# R812：**只有真的打到人才烧掉这一场的一次性额度** —— 开场还没有敌人的关卡\r\n"
        "\t# 不该把效果空放掉。放在这里（而不是函数入口）是有意的。\r\n"
        "\t_sun_ring_used = true\r\n"
        "\tcells.sort()\r\n",
        "consume")
write(p, s)

# ─────────────────────────── ② 演出：一场只这一下，加重 ───────────────────────────
p = "scripts/battle_scene.gd"
s = read(p)

s = sub(s,
        "\t\t\t# R810 太阳指环（6082）：每个我方回合开始，对所有敌方单位 3 点伤害。\r\n"
        "\t\t\t# 与风妖精同一套「全体 ping」演出，只换色：日轮 = 金 + 象牙白。\r\n"
        "\t\t\t# ⚠️ 每回合都会放 → **不弹横幅、不拉镜头**（那是大事件的位置），\r\n"
        "\t\t\t#    节奏靠逐格 60ms 错开：看得见「一圈扫过去」，又不至于卡住操作。\r\n",
        "\t\t\t# R810 太阳指环（6082）：对所有敌方单位 3 点伤害。R812 起**每场战斗只放一次**。\r\n"
        "\t\t\t# 与风妖精同一套「全体 ping」演出，只换色：日轮 = 金 + 象牙白。\r\n"
        "\t\t\t# 一场就这一下 → 爆点换成 big + 加一次轻抖，让它有分量；\r\n"
        "\t\t\t# ⚠️ 仍**不弹横幅** —— 回合头本来就有「我方回合 · 第 N 回合」的横幅，\r\n"
        "\t\t\t#    这里是同一拍触发的，再压一条会被它盖掉（不是「每回合所以不弹」那个理由了）。\r\n",
        "fxdoc")

s = sub(s,
        "\t\t\t\t_bursts.append({\"pos\": _cell_center(sc), \"sc\": _grid_scroll,\r\n"
        "\t\t\t\t\t\t\"start\": sr_at, \"dur\": 520, \"col\": Color(\"f2c14e\"), \"big\": false})\r\n",
        "\t\t\t\t_bursts.append({\"pos\": _cell_center(sc), \"sc\": _grid_scroll,\r\n"
        "\t\t\t\t\t\t\"start\": sr_at, \"dur\": 620, \"col\": Color(\"f2c14e\"), \"big\": true})\r\n",
        "burst")

s = sub(s,
        "\t\t\tsfx.play(\"spell\")\r\n"
        "\t\t\tvar sr_d := int(data.get(\"dmg\", 0))\r\n"
        "\t\t\tvar sr_n := int(data.get(\"hits\", 0))\r\n",
        "\t\t\tsfx.play(\"spell\")\r\n"
        "\t\t\t_shake(4.0, 260)     # R812：一场只这一下，给点分量（幅度小于缺陷时钟的 6.0）\r\n"
        "\t\t\tvar sr_d := int(data.get(\"dmg\", 0))\r\n"
        "\t\t\tvar sr_n := int(data.get(\"hits\", 0))\r\n",
        "shake")
write(p, s)

# ─────────────────────────── ③ 描述：五处齐改 ───────────────────────────
DESCS = [
    ("relics.json",
     "每个回合，对所有敌方单位造成 3 点伤害。",
     "每场战斗一次，对所有敌方单位造成 3 点伤害。"),
    ("i18n/noncard_zh_canonical.json",
     "每个回合，对所有敌方单位造成 3 点伤害。",
     "每场战斗一次，对所有敌方单位造成 3 点伤害。"),
    ("i18n/noncard_en.json",
     "Each turn, deal 3 damage to all enemy units.",
     "Once per battle, deal 3 damage to all enemy units."),
    ("i18n/noncard_ja.json",
     "毎ターン、敵ユニットすべてに 3 ダメージを与える。",
     "戦闘中1回のみ、敵ユニットすべてに 3 ダメージを与える。"),
    ("i18n/noncard_es.json",
     "Cada turno, infliges 3 de daño a todas las unidades enemigas.",
     "Una vez por batalla, infliges 3 de daño a todas las unidades enemigas."),
]
for rel, old, new in DESCS:
    s = read(rel)
    s = sub(s, old, new, rel)
    write(rel, s)

# ─────────────────────────── ④ 测试：老断言改口径 + 新增三条 ───────────────────────────
p = "scripts/test_engine.gd"
s = read(p)

s = sub(s,
        "6082: [\"太阳指环\", \"一般\", \"每个回合，对所有敌方单位造成 3 点伤害。\"],",
        "6082: [\"太阳指环\", \"一般\", \"每场战斗一次，对所有敌方单位造成 3 点伤害。\"],",
        "desclock")

s = sub(s,
        "\t# ── ③ 太阳指环：每个我方回合开始打全体敌人 3 点 ──\r\n",
        "\t# ── ③ 太阳指环：**每场战斗一次**，打全体敌人 3 点（R812 由「每回合」改来）──\r\n",
        "secdoc")

s = sub(s,
        "\tr810_e3.end_turn()     # 我方 → 敌方\r\n"
        "\tr810_e3.end_turn()     # 敌方 → 我方（第二个我方回合）\r\n"
        "\tcheck(r810_foe.health == r810_f0 - 6,\r\n"
        "\t\t\t\"R810 太阳指环：第二个我方回合再打一次（累计 -6，实际 %d）\"\r\n"
        "\t\t\t% (r810_f0 - r810_foe.health))\r\n",
        "\tr810_e3.end_turn()     # 我方 → 敌方\r\n"
        "\tr810_e3.end_turn()     # 敌方 → 我方（第二个我方回合）\r\n"
        "\tcheck(r810_foe.health == r810_f0 - 3,\r\n"
        "\t\t\t\"R812 太阳指环：**每场只打一次** —— 第二个我方回合不再掉血（仍是 -3，实际 %d）\"\r\n"
        "\t\t\t% (r810_f0 - r810_foe.health))\r\n"
        "\r\n"
        "\t# 换一场战斗（= 新引擎实例）→ 一次性额度重新可用\r\n"
        "\tvar r810_e3b := _new_engine([], 40, 40)\r\n"
        "\tr810_e3b.self_relics = RunState.active_relics()\r\n"
        "\tvar r810_foe_b := r810_e3b.state.place(\r\n"
        "\t\t\tCardData.from_dict(r810_cards.get_card(1051).to_dict()),\r\n"
        "\t\t\tVector2i(1, 0), GameEngine.SIDE_OPPONENT)\r\n"
        "\tvar r810_fb0: int = r810_foe_b.health\r\n"
        "\tr810_e3b._begin_turn(GameEngine.SIDE_SELF)\r\n"
        "\tcheck(r810_foe_b.health == r810_fb0 - 3,\r\n"
        "\t\t\t\"R812 太阳指环：换一场战斗后重新可用（%d → %d）\"\r\n"
        "\t\t\t% [r810_fb0, r810_foe_b.health])\r\n"
        "\r\n"
        "\t# 空场不白烧额度：开场没有敌人时不置位，敌人后到场仍吃得到\r\n"
        "\tvar r810_e3c := _new_engine([], 40, 40)\r\n"
        "\tr810_e3c.self_relics = RunState.active_relics()\r\n"
        "\tr810_e3c._begin_turn(GameEngine.SIDE_SELF)     # 场上一个敌人都没有\r\n"
        "\tcheck(not r810_e3c._sun_ring_used,\r\n"
        "\t\t\t\"R812 太阳指环：空场不消耗「每场一次」的额度\")\r\n"
        "\tvar r810_late := r810_e3c.state.place(\r\n"
        "\t\t\tCardData.from_dict(r810_cards.get_card(1051).to_dict()),\r\n"
        "\t\t\tVector2i(1, 0), GameEngine.SIDE_OPPONENT)\r\n"
        "\tvar r810_l0: int = r810_late.health\r\n"
        "\tr810_e3c._sun_ring_tick()\r\n"
        "\tcheck(r810_late.health == r810_l0 - 3 and r810_e3c._sun_ring_used,\r\n"
        "\t\t\t\"R812 太阳指环：敌人后到场仍吃得到，吃到后额度才置位（%d → %d）\"\r\n"
        "\t\t\t% [r810_l0, r810_late.health])\r\n",
        "tests")

s = sub(s,
        "\tvar r810_place_src := FileAccess.get_file_as_string(\"res://scripts/placement.gd\")\r\n",
        "\tcheck_src(r810_eng_src.contains(\"_sun_ring_used\"),\r\n"
        "\t\t\t\"R812 守卫：太阳指环有「每场一次」的保险丝 `_sun_ring_used`\")\r\n"
        "\tcheck_src(r810_eng_src.contains(\"or _sun_ring_used\"),\r\n"
        "\t\t\t\"R812 守卫：`_sun_ring_tick` 的入口判据带上 `_sun_ring_used`\")\r\n"
        "\tvar r810_place_src := FileAccess.get_file_as_string(\"res://scripts/placement.gd\")\r\n",
        "guard")
write(p, s)

print("R812 patch OK")
