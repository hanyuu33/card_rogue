# -*- coding: utf-8 -*-
"""R797 数据与引擎：龟壳 6078（受伤 -2）+ 河豚 7015（回弹）+ 工具售价 -5。"""
import json
import io

ROOT = "E:/tmp/wt794/"
fails = []


def patch(path, pairs, nl="\n"):
    raw = open(ROOT + path, "rb").read().decode("utf-8")
    for old, new in pairs:
        o = old.replace("\n", nl)
        n = new.replace("\n", nl)
        c = raw.count(o)
        if c != 1:
            fails.append("%s: 锚点命中 %d 次 → %r" % (path, c, old[:48]))
            continue
        raw = raw.replace(o, n)
    open(ROOT + path, "wb").write(raw.encode("utf-8"))
    crlf = raw.count("\r\n")
    lf = raw.count("\n")
    print("patched %-28s CRLF %d / LF %d" % (path, crlf, lf))


# ---------- 1. traps.json：售价 -5 + 河豚 7015 ----------
tp = ROOT + "traps.json"
d = json.loads(open(tp, encoding="utf-8").read())
prices = {7001: 25, 7002: 35, 7003: 25, 7004: 35, 7005: 45,
          7006: 30, 7008: 25, 7013: 50, 7014: 35}
for t in d["traps"]:
    if t["id"] in prices:
        assert t["price"] == prices[t["id"]] + 5, (t["id"], t["price"])
        t["price"] = prices[t["id"]]
assert len(d["traps"]) == 14
d["traps"].append({
    "id": 7015, "name": "河豚", "price": 25, "damage": 3, "bounce": 1,
    "desc": "拖到战场空格上放置。敌人踩到时被弹回来时的格子并受到 3 点伤害，用掉后从工具栏移除。",
    "icon": "tool_puffer",
})
open(tp, "w", encoding="utf-8", newline="").write(
    json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print("traps.json：%d 件，7015 河豚 25 金" % len(d["traps"]))

# ---------- 2. relics.json：龟壳 6078 ----------
rp = ROOT + "relics.json"
d = json.loads(open(rp, encoding="utf-8").read())
assert d["relics"][-1]["id"] == 6077
d["relics"].append({
    "id": 6078, "name": "龟壳", "kind": "战斗", "source": "奖励", "tier": "一般",
    "desc": "你上回合没有攻击过的己方单位，受到的伤害 -2（至少仍受 1 点）。",
})
open(rp, "w", encoding="utf-8", newline="").write(
    json.dumps(d, ensure_ascii=False, indent=2) + "\n")
print("relics.json：%d 件" % len(d["relics"]))

# ---------- 3. trap_data.gd：bounce ----------
patch("scripts/trap_data.gd", [
    ("""## R796：智慧药剂 7014""",
     """## R797：河豚 7015 —— 踩到的单位**回弹这么多格**（1 = 回到来时的格子）。
## 回弹方向不走 `_knockback`（那是「朝对方后排直推」）：河豚是「原地弹回」，
## 只有「没有来路」（效果直达 / 上一格已被占）时，才改朝**河豚所属方**的方向弹一格。
var bounce := 0
## R796：智慧药剂 7014"""),
    ("""\tt.draw_cards = int(d.get("draw_cards", 0))""",
     """\tt.draw_cards = int(d.get("draw_cards", 0))
\tt.bounce = int(d.get("bounce", 0))"""),
])

# ---------- 4. placement.gd：attacked_prev_turn ----------
patch("scripts/placement.gd", [
    ("""var master_sword_atk: int = 0""",
     """var master_sword_atk: int = 0
## R797 龟壳（6078）：「**上一个自己的回合**有没有攻击过」。
## 置位只在 `attack()` / `attack_hp()`（普攻的两个结算口），复位只在
## `FieldState.reset_units()`（自己的回合开始）—— 于是**敌方回合**里读到的就是这个单位
## 「上回合打没打过」，正是龟壳的判据窗口。别用 `tapped` 代替：横置会被眩晕 / 冰冻 /
## 沉睡复用，那是「不能行动」不是「没攻击」。
var attacked_prev_turn: bool = false"""),
])

# ---------- 5. field_state.gd：回合开始复位 ----------
patch("scripts/field_state.gd", [
    ("""\t\t\tp.did_move = false""",
     """\t\t\tp.did_move = false
\t\t\t# R797 龟壳：新回合开始 = 上一回合的「攻击过」作废。
\t\t\tp.attacked_prev_turn = false"""),
])
