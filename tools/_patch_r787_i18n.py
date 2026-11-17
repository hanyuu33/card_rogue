# -*- coding: utf-8 -*-
"""R787：附魔「伤害 +8」的四语文案 + 术语表。

⚠️ 附魔名走 `CardData.enchant_name()` → `GameI18n.source(中文label)`，
   而 source 是**按中文整串**去 glossary 查的 —— 中文 label 改成「伤害 +8」
   之后，glossary 的 key 也必须跟着改，否则英文/日文版会直接显示中文。
"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"


def load(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def save(rel, s):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        print("FAIL [%s] 命中 %d 次：%r" % (tag, n, old[:70]))
        sys.exit(1)
    return s.replace(old, new, 1)


# ── 三语 interface（LF）──
CASES = [
    ("i18n/interface_en.json",
     [('"SHOP_ENCHANT_DAMAGE_NAME": "Damage +10",',
       '"SHOP_ENCHANT_DAMAGE_NAME": "Damage +8",'),
      ('"SHOP_ENCHANT_DAMAGE_DESC": "Damage dealt by this Skill card +10 (only Skill cards',
       '"SHOP_ENCHANT_DAMAGE_DESC": "Damage dealt by this Skill card +8 (only Skill cards')]),
    ("i18n/interface_ja.json",
     [('"SHOP_ENCHANT_DAMAGE_NAME": "ダメージ+10",',
       '"SHOP_ENCHANT_DAMAGE_NAME": "ダメージ+8",'),
      ('このスキルカードが与えるダメージ+10（',
       'このスキルカードが与えるダメージ+8（')]),
    ("i18n/interface_es.json",
     [('"SHOP_ENCHANT_DAMAGE_NAME": "Daño +10",',
       '"SHOP_ENCHANT_DAMAGE_NAME": "Daño +8",'),
      ('Esta carta de Habilidad inflige +10 de daño',
       'Esta carta de Habilidad inflige +8 de daño')]),
]
for rel, pairs in CASES:
    s = load(rel)
    for i, (o, n) in enumerate(pairs):
        s = rep(s, o, n, "%s-%d" % (rel, i))
    json.loads(s)  # 写完还要能解析
    save(rel, s)
    print("OK", rel)

# ── 中文规范（LF，带 source 行号）──
P = "i18n/interface_zh_canonical.json"
s = load(P)
s = rep(s,
        '      "SHOP_ENCHANT_DAMAGE_NAME": {\n'
        '        "source": "scripts/card_data.gd:114",\n'
        '        "zh": "伤害 +10"\n'
        '      },',
        '      "SHOP_ENCHANT_DAMAGE_NAME": {\n'
        '        "source": "scripts/card_data.gd:132",\n'
        '        "zh": "伤害 +8"\n'
        '      },', "zh-name")
s = rep(s,
        '      "SHOP_ENCHANT_DAMAGE_DESC": {\n'
        '        "source": "scripts/shop_scene.gd:71",\n'
        '        "zh": "这张技能卡造成的伤害 +10（只能选能直接造成伤害的技能卡）"\n'
        '      },',
        '      "SHOP_ENCHANT_DAMAGE_DESC": {\n'
        '        "source": "scripts/shop_scene.gd:74",\n'
        '        "zh": "这张技能卡造成的伤害 +8（只能选能直接造成伤害的技能卡）"\n'
        '      },', "zh-desc")
json.loads(s)
save(P, s)
print("OK", P)

# ── 术语表（LF）：key 是中文真源，必须与 label 逐字一致 ──
P = "i18n/glossary.json"
s = load(P)
s = rep(s,
        '    "伤害 +10": {\n'
        '      "en": "Damage +10",\n'
        '      "ja": "ダメージ+10"\n'
        '    },',
        '    "伤害 +8": {\n'
        '      "en": "Damage +8",\n'
        '      "ja": "ダメージ+8"\n'
        '    },', "glossary")
json.loads(s)
save(P, s)
print("OK", P)

# ── 收尾：全仓 i18n 不许再有 +10 的附魔残留 ──
import glob
bad = []
for f in glob.glob(ROOT + "i18n/*.json"):
    t = io.open(f, encoding="utf-8").read()
    for needle in ["伤害 +10", "Damage +10", "ダメージ+10", "Daño +10", "+10 de daño"]:
        if needle in t:
            bad.append((f.split("/")[-1], needle))
print("残留:", bad if bad else "无")
