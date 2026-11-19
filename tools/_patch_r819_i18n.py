# -*- coding: utf-8 -*-
"""R819：占卜代价结果行进 event_ui 四语（模板，含三个 %d）。"""
import io
import json
import re

ROWS = {
    "event_ui_zh_canonical.json": "（占卜的代价：失去 %d 点最大生命 → %d / %d）",
    "event_ui_en.json": "(Divination cost: -%d Max Health -> %d / %d)",
    "event_ui_ja.json": "（占いの代価：最大HPを%d失う → %d / %d）",
    "event_ui_es.json": "(Coste de la adivinación: -%d de Vida máxima -> %d / %d)",
}

for name, text in ROWS.items():
    path = "i18n/" + name
    s = io.open(path, encoding="utf-8", newline="").read()
    if '"DIVINATION_COST_PAID"' in s:
        print("skip(already)", name)
        continue
    m = re.search(r'\n(\s*)"DIVINATION_CARD_GAINED":', s)
    assert m and s.count(m.group(0)) == 1, name
    indent = m.group(1)
    line = '%s"DIVINATION_COST_PAID": %s,' % (
        indent, json.dumps(text, ensure_ascii=False))
    s2 = s.replace(m.group(0), "\n" + line + m.group(0), 1)
    assert s2.count('"DIVINATION_COST_PAID"') == 1, name
    assert s2.count('"DIVINATION_CARD_GAINED"') == 1, name
    io.open(path, "w", encoding="utf-8", newline="").write(s2)
    print("ok", name)

for name in ROWS:
    d = json.loads(io.open("i18n/" + name, encoding="utf-8").read())
    assert d["results"]["divination"]["DIVINATION_COST_PAID"] == ROWS[name], name
print("json ok")
