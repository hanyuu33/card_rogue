# -*- coding: utf-8 -*-
"""R781：叙事底本 + 三语新增 `REST_WARM_NOTE`（「温暖」修饰下火堆描述末句）。

`GameI18n.source()` 是**按中文全串**查表的，所以只要这个短句在四份 narrative 里都有，
温暖版描述的最后一行就能翻出来；前面几行沿用 R767 之前的既有译文。
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

TEXTS = {
    "narrative_zh_canonical.json": "（三样里可以挑两样——今天的火堆格外暖。）",
    "narrative_en.json": "(Pick two of the three — today's fire burns warmer.)",
    "narrative_ja.json": "（3つのうち2つ選べる——今日の焚き火はひときわ暖かい。）",
    "narrative_es.json": "(Elige dos de las tres: hoy la hoguera arde más cálida.)",
}

for fn, text in TEXTS.items():
    path = os.path.join("i18n", fn)
    raw = open(path, encoding="utf-8").read()
    d = json.loads(raw)
    ev = d.get("events", d)
    if "rest" not in ev:
        sys.exit("[R781] %s 缺 rest 节点" % fn)
    texts = ev["rest"]["texts"]
    if "REST_WARM_NOTE" in texts and texts["REST_WARM_NOTE"] == text:
        print("  %s 已是最新，跳过" % fn)
        continue
    texts["REST_WARM_NOTE"] = text
    out = json.dumps(d, ensure_ascii=False, indent=2)
    if not out.endswith("\n"):
        out += "\n"
    open(path, "w", encoding="utf-8", newline="\n").write(out)
    print("  %s +REST_WARM_NOTE" % fn)

for fn in TEXTS:
    d = json.loads(open(os.path.join("i18n", fn), encoding="utf-8").read())
    ev = d.get("events", d)
    assert "REST_WARM_NOTE" in ev["rest"]["texts"], fn
print("四语 REST_WARM_NOTE 就位")
