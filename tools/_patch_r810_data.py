# -*- coding: utf-8 -*-
"""R810 数据层：四件新道具（6081~6084）写进 relics.json / 四语 noncard / glossary / 奖励池。"""
import io
import json

ROOT = "E:/work/card_rogue/"

NEW = [
    {"id": 6081, "name": "新月耳饰", "kind": "战斗", "source": "奖励", "tier": "一般",
     "desc": "每 3 场战斗，获得 1 点费用。"},
    {"id": 6082, "name": "太阳指环", "kind": "战斗", "source": "奖励", "tier": "一般",
     "desc": "每个回合，对所有敌方单位造成 3 点伤害。"},
    {"id": 6083, "name": "海妖鱼叉", "kind": "战斗", "source": "奖励", "tier": "一般",
     "desc": "同一回合内，每对一个敌人造成 3 次伤害，对其造成 6 点伤害。"},
    {"id": 6084, "name": "缺陷时钟", "kind": "战斗", "source": "奖励", "tier": "传奇",
     "desc": "在每场战斗中打出第 12 张牌时，结束当前回合并变成你新的回合开始（完全不进行敌方回合）。"},
]

TEXT = {
    "noncard_zh_canonical": {
        6081: ("新月耳饰", "每 3 场战斗，获得 1 点费用。"),
        6082: ("太阳指环", "每个回合，对所有敌方单位造成 3 点伤害。"),
        6083: ("海妖鱼叉", "同一回合内，每对一个敌人造成 3 次伤害，对其造成 6 点伤害。"),
        6084: ("缺陷时钟", "在每场战斗中打出第 12 张牌时，结束当前回合并变成你新的回合开始（完全不进行敌方回合）。"),
    },
    "noncard_en": {
        6081: ("Crescent Earring", "Every 3 battles, gain 1 Energy."),
        6082: ("Sun Ring", "Each turn, deal 3 damage to all enemy units."),
        6083: ("Siren Harpoon", "Within the same turn, every 3rd time you deal damage to an enemy, deal 6 damage to it."),
        6084: ("Defective Clock", "The 12th card you play each battle ends your current turn and immediately begins a new one of yours (the enemy turn never happens)."),
    },
    "noncard_ja": {
        6081: ("三日月のイヤリング", "3 回の戦闘ごとに、コストを 1 得る。"),
        6082: ("太陽の指輪", "毎ターン、敵ユニットすべてに 3 ダメージを与える。"),
        6083: ("セイレーンの銛", "同じターン中、1 体の敵に 3 回ダメージを与えるたび、その敵に 6 ダメージを与える。"),
        6084: ("欠陥時計", "各戦闘で 12 枚目のカードを使った時、現在のターンを終了し、そのまま自分の新しいターンを開始する（敵のターンは行わない）。"),
    },
    "noncard_es": {
        6081: ("Pendiente de luna creciente", "Cada 3 combates, obtienes 1 de Energía."),
        6082: ("Anillo solar", "Cada turno, infliges 3 de daño a todas las unidades enemigas."),
        6083: ("Arpón de sirena", "Dentro del mismo turno, cada 3.ª vez que infliges daño a un enemigo, le infliges 6 de daño."),
        6084: ("Reloj defectuoso", "La 12.ª carta que juegas en cada combate termina tu turno actual y comienza de inmediato un nuevo turno tuyo (el turno enemigo no ocurre)."),
    },
}

GLOSSARY = [
    ("新月耳饰", "Crescent Earring", "三日月のイヤリング", 6081),
    ("太阳指环", "Sun Ring", "太陽の指輪", 6082),
    ("海妖鱼叉", "Siren Harpoon", "セイレーンの銛", 6083),
    ("缺陷时钟", "Defective Clock", "欠陥時計", 6084),
]


def read(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def write(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


# ---- 1. relics.json ----
s = read("relics.json")
anchor = '''      "desc": "每场战斗你第一次使用技能卡时，将那张卡带有「次元」的复制加入手牌。"
    }
  ]
}'''
assert s.count(anchor) == 1, s.count(anchor)
block = [anchor.split("\n  ]")[0] + ","]
for r in NEW:
    block.append('''    {
      "id": %d,
      "name": "%s",
      "kind": "%s",
      "source": "%s",
      "tier": "%s",
      "desc": "%s"
    }''' % (r["id"], r["name"], r["kind"], r["source"], r["tier"], r["desc"]))
joined = "\n".join(block).replace("    }\n    {", "    },\n    {")
write("relics.json", s.replace(anchor, joined + "\n  ]\n}"))
data = json.loads(read("relics.json"))
assert len(data["relics"]) == 79, len(data["relics"])
assert [r["id"] for r in data["relics"]][-4:] == [6081, 6082, 6083, 6084]

# ---- 2. 四语 noncard：6080 是 relics 段最后一条 ----
for fname, rows in TEXT.items():
    s = read("i18n/%s.json" % fname)
    lines = s.split("\n")
    idx = [i for i, ln in enumerate(lines) if ln.strip().startswith('"6080":')]
    assert len(idx) == 1, (fname, idx)
    i0 = idx[0]
    base = lines[i0]
    indent = base[:len(base) - len(base.lstrip())]
    assert base.rstrip().endswith(("},", "}")), base[-20:]
    lines[i0] = base.rstrip().rstrip(",") + ","
    add = []
    for k, rid in enumerate((6081, 6082, 6083, 6084)):
        name, desc = rows[rid]
        tail = "" if k == 3 else ","
        add.append('%s"%d": {"name": %s, "desc": %s}%s'
                   % (indent, rid,
                      json.dumps(name, ensure_ascii=False),
                      json.dumps(desc, ensure_ascii=False), tail))
    write("i18n/%s.json" % fname, "\n".join(lines[:i0 + 1] + add + lines[i0 + 1:]))
    d = json.loads(read("i18n/%s.json" % fname))
    assert len(d["relics"]) == 79, (fname, len(d["relics"]))
    assert d["relics"]["6084"]["name"] == rows[6084][0]

# ---- 3. glossary ----
s = read("i18n/glossary.json")
anchor = '''    "法术卷轴": {
      "en": "Spell Scroll",
      "ja": "スペルスクロール",
      "id": 6080
    }'''
assert s.count(anchor) == 1
add = [anchor]
for name, en, ja, rid in GLOSSARY:
    add.append('''    "%s": {
      "en": "%s",
      "ja": "%s",
      "id": %d
    }''' % (name, en, ja, rid))
write("i18n/glossary.json", s.replace(anchor, ",\n".join(add)))
g = json.loads(read("i18n/glossary.json"))
assert g["relics"]["缺陷时钟"]["id"] == 6084

# ---- 4. 奖励池 ----
s = read("scripts/relic_repo.gd")
old = "\t\t6070, 6071, 6072, 6073, 6074, 6076, 6077, 6078, 6079, 6080]"
new = "\t\t6070, 6071, 6072, 6073, 6074, 6076, 6077, 6078, 6079, 6080,\n\t\t6081, 6082, 6083, 6084]"
assert s.count(old) == 1
write("scripts/relic_repo.gd", s.replace(old, new))
print("DATA OK")
