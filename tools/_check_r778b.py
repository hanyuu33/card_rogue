# -*- coding: utf-8 -*-
"""R778b 事后核验：
1) cards.json 里仍带「效果区多张本卡不可叠加」的卡，是否**全部**是玩家侧（class != 敌人）；
2) zh_canonical / cards_en / cards_ja / cards_es 与 cards.json 的该项是否同步（同一批 id）；
3) 9133 / 1013 / 9013 / 9115 的四语文本抽查。
"""
import io
import json
import sys

REPO = "E:/work/card_rogue/"
SENT = "效果区多张本卡不可叠加"

cards = json.load(io.open(REPO + "cards.json", encoding="utf-8"))["cards"]
idx = {str(c.get("id")): c for c in cards}

still = [(str(c["id"]), c.get("name"), c.get("class", "")) for c in cards
         if SENT in (c.get("effect_text") or "")]
print("== cards.json 仍含该句 =", len(still))
bad = [t for t in still if t[2] == "敌人"]
for t in still:
    print("  ", t)
print("   其中 class=敌人（应为 0）：", len(bad))
if bad:
    print("!! 敌人卡漏删", bad)

# 四语底本
for f in ("zh_canonical", "cards_en", "cards_ja", "cards_es"):
    path = REPO + "i18n/" + f + ".json"
    d = json.load(io.open(path, encoding="utf-8"))
    # 结构可能是 {id: {...}} 或 {"cards": ...}
    pool = d.get("cards", d) if isinstance(d, dict) else d
    n = 0
    if isinstance(pool, dict):
        for k, v in pool.items():
            txt = v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)
            if SENT in txt:
                n += 1
    print("==", f, "含该句条目 =", n)

# 抽查四语
for i in ("9133", "1013", "9013", "9242"):
    row = [i]
    c = idx.get(i)
    row.append((c.get("effect_text") or "<empty>")[:48] if c else "MISSING")
    for f in ("zh_canonical", "cards_en", "cards_ja", "cards_es"):
        d = json.load(io.open(REPO + "i18n/" + f + ".json", encoding="utf-8"))
        pool = d.get("cards", d) if isinstance(d, dict) else d
        v = pool.get(i) if isinstance(pool, dict) else None
        txt = v if isinstance(v, str) else (json.dumps(v, ensure_ascii=False) if v else "<none>")
        row.append(txt[:44])
    print(" | ".join(row))
