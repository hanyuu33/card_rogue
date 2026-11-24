# -*- coding: utf-8 -*-
"""R841 数据层：锤子 7018（直击眩晕）/ 润滑油 7019（选手卡减费）。

只动数据与定义，不改逻辑。每处 exact-replace 都带 assert count==1。
"""
import io
import json

ROOT = "E:/work/card_rogue/"


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def rep(p, old, new, tag):
    s = read(p)
    crlf = "\r\n" in s
    norm = s.replace("\r\n", "\n")
    cnt = norm.count(old)
    assert cnt == 1, "%s：锚点命中 %d 次（要求 1）" % (tag, cnt)
    out = norm.replace(old, new)
    if crlf:
        out = out.replace("\n", "\r\n")
    write(p, out)
    print("ok  %s" % tag)


# ---------- ① traps.json ----------
rep("traps.json",
    '''      "desc": "拖到战场空格上放置。该格在 3 个我方回合内不可使用：任何单位都无法进入或经过，用掉后从工具栏移除。", "icon": "tool_garlic" }
  ]''',
    '''      "desc": "拖到战场空格上放置。该格在 3 个我方回合内不可使用：任何单位都无法进入或经过，用掉后从工具栏移除。", "icon": "tool_garlic" },
    { "id": 7018, "name": "锤子", "price": 40, "direct_stun": 1,
      "desc": "拖到敌方单位身上使用。被砸中的目标眩晕一回合（下个回合不能行动），用掉后从工具栏移除。", "icon": "tool_hammer" },
    { "id": 7019, "name": "润滑油", "price": 30, "pick_kind": "hand_down", "cost_down": 3,
      "desc": "轻点两下即可使用，无需拖到战场格子上。选一张手牌，其费用在本场战斗中 -3，用掉后从工具栏移除。", "icon": "tool_oil" }
  ]''',
    "traps.json 加 7018/7019")

# 立刻验 JSON 与条数（格式错当场炸，别留到回归）
d = json.loads(read("traps.json"))
ids = [t["id"] for t in d["traps"]]
assert ids[-2:] == [7018, 7019] and len(ids) == 19, ids
print("    traps.json 解析 OK，条数 %d" % len(ids))

# ---------- ② trap_data.gd ----------
rep("scripts/trap_data.gd",
    '''## R754：「不受随机获得影响」''',
    '''## R841：锤子 7018 —— 拖到**敌方单位**身上，使其中招后眩晕 N 个回合（1 = 下个回合不能行动）。
## 与石头 7012 的 `direct_damage` 共用同一个落点口（`trap_drop_cells()` → `trap_target_cells()`），
## 区别只在结算：那个走 `_hit_unit`，这个走 `_apply_stun`（眩晕的唯一入口，别另开一条）。
## 刻意**不进** `is_usable()` —— 它要选目标，走拖放那条路，不是「轻点即结算」。
var direct_stun := 0
## R841：润滑油 7019 —— 选卡型里「选一张**手卡**，本场战斗内费用 -N」。
## 只在 `pick_kind == "hand_down"` 时被读；落地走 `state.hand_cost_delta`
## （手卡内减费的唯一口径：卡一旦离手就自动恢复原价，再抓回手里又生效）。
var cost_down := 0
## R754：「不受随机获得影响」''',
    "trap_data.gd 字段")

rep("scripts/trap_data.gd",
    '''	t.block_turns = int(d.get("block_turns", 0))''',
    '''	t.block_turns = int(d.get("block_turns", 0))
	t.direct_stun = int(d.get("direct_stun", 0))
	t.cost_down = int(d.get("cost_down", 0))''',
    "trap_data.gd 解析")

