#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 数据层 · 修正版：i18n/noncard_* 四语（上一版插入时把 anchor 之后的整段丢了）。

正确写法：head + "," + 新条目 + s[k:]（anchor 与它后面的一切原样保留）。
"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"

LANG = {
    "en": {
        "spike": "Whenever one of your Structures or your Health is attacked, "
                 "deal 5 damage to the attacker.",
        "old_spike": '"desc": "Whenever one of your Structures is attacked, deal 5 damage to the attacker."',
        "6076": {"name": "Rabbit's Foot",
                 "desc": "Battle victories grant 10 extra gold, and the chance "
                         "for a tool to drop after battle is +10% (additive)."},
        "6077": {"name": "Drill",
                 "desc": "When you play a card whose cost is X, if X is 6 or "
                         "more, X is doubled."},
    },
    "ja": {
        "spike": "自分の構造物または自分のHPが攻撃されたとき、攻撃者に5ダメージを与える。",
        "old_spike": '"desc": "自分の構造物が攻撃されたとき、攻撃者に5ダメージを与える。"',
        "6076": {"name": "ウサギの足",
                 "desc": "戦闘勝利時に追加で10ゴールドを得る。戦闘後にツールがドロップする確率が+10%（加算）。"},
        "6077": {"name": "ドリル",
                 "desc": "コストがXのカードを使うとき、Xが6以上ならXは2倍になる。"},
    },
    "es": {
        "spike": "Cuando una de tus Estructuras o tu Salud es atacada, inflige 5 de daño al atacante.",
        "old_spike": '"desc": "Cuando una de tus Estructuras es atacada, inflige 5 de daño al atacante."',
        "6076": {"name": "Pata de conejo",
                 "desc": "Ganas 10 de oro extra al vencer en combate y la probabilidad de que "
                         "caiga una herramienta tras el combate aumenta un 10% (aditivo)."},
        "6077": {"name": "Taladro",
                 "desc": "Cuando usas una carta cuyo coste es X, si X es 6 o más, X se duplica."},
    },
    "zh_canonical": {
        "spike": "你的工事或你的生命被攻击时，对攻击者造成 5 点伤害。",
        "old_spike": '"desc": "你的工事被攻击时，对攻击者造成 5 点伤害。"',
        "6076": {"name": "兔脚",
                 "desc": "战斗胜利时额外获得 10 金币；战斗掉落工具的概率 +10%（相加）。"},
        "6077": {"name": "钻头",
                 "desc": "你使用费用为 X 的卡时，若 X 为 6 或以上，X 翻倍。"},
    },
}

ANCHOR = '\n  },\n  "classes": {'

for lang, d in LANG.items():
    p = ROOT + "i18n/noncard_%s.json" % lang
    s = io.open(p, encoding="utf-8", newline="").read()
    assert '"6076"' not in s, p

    # ① 刺墙 desc：只换 desc 那一小段，行内其余部分（name）原样保留
    assert s.count(d["old_spike"]) == 1, (p, s.count(d["old_spike"]))
    s = s.replace(d["old_spike"], '"desc": "%s"' % d["spike"])

    # ② 两件新道具：插在 relics 对象闭合之前，**anchor 与它后面的一切原样保留**
    k = s.find(ANCHOR)
    assert k > 0, p
    head = s[:k].rstrip()
    assert head.endswith("}"), p
    add = ('\n    "6076": {"name": "%s", "desc": "%s"},'
           '\n    "6077": {"name": "%s", "desc": "%s"}'
           % (d["6076"]["name"], d["6076"]["desc"],
              d["6077"]["name"], d["6077"]["desc"]))
    s = head + "," + add + s[k:]
    io.open(p, "w", encoding="utf-8", newline="").write(s)
    print("OK  %s" % p)

# ③ 全量校验：结构完整（classes / implementation_notes 都还在），四语条目齐
for lang in LANG:
    p = ROOT + "i18n/noncard_%s.json" % lang
    doc = json.load(io.open(p, encoding="utf-8"))
    assert len(doc["relics"]) == 71, (lang, len(doc["relics"]))
    assert len(doc["classes"]) == 3, lang
    assert "6076" in doc["relics"] and "6077" in doc["relics"], lang
    assert "生命" in doc["relics"]["6073"]["desc"] or lang != "zh_canonical"
    print("OK  %s 结构完整：relics %d / classes %d%s"
          % (lang, len(doc["relics"]), len(doc["classes"]),
             " / notes %d" % len(doc["implementation_notes"])
             if "implementation_notes" in doc else ""))
print("DONE")
