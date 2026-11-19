# -*- coding: utf-8 -*-
"""R824：鸭子闹钟 6085 的四语文案 + 术语表 + 校验器条数。

幂等：已经写过 6085 的文件直接跳过（zh / en 上一跑已落盘）。
"""
import io
import json

ROOT = "E:/work/card_rogue/"

ZH_NAME = "鸭子闹钟"
ZH_DESC = "每场战斗的第 2 回合，抽 1 张卡并获得 1 点费用；第 5 回合起，技能伤害 +1。"

# 文件 -> (锚点行 = 6084 那一整行, 新行内容)
ROWS = {
    "i18n/noncard_zh_canonical.json": (
        '"6084": {"name": "缺陷时钟", "desc": "在每场战斗中打出第 12 张牌时，结束当前回合并变成你新的回合开始（完全不进行敌方回合）。"}',
        {"name": ZH_NAME, "desc": ZH_DESC}),
    "i18n/noncard_en.json": (
        '"6084": {"name": "Defective Clock", "desc": "The 12th card you play each battle ends your current turn and immediately begins a new one of yours (the enemy turn never happens)."}',
        {"name": "Duck Alarm Clock",
         "desc": "On the 2nd turn of every battle, draw 1 card and gain 1 Energy. From the 5th turn onward, skill damage +1."}),
    "i18n/noncard_ja.json": (
        '"6084": {"name": "欠陥時計", "desc": "各戦闘で 12 枚目のカードを使った時、現在のターンを終了し、そのまま自分の新しいターンを開始する（敵のターンは行わない）。"}',
        {"name": "アヒルの目覚まし時計",
         "desc": "毎戦闘の 2 ターン目にカードを 1 枚引き、コストを 1 得る。5 ターン目以降、スキルのダメージ +1。"}),
    "i18n/noncard_es.json": (
        '"6084": {"name": "Reloj defectuoso", "desc": "La 12.ª carta que juegas en cada combate termina tu turno actual y comienza de inmediato un nuevo turno tuyo (el turno enemigo no ocurre)."}',
        {"name": "Despertador de pato",
         "desc": "En el 2.º turno de cada combate, roba 1 carta y obtén 1 de Coste. A partir del 5.º turno, el daño de habilidad +1."}),
}

for rel, (anchor, row) in ROWS.items():
    raw = io.open(ROOT + rel, encoding="utf-8", newline="").read()
    assert raw.count("\r\n") == 0, rel + " 不是 LF"
    if '"6085"' in raw:
        print("SKIP", rel, "（已有 6085）")
        continue
    assert raw.count(anchor) == 1, "%s 锚点命中 %d" % (rel, raw.count(anchor))
    line = '"6085": ' + json.dumps(row, ensure_ascii=False)
    raw = raw.replace(anchor, anchor + ",\n    " + line)
    data = json.loads(raw)
    assert data["relics"]["6085"]["name"] == row["name"]
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(raw)
    print("OK", rel, len(raw))

# ── 术语表（validate_noncard 要求道具名走 glossary.relics[中文名][en/ja]）──
rel = "i18n/glossary.json"
t = io.open(ROOT + rel, encoding="utf-8", newline="").read()
assert t.count("\r\n") == 0
if '"鸭子闹钟"' in t:
    print("SKIP glossary.json（已有）")
else:
    anchor = '"缺陷时钟": {"en": "Defective Clock", "ja": "欠陥時計", "id": 6084}'
    assert t.count(anchor) == 1, "glossary 锚点 %d" % t.count(anchor)
    t = t.replace(anchor, anchor + ',\n    "鸭子闹钟": {"en": "Duck Alarm Clock", "ja": "アヒルの目覚まし時計", "id": 6085}')
    json.loads(t)
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(t)
    print("OK glossary.json", len(t))

# ── 校验器写死的条数 79 → 80 ──
rel = "i18n/validate_spanish.py"
t = io.open(ROOT + rel, encoding="utf-8", newline="").read()
if 'NONCARD_ES["relics"]) == 80' in t:
    print("SKIP validate_spanish.py（已是 80）")
else:
    old = 'check(len(NONCARD_ES["relics"]) == 79 and len(NONCARD_ES["classes"]) == 3,\n      "noncard 为 79 件道具 + 3 个角色'
    assert t.count(old) == 1
    t = t.replace(old, 'check(len(NONCARD_ES["relics"]) == 80 and len(NONCARD_ES["classes"]) == 3,\n      "noncard 为 80 件道具 + 3 个角色')
    old2 = "海妖鱼叉 6083 / 缺陷时钟 6084）"
    assert t.count(old2) == 1
    t = t.replace(old2, "海妖鱼叉 6083 / 缺陷时钟 6084 / R824 +鸭子闹钟 6085）")
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(t)
    print("OK validate_spanish.py", len(t))
