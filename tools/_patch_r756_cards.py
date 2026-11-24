# -*- coding: utf-8 -*-
"""R756：三张二层「计量工坊」敌人卡（cards.json）+ 三语 i18n。

9253 常数测量员 / 9254 精密计算者 / 9255 负载增量员
"""
import io
import json

ROOT = "e:/work/card_rogue/"

CARDS = [
    {
        "id": 9253,
        "name": "常数测量员",
        "kind": "盟友",
        "cost": 0,
        "power": 0,
        "health": 60,
        "attack_range": 1,
        "move_speed": 1,
        "rarity": 4,
        "group": "enemy",
        "class": "敌人",
        "traits": ["测量"],
        "affixes": [],
        "effect_text": "作为行动的代替：对所有敌方单位分配 16 点伤害（由近及远，打倒一个就把剩下的分给下一个，超负荷单位只分到刚好归零），分配剩下的伤害由对方 HP 承受。若这次没有对对方 HP 造成伤害，则眩晕一回合。",
        "target_mode": "none",
        "color": "物理",
        "image": "",
    },
    {
        "id": 9254,
        "name": "精密计算者",
        "kind": "盟友",
        "cost": 6,
        "power": 6,
        "health": 60,
        "attack_range": 1,
        "move_speed": 2,
        "rarity": 4,
        "group": "enemy",
        "class": "敌人",
        "traits": ["计算"],
        "affixes": [],
        "effect_text": "对方盟友或工事入场后，若其生命大于 15，则变为 15。此效果在所有入场增益结算之后结算。",
        "target_mode": "none",
        "color": "物理",
        "image": "",
    },
    {
        "id": 9255,
        "name": "负载增量员",
        "kind": "盟友",
        "cost": 4,
        "power": 4,
        "health": 60,
        "attack_range": 1,
        "move_speed": 1,
        "rarity": 4,
        "group": "enemy",
        "class": "敌人",
        "traits": ["增量"],
        "affixes": [],
        "effect_text": "回合开始时，将一张「攻击」和一张「木栅栏」加入对方抽牌库。",
        "target_mode": "none",
        "color": "物理",
        "image": "",
    },
]

I18N = {
    "en": {
        "9253": {
            "name": "Constant Surveyor",
            "effect_text": "Instead of acting: distribute 16 damage among all enemy units (nearest first; when one is reduced to 0, the rest spills to the next one; Overloaded units only receive exactly enough to hit 0). Any damage left over is dealt to the opponent's HP. If this deals no damage to the opponent's HP, it is Stunned for one turn.",
        },
        "9254": {
            "name": "Precision Calculator",
            "effect_text": "After an opponent's Ally or Structure enters, if its Health is greater than 15, it becomes 15. This resolves after all entry buffs.",
        },
        "9255": {
            "name": "Load Incrementer",
            "effect_text": "At the start of each turn, add one \u300cAttack\u300d and one \u300cWooden Fence\u300d to the opponent's draw pile.",
        },
    },
    "ja": {
        "9253": {
            "name": "定数測量士",
            "effect_text": "行動の代わり：敵ユニットすべてに16ダメージを分配する（近い順。1体を倒したら残りを次へ。オーバーロードのユニットには0になるちょうどの量だけ）。分配後に余ったダメージは相手HPに与える。これで相手HPにダメージを与えられなかった場合、1ターン気絶する。",
        },
        "9254": {
            "name": "精密計算者",
            "effect_text": "相手の味方または構築物が登場した後、その体力が15より大きい場合、15になる。すべての登場時バフの解決後に処理する。",
        },
        "9255": {
            "name": "負荷増量員",
            "effect_text": "ターン開始時、「攻撃」1枚と「木の柵」1枚を相手の山札に加える。",
        },
    },
    "es": {
        "9253": {
            "name": "Top\u00f3grafo Constante",
            "effect_text": "En lugar de actuar: reparte 16 de da\u00f1o entre todas las unidades enemigas (de la m\u00e1s cercana a la m\u00e1s lejana; al derribar una, el resto pasa a la siguiente; las unidades con Sobrecarga solo reciben lo justo para llegar a 0). El da\u00f1o sobrante se aplica a la HP del oponente. Si no se inflige da\u00f1o a la HP del oponente, queda Aturdida durante un turno.",
        },
        "9254": {
            "name": "Calculador de Precisi\u00f3n",
            "effect_text": "Cuando entra un Aliado o Estructura del oponente, si su Salud es mayor que 15, pasa a ser 15. Se resuelve despu\u00e9s de todos los bonificadores de entrada.",
        },
        "9255": {
            "name": "Incrementador de Carga",
            "effect_text": "Al comienzo de cada turno, a\u00f1ade un \u00abAtaque\u00bb y una \u00abValla de Madera\u00bb a la pila de robo del oponente.",
        },
    },
}

