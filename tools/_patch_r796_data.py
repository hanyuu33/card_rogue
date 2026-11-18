#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 数据层：兔脚 6076 / 钻头 6077 + 卡牌包 7013 / 智慧药剂 7014 + 刺墙扩面文案。
全部 exact-replace + assert count==1。"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"


def rd(p):
    return io.open(ROOT + p, encoding="utf-8", newline="").read()


def wr(p, s):
    io.open(ROOT + p, "w", encoding="utf-8", newline="").write(s)


def rep(p, old, new, note=""):
    s = rd(p)
    n = s.count(old)
    if n != 1:
        print("FAIL %s 锚点命中 %d 次 %s" % (p, n, note))
        sys.exit(1)
    wr(p, s.replace(old, new))
    print("OK  %s %s" % (p, note))


# ── ① relics.json：两件新道具 + 刺墙文案 ──────────────────────────────
rel_old = '''    {
      "id": 6074,
      "name": "应急装甲",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "每回合最多受到 20 点伤害。"
    }
  ]
}'''
rel_new = '''    {
      "id": 6074,
      "name": "应急装甲",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "每回合最多受到 20 点伤害。"
    },
    {
      "id": 6076,
      "name": "兔脚",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "战斗胜利时额外获得 10 金币；战斗掉落工具的概率 +10%（相加）。"
    },
    {
      "id": 6077,
      "name": "钻头",
      "kind": "战斗",
      "source": "奖励",
      "tier": "一般",
      "desc": "你使用费用为 X 的卡时，若 X 为 6 或以上，X 翻倍。"
    }
  ]
}'''
rep("relics.json", rel_old, rel_new, "(+6076/6077)")

rep("relics.json",
    '"desc": "你的工事被攻击时，对攻击者造成 5 点伤害。"',
    '"desc": "你的工事或你的生命被攻击时，对攻击者造成 5 点伤害。"',
    "(刺墙 desc)")

# ── ② i18n/noncard_*：四语 ────────────────────────────────────────
LANG = {
    "en": {
        "spike": "Whenever one of your Structures or your Health is attacked, "
                 "deal 5 damage to the attacker.",
        "6076": {"name": "Rabbit's Foot",
                 "desc": "Battle victories grant 10 extra gold, and the chance "
                         "for a tool to drop after battle is +10% (additive)."},
        "6077": {"name": "Drill",
                 "desc": "When you play a card whose cost is X, if X is 6 or "
                         "more, X is doubled."},
    },
    "ja": {
        "spike": "自分の構造物または自分のHPが攻撃されたとき、攻撃者に5ダメージを与える。",
        "6076": {"name": "ウサギの足",
                 "desc": "戦闘勝利時に追加で10ゴールドを得る。戦闘後にツールがドロップする確率が+10%（加算）。"},
        "6077": {"name": "ドリル",
                 "desc": "コストがXのカードを使うとき、Xが6以上ならXは2倍になる。"},
    },
    "es": {
        "spike": "Cuando una de tus Estructuras o tu Salud es atacada, inflige 5 de daño al atacante.",
        "6076": {"name": "Pata de conejo",
                 "desc": "Ganas 10 de oro extra al vencer en combate y la probabilidad de que "
                         "caiga una herramienta tras el combate aumenta un 10% (aditivo)."},
        "6077": {"name": "Taladro",
                 "desc": "Cuando usas una carta cuyo coste es X, si X es 6 o más, X se duplica."},
    },
    "zh_canonical": {
        "spike": "你的工事或你的生命被攻击时，对攻击者造成 5 点伤害。",
        "6076": {"name": "兔脚",
                 "desc": "战斗胜利时额外获得 10 金币；战斗掉落工具的概率 +10%（相加）。"},
        "6077": {"name": "钻头",
                 "desc": "你使用费用为 X 的卡时，若 X 为 6 或以上，X 翻倍。"},
    },
}

for lang, d in LANG.items():
    p = "i18n/noncard_%s.json" % lang
    # 刺墙 desc 只在键内改，不碰 name（四语 name 各自不同）
    s = rd(p)
    i = s.find('"6073"')
    assert i > 0, p
    j = s.find('\n', i)
    line = s[i:j]
    old_line = line
    for frag in ('"desc": "你的工事被攻击时，对攻击者造成 5 点伤害。"',
                 '"desc": "Whenever one of your Structures is attacked, deal 5 damage to the attacker."',
                 '"desc": "自分の構造物が攻撃されたとき、攻撃者に5ダメージを与える。"',
                 '"desc": "Cuando una de tus Estructuras es atacada, inflige 5 de daño al atacante."'):
        if frag in line:
            head = frag.split('"desc": "')[0]
            line = head + '"desc": "%s"}' % d["spike"]
            break
    if line == old_line:
        print("FAIL %s 找不到 6073 旧 desc" % p)
        sys.exit(1)
    s = s[:i] + line + s[j:]
    wr(p, s)
    print("OK  %s (6073 desc)" % p)

    # 两件新道具：插在 relics 对象结束前（"classes" 之前），单行格式与邻项一致
    anchor = '\n  },\n  "classes": {'
    add = ""
    for rid in ("6076", "6077"):
        add += '\n    "%s": {"name": "%s", "desc": "%s"},' % (
            rid, d[rid]["name"], d[rid]["desc"])
    # 上一条（6074）行尾是 `}` 无逗号 → 需要补
    s = rd(p)
    k = s.find(anchor)
    assert k > 0, p
    prev = s[:k]
    assert prev.rstrip().endswith('}'), p
    prev = prev.rstrip() + ","
    new = prev + add.rstrip(",") + anchor
    wr(p, new)
    print("OK  %s (+6076/6077)" % p)

