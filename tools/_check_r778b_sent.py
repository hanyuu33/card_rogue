# -*- coding: utf-8 -*-
"""R778b：精确核对 14 张敌人效果卡的四语文本是否已删掉「多张不叠加」那句。"""
import io
import json

REPO = "E:/work/card_rogue/"
IDS = ["9013", "9015", "9024", "9049", "9115", "9117", "9125",
       "9139", "9147", "9178", "9209", "9210", "9212", "9240"]
PAT = {
    "zh_canonical": ["效果区多张", "不可叠加"],
    "cards_en": ["Multiple copies", "do not stack", "does not stack"],
    "cards_ja": ["複数あっても", "重複しない"],
    "cards_es": ["Varias copias", "acumulan"],
}

for f, pats in PAT.items():
    d = json.load(io.open(REPO + "i18n/" + f + ".json", encoding="utf-8"))
    pool = d.get("cards", d)
    print("==", f)
    for i in IDS:
        v = pool.get(i)
        if v is None:
            print("   ", i, "MISSING")
            continue
        t = (v.get("effect_text") or "") if isinstance(v, dict) else str(v)
        bad = [p for p in pats if p in t]
        flag = "  <<< 残留 %s" % bad if bad else ""
        print("   ", i, (v.get("name") if isinstance(v, dict) else ""), "|", t[-46:], flag)
