# -*- coding: utf-8 -*-
## R801：爆炸蘑菇 7016 —— i18n/traps_{en,ja,es}.json
import json
import os

os.chdir("E:/work/card_rogue")

NEW = {
    "en": ("Explosive Mushroom",
           "Drag it onto an empty battlefield cell. An enemy that steps on it sets it off, "
           "dealing 15 damage to every unit within one cell, friend or foe; the tool is then used up."),
    "ja": ("爆発キノコ",
           "戦場の空きマスにドラッグして設置する。踏んだ敵がいると爆発し、"
           "1 マス以内のすべてのユニット（敵味方問わず）に 15 ダメージを与える。使用後は消費される。"),
    "es": ("Seta explosiva",
           "Arrástrala a una casilla vacía del campo. El enemigo que la pise hace que explote "
           "y causa 15 de daño a todas las unidades a una casilla o menos (aliadas o enemigas); "
           "después, la herramienta se consume."),
}

for lang, (name, desc) in NEW.items():
    p = "i18n/traps_%s.json" % lang
    raw = open(p, "rb").read().decode("utf-8")
    assert raw.count("\r\n") == 0, "%s 应是纯 LF" % p
    doc = json.loads(raw)
    old_row = doc["traps"]["7015"]
    old = ('  "7015": {\n   "name": %s,\n   "desc": %s\n  }'
           % (json.dumps(old_row["name"], ensure_ascii=False),
              json.dumps(old_row["desc"], ensure_ascii=False)))
    new = old + (',\n  "7016": {\n   "name": %s,\n   "desc": %s\n  }'
                 % (json.dumps(name, ensure_ascii=False),
                    json.dumps(desc, ensure_ascii=False)))
    assert raw.count(old) == 1, "%s 锚点 %d" % (p, raw.count(old))
    raw = raw.replace(old, new)
    open(p, "wb").write(raw.encode("utf-8"))
    chk = json.loads(open(p, "rb").read().decode("utf-8"))["traps"]
    assert len(chk) == 16 and "7016" in chk
    print("%-22s ok  n=%d  7016=%s" % (p, len(chk), chk["7016"]["name"]))

for lang in ("en", "ja", "es"):
    b = open("i18n/traps_%s.json" % lang, "rb").read()
    print("  %s CRLF %d LFonly %d" % (lang, b.count(b"\r\n"),
                                      b.count(b"\n") - b.count(b"\r\n")))