# ---------------- ① cards.json（CRLF / 2 空格 / 追加到数组尾部） ----------------
path = ROOT + "cards.json"
raw = io.open(path, "r", encoding="utf-8", newline="").read()
have = {c["id"] for c in json.loads(raw)["cards"]}
_need = [c for c in CARDS if c["id"] not in have]
if not _need:
    print("cards.json 已有三张卡，跳过")

anchor = "\r\n    }\r\n  ]\r\n}\r\n"
assert raw.count(anchor) == 1, "cards.json 尾部锚点不唯一"

add = ""
for c in _need:
    # 顶层（数组元素）缩进 4 空格，内部再按 indent=2 叠加 → 每行统一 +4 空格
    lines = json.dumps(c, ensure_ascii=False, indent=2).split("\n")
    body = "\r\n".join("    " + l for l in lines)
    add += ",\r\n" + body
if _need:
    raw = raw.replace(anchor, add + anchor)
    io.open(path, "w", encoding="utf-8", newline="").write(raw)
    print("cards.json +%d" % len(_need))

# ---------------- ② 三语 cards_*.json ----------------
for lang in ("en", "ja", "es"):
    p = ROOT + "i18n/cards_%s.json" % lang
    s = io.open(p, "r", encoding="utf-8", newline="").read()
    assert "\r\n" not in s, p + " 出现 CRLF"
    if '"9253"' in s:
        print(p, "已有 9253，跳过")
        continue
    tail_anchor = "\n  }\n }\n}\n"
    assert s.count(tail_anchor) == 1, p + " 尾部锚点不唯一"
    add2 = ""
    for cid in ("9253", "9254", "9255"):
        row = I18N[lang][str(cid)]
        add2 += (',\n  "%s": {\n   "name": %s,\n   "effect_text": %s\n  }'
                 % (cid, json.dumps(row["name"], ensure_ascii=False),
                    json.dumps(row["effect_text"], ensure_ascii=False)))
    s = s.replace(tail_anchor, "\n  }" + add2 + "\n }\n}\n")
    # count +3（同步写在头部）
    old_count = json.loads(s)["count"]
    assert old_count == 320, (p, old_count)
    s = s.replace('"count": %d,' % old_count, '"count": %d,' % (old_count + 3), 1)
    data = json.loads(s)
    assert data["count"] == len(data["cards"]) == 323, (p, data["count"], len(data["cards"]))
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print(p, "count ->", data["count"])

# ---------------- ③ zh_canonical ----------------
p = ROOT + "i18n/zh_canonical.json"
s = io.open(p, "r", encoding="utf-8", newline="").read()
assert "\r\n" not in s, p + " 出现 CRLF"
assert '"9253"' not in s, p + " 已有 9253"
ta = "\n  }\n }\n}"
assert s.count(ta) == 1, p + " 尾部锚点不唯一"
add3 = ""
for c in CARDS:
    add3 += (',\n  "%d": {\n   "name": %s,\n   "effect_text": %s,\n   "changed": false\n  }'
             % (c["id"], json.dumps(c["name"], ensure_ascii=False),
                json.dumps(c["effect_text"], ensure_ascii=False)))
s = s.replace(ta, "\n  }" + add3 + "\n }\n}")
s = s.replace('"updated": "2026-11-14"', '"updated": "2026-11-15"', 1)
data = json.loads(s)
assert len(data["cards"]) == 323, len(data["cards"])
# 每张卡的 effect_text 必须与 cards.json 完全一致
for c in CARDS:
    assert data["cards"][str(c["id"])]["effect_text"] == c["effect_text"]
io.open(p, "w", encoding="utf-8", newline="").write(s)
print(p, "cards ->", len(data["cards"]))
print("OK")