# ---------- ③ trap_art.gd 配色兜底 ----------
rep("scripts/trap_art.gd",
    '''		7017: return Color(0.76, 0.82, 0.52)
	return Color(0.80, 0.76, 0.66)''',
    '''		7017: return Color(0.76, 0.82, 0.52)
		# R841 锤子 —— 木槌的黄褐；润滑油 —— 琥珀油色。
		7018: return Color(0.80, 0.62, 0.34)
		7019: return Color(0.95, 0.72, 0.25)
	return Color(0.80, 0.76, 0.66)''',
    "trap_art.gd color_of")

# ---------- ④ 三语 ----------
I18N = {
    "en": {
        "7018": {"name": "Mallet",
                 "desc": "Drag it onto an enemy unit to strike it. The target is stunned for one turn (it cannot act on its next turn); the tool is then used up."},
        "7019": {"name": "Lubricant Oil",
                 "desc": "Tap it twice to use; no dragging onto the battlefield is needed. Choose a card in your hand: its cost is reduced by 3 for the rest of this battle; the tool is then used up."},
    },
    "ja": {
        "7018": {"name": "木槌",
                 "desc": "敵ユニットにドラッグして使う。当たった対象は1ターンの間スタンする（次のターンは行動できない）。使用後は消費される。"},
        "7019": {"name": "潤滑油",
                 "desc": "2回タップするだけで使え、戦場にドラッグする必要はない。手札を1枚選び、この戦闘の間そのカードのコストを -3 する。使用後は消費される。"},
    },
    "es": {
        "7018": {"name": "Mazo",
                 "desc": "Arrástralo sobre una unidad enemiga para golpearla. El objetivo queda aturdido un turno (no puede actuar en su siguiente turno); después, la herramienta se consume."},
        "7019": {"name": "Aceite lubricante",
                 "desc": "Tócala dos veces para usarla; no hace falta arrastrarla al campo de batalla. Elige una carta de tu mano: su coste se reduce en 3 durante el resto de este combate; después, la herramienta se consume."},
    },
}

for lang, add in I18N.items():
    p = "i18n/traps_%s.json" % lang
    s = read(p)
    crlf = "\r\n" in s
    norm = s.replace("\r\n", "\n")
    tail = '''  "7017": {'''
    assert norm.count(tail) == 1, "%s：7017 锚点 %d 次" % (p, norm.count(tail))
    # 在 7017 那一块之后追加两条：直接找到 7017 块的收尾 "  }\n }"
    idx = norm.index(tail)
    close = norm.index("\n  }\n }\n}", idx) + len("\n  }")
    block = ""
    for tid in ("7018", "7019"):
        e = add[tid]
        block += ',\n  "%s": {\n   "name": %s,\n   "desc": %s\n  }' % (
            tid, json.dumps(e["name"], ensure_ascii=False),
            json.dumps(e["desc"], ensure_ascii=False))
    out = norm[:close] + block + norm[close:]
    if crlf:
        out = out.replace("\n", "\r\n")
    write(p, out)
    dd = json.loads(out)
    assert len(dd["traps"]) == 19, (p, len(dd["traps"]))
    print("ok  %s 追加 7018/7019（现 %d 条）" % (p, len(dd["traps"])))

# ---------- ⑤ demo_scope.json（这批新工具要进试玩）----------
s = read("demo_scope.json")
crlf = "\r\n" in s
norm = s.replace("\r\n", "\n")
old = '''    7015,
    7016
  ]'''
assert norm.count(old) == 1, "demo_scope traps 锚点 %d 次" % norm.count(old)
# ⚠️ 大蒜 7017 不在试玩基线里（R839 当时明确「新工具默认不进」）——
# 这次店长只说「这批新工具」，所以只补 7018 / 7019，别顺手动 7017。
out = norm.replace(old, '''    7015,
    7016,
    7018,
    7019
  ]''')
if crlf:
    out = out.replace("\n", "\r\n")
write("demo_scope.json", out)
dsc = json.loads(out)
assert dsc["traps"][-2:] == [7018, 7019] and len(dsc["traps"]) == 18, dsc["traps"]
print("ok  demo_scope.json traps -> %d 件" % len(dsc["traps"]))
