#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R796 数据层 · 补丁 ②：i18n/traps_* 三语插入（上一版把对象闭合括号切掉了）。"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"

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
    p = ROOT + "i18n/traps_%s.json" % lang
    raw = io.open(p, encoding="utf-8", newline="").read()
    if '"7013"' in raw:
        print("SKIP %s 已有 7013" % lang)
        continue
    k = raw.rfind('"7012"')
    close = raw.find("\n  }", k)          # 7012 对象自己的闭合括号（2 空格缩进）
    assert k > 0 and close > k, p
    end = close + len("\n  }")
    block = raw[k:end] + ","
    add = ""
    for tid in ("7013", "7014"):
        add += ('\n  "%s": {\n   "name": "%s",\n   "desc": "%s"\n  },'
                % (tid, d[tid]["name"], d[tid]["desc"]))
    new = raw[:k] + block + add.rstrip(",") + raw[end:]
    io.open(p, "w", encoding="utf-8", newline="").write(new)
    print("OK  %s (+7013/7014)" % p)

for lang in TRAP_LANG:
    p = ROOT + "i18n/traps_%s.json" % lang
    t = json.load(io.open(p, encoding="utf-8"))["traps"]
    assert "7013" in t and "7014" in t, lang
    print("OK  %s 可解析，工具条目 %d" % (lang, len(t)))
print("DONE")