# ── ③ traps.json：两件新工具 ──────────────────────────────────────
tr_old = '''    { "id": 7012, "name": "石头", "direct_damage": 15, "no_drop": true,
      "desc": "拖到敌方单位身上。对它造成 15 点伤害，用掉后从工具栏移除。", "icon": "tool_stone" }
  ]
}'''
tr_new = '''    { "id": 7012, "name": "石头", "direct_damage": 15, "no_drop": true,
      "desc": "拖到敌方单位身上。对它造成 15 点伤害，用掉后从工具栏移除。", "icon": "tool_stone" },
    { "id": 7013, "name": "卡牌包", "price": 55, "fill_hand": true,
      "desc": "轻点两下即可使用，无需拖到战场格子上。用随机卡牌填满你的手牌，用掉后从工具栏移除。", "icon": "tool_cardpack" },
    { "id": 7014, "name": "智慧药剂", "price": 40, "draw_cards": 3,
      "desc": "轻点两下即可使用，无需拖到战场格子上。立即抽 3 张卡，用掉后从工具栏移除。", "icon": "tool_potion_wisdom" }
  ]
}'''
rep("traps.json", tr_old, tr_new, "(+7013/7014)")

# ── ④ i18n/traps_*：三语 ─────────────────────────────────────────
TRAP_LANG = {
    "en": {
        "7013": {"name": "Card Pack",
                 "desc": "Tap it twice to use it, no dragging needed. Fills your hand "
                         "with random cards; the tool is then used up."},
        "7014": {"name": "Potion of Wisdom",
                 "desc": "Tap it twice to use it, no dragging needed. Draws 3 cards; "
                         "the tool is then used up."},
    },
    "ja": {
        "7013": {"name": "カードパック",
                 "desc": "2回タップすると使用できる（ドラッグ不要）。ランダムなカードで手札をいっぱいにする。使用後は消費される。"},
        "7014": {"name": "知恵のポーション",
                 "desc": "2回タップすると使用できる（ドラッグ不要）。カードを3枚引く。使用後は消費される。"},
    },
    "es": {
        "7013": {"name": "Paquete de cartas",
                 "desc": "Tócala dos veces para usarla, sin arrastrarla. Llena tu mano con "
                         "cartas aleatorias; después, la herramienta se consume."},
        "7014": {"name": "Poción de sabiduría",
                 "desc": "Tócala dos veces para usarla, sin arrastrarla. Roba 3 cartas; "
                         "después, la herramienta se consume."},
    },
}

for lang, d in TRAP_LANG.items():
    p = "i18n/traps_%s.json" % lang
    raw = rd(p)
    k = raw.rfind('"7012"')
    assert k > 0, p
    end = raw.find("\n  }", k)
    assert end > 0, p
    assert raw[k:end].rstrip().endswith("}"), p
    block = raw[k:end].rstrip() + ","
    add = ""
    for tid in ("7013", "7014"):
        add += ('\n  "%s": {\n   "name": "%s",\n   "desc": "%s"\n  },'
                % (tid, d[tid]["name"], d[tid]["desc"]))
    new = raw[:k] + block + add.rstrip(",") + raw[end:]
    wr(p, new)
    print("OK  %s (+7013/7014)" % p)

# ── ⑤ 校验 JSON 全部可解析 ───────────────────────────────────────
for p in ["relics.json", "traps.json"] + ["i18n/noncard_%s.json" % l for l in LANG] \
        + ["i18n/traps_%s.json" % l for l in TRAP_LANG]:
    json.load(io.open(ROOT + p, encoding="utf-8"))
print("OK  JSON 全部可解析")

relics = json.load(io.open(ROOT + "relics.json", encoding="utf-8"))["relics"]
traps = json.load(io.open(ROOT + "traps.json", encoding="utf-8"))["traps"]
for lang in ("zh_canonical", "en", "ja", "es"):
    r = json.load(io.open(ROOT + "i18n/noncard_%s.json" % lang, encoding="utf-8"))["relics"]
    assert "6076" in r and "6077" in r, lang
for lang in ("en", "ja", "es"):
    t = json.load(io.open(ROOT + "i18n/traps_%s.json" % lang, encoding="utf-8"))["traps"]
    assert "7013" in t and "7014" in t, lang
print("道具 %d 件 / 工具 %d 件" % (len(relics), len(traps)))
print("DONE")
