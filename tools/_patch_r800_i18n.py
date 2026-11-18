#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R800：四语加 9274 余音 / 9275 音符。

只按原缩进（条目 2 空格、字段 3 空格）在末尾插两条，不整篇 json.dumps。
"""
import json

ENTRIES = {
    "zh_canonical": '''  "9274": {
   "name": "余音",
   "effect_text": "X 费，打出时消耗全部费用。将 X 张「音符」加入抽牌库。没有费用时也能使用（此时 X 为 0）。",
   "changed": false
  },
  "9275": {
   "name": "音符",
   "effect_text": "获得 2 点费用，抽 2 张卡。",
   "changed": false
  }''',
    "cards_en": '''  "9274": {
   "name": "Lingering Note",
   "effect_text": "Costs X; playing it consumes all of your Cost. Add X copies of Note to your Draw Pile. Can be used even with no Cost (X is 0 in that case)."
  },
  "9275": {
   "name": "Note",
   "effect_text": "Gain 2 Cost and draw 2 cards."
  }''',
    "cards_ja": '''  "9274": {
   "name": "余韻",
   "effect_text": "コストX。使用時に全コストを消費する。「音符」をX枚山札に加える。コストがなくても使用できる（その場合Xは0）。"
  },
  "9275": {
   "name": "音符",
   "effect_text": "コストを2獲得し、カードを2枚引く。"
  }''',
    "cards_es": '''  "9274": {
   "name": "Resonancia",
   "effect_text": "Cuesta X; al jugarlo consume todo el Coste. Añade X copias de Nota a la pila de robo. Puede usarse incluso sin Coste (en ese caso, X es 0)."
  },
  "9275": {
   "name": "Nota",
   "effect_text": "Obtienes 2 de Coste y robas 2 cartas."
  }''',
}

# 锚点分两段用：LAST_BRACE 是「最后一条的闭合」要去掉，TAIL 是真正的文件尾巴。
LAST_BRACE = "\n  }\n }\n}"
TAIL = "\n }\n}"

for name, block in ENTRIES.items():
    p = "i18n/%s.json" % name
    d = open(p, "rb").read().decode("utf-8")
    assert d.count(LAST_BRACE) == 1, "%s anchor count=%d" % (name, d.count(LAST_BRACE))
    assert d.count(TAIL) == 1, "%s tail count=%d" % (name, d.count(TAIL))
    # 原最后一条的 `  }` 变成 `  },`，随后接两个新条目，再接真正的文件尾巴。
    out = d.replace(LAST_BRACE, "\n  },\n" + block + TAIL)
    open(p, "wb").write(out.encode("utf-8"))

    # 校验：可解析、两条都在、行尾仍是纯 LF、条目数 +2
    chk = json.load(open(p, encoding="utf-8"))["cards"]
    assert "9274" in chk and "9275" in chk, name
    assert chk["9275"]["name"], name
    b = open(p, "rb").read()
    assert b.count(b"\r\n") == 0, "%s 出现 CRLF" % name
    print("%-16s ok  len=%d  9274=%s 9275=%s" % (name, len(chk), chk["9274"]["name"], chk["9275"]["name"]))
