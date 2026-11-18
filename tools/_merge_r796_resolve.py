#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 合并：不解析冲突文本，改为「在**新 HEAD** 上重放我的两处数据改动」。

这样 6075（大师之剑，事件专属）原样留在原位，6076 / 6077 接在它后面；
6073 的 desc 用扩面版（新 HEAD 里还是旧文案）。
"""
import io
import json
import re

D = "E:/tmp/r796_merge/"

SPIKE = {
    "en": "Whenever one of your Structures or your Health is attacked, deal 5 damage to the attacker.",
    "ja": "自分の構造物または自分のHPが攻撃されたとき、攻撃者に5ダメージを与える。",
    "es": "Cuando una de tus Estructuras o tu Salud es atacada, inflige 5 de daño al atacante.",
    "zh_canonical": "你的工事或你的生命被攻击时，对攻击者造成 5 点伤害。",
}
OLD_SPIKE = {
    "en": '"desc": "Whenever one of your Structures is attacked, deal 5 damage to the attacker."',
    "ja": '"desc": "自分の構造物が攻撃されたとき、攻撃者に5ダメージを与える。"',
    "es": '"desc": "Cuando una de tus Estructuras es atacada, inflige 5 de daño al atacante."',
    "zh_canonical": '"desc": "你的工事被攻击时，对攻击者造成 5 点伤害。"',
}
NEW = {
    "en": {"6076": ("Rabbit's Foot", "Battle victories grant 10 extra gold, and the chance "
                                     "for a tool to drop after battle is +10% (additive)."),
           "6077": ("Drill", "When you play a card whose cost is X, if X is 6 or more, "
                             "X is doubled.")},
    "ja": {"6076": ("ウサギの足", "戦闘勝利時に追加で10ゴールドを得る。戦闘後にツールがドロップする確率が+10%（加算）。"),
           "6077": ("ドリル", "コストがXのカードを使うとき、Xが6以上ならXは2倍になる。")},
    "es": {"6076": ("Pata de conejo", "Ganas 10 de oro extra al vencer en combate y la probabilidad "
                                      "de que caiga una herramienta tras el combate aumenta un 10% (aditivo)."),
           "6077": ("Taladro", "Cuando usas una carta cuyo coste es X, si X es 6 o más, X se duplica.")},
    "zh_canonical": {"6076": ("兔脚", "战斗胜利时额外获得 10 金币；战斗掉落工具的概率 +10%（相加）。"),
                     "6077": ("钻头", "你使用费用为 X 的卡时，若 X 为 6 或以上，X 翻倍。")},
}


def load(p):
    return io.open(p, encoding="utf-8", newline="").read()


def save(p, s):
    io.open(p, "w", encoding="utf-8", newline="").write(s)


# ── ① relics.json：在新 HEAD 上重放 ──────────────────────────────
s = load(D + "head_relics.json")
assert s.count(OLD_SPIKE["zh_canonical"]) == 1
s = s.replace(OLD_SPIKE["zh_canonical"], '"desc": "%s"' % SPIKE["zh_canonical"])
tail_old = '''      "desc": "每场战斗使用的第一个盟友 +10 力量（不叠加）。"
    }
  ]
}'''
assert s.count(tail_old) == 1, s.count(tail_old)
add = ""
for rid in ("6076", "6077"):
    name, desc = NEW["zh_canonical"][rid]
    add += (',\n    {\n      "id": %s,\n      "name": "%s",\n      "kind": "战斗",\n'
            '      "source": "奖励",\n      "tier": "一般",\n      "desc": "%s"\n    }'
            % (rid, name, desc))
s = s.replace(tail_old, '''      "desc": "每场战斗使用的第一个盟友 +10 力量（不叠加）。"
    }''' + add + '''
  ]
}''')
save(D + "m_relics.json", s)
doc = json.load(io.open(D + "m_relics.json", encoding="utf-8"))
ids = [int(x["id"]) for x in doc["relics"]]
assert ids.count(6075) == 1 and 6076 in ids and 6077 in ids, ids[-5:]
assert "生命" in [x["desc"] for x in doc["relics"] if int(x["id"]) == 6073][0]
print("OK relics.json：%d 件（末尾 %s）" % (len(doc["relics"]), ids[-4:]))

# ── ② i18n/noncard_*：同样在新 HEAD 上重放 ──────────────────────
ANCHOR = '\n  "classes": {'
for lang in ("en", "ja", "es", "zh_canonical"):
    s = load(D + "head_noncard_%s.json" % lang)
    assert s.count(OLD_SPIKE[lang]) == 1, (lang, s.count(OLD_SPIKE[lang]))
    s = s.replace(OLD_SPIKE[lang], '"desc": "%s"' % SPIKE[lang])
    k = s.find(ANCHOR)
    assert k > 0, lang
    head = s[:k]
    cut = head.rfind("\n") + 1
    last = head[cut:]
    assert '"6075"' in last, (lang, last[-80:])
    clean = last.strip()
    # 这一行把「6075 条目」和「relics 对象闭合」挤在一起：`...}  },` → 只留条目的 `},`
    clean = re.sub(r"\}\s*\},$", "},", clean)
    assert clean.endswith("},"), (lang, clean[-40:])
    add = ""
    for rid in ("6076", "6077"):
        name, desc = NEW[lang][rid]
        add += '\n    "%s": {"name": "%s", "desc": "%s"},' % (rid, name, desc)
    add = add.rstrip(",")
    s = head[:cut] + "    " + clean + add + "\n  }," + s[k:]
    save(D + "m_noncard_%s.json" % lang, s)
    doc = json.load(io.open(D + "m_noncard_%s.json" % lang, encoding="utf-8"))
    r = doc["relics"]
    assert "6075" in r and "6076" in r and "6077" in r, lang
    base_n = len(json.load(io.open(D + "head_noncard_%s.json" % lang,
                                   encoding="utf-8"))["relics"])
    assert len(r) == base_n + 2, (lang, len(r), base_n)
    print("OK noncard_%s（%d 条，classes %d）" % (lang, len(r), len(doc["classes"])))

print("DONE")
