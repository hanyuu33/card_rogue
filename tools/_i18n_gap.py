# -*- coding: utf-8 -*-
"""英文本地化真实缺口统计：源码实际会取哪些 key，en 文件里有没有。

只看运行时真正走的路径（GameI18n.ui / card_name / card_effect / relic_* /
trap_* / class_field），不做文件结构对比——zh_canonical 是源清单，结构不同。
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
I18N = ROOT / "i18n"


def jload(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def main():
    # ---------- 卡牌 ----------
    cards = jload(ROOT / "cards.json")["cards"]
    en_cards = jload(I18N / "cards_en.json")["cards"]
    print("=== 卡牌 ===")
    print("cards.json 条目:", len(cards), " cards_en 条目:", len(en_cards))
    if isinstance(cards, dict):
        ids = set(str(k) for k in cards)
    else:
        ids = set(str(c.get("id")) for c in cards)
    if isinstance(en_cards, dict):
        en_ids = set(str(k) for k in en_cards)
    else:
        en_ids = set(str(c.get("id")) for c in en_cards)
    missing = sorted(ids - en_ids, key=lambda s: int(s) if s.isdigit() else 0)
    print("缺英文卡:", len(missing))
    # 逐字段：name / effect_text
    src = cards if isinstance(cards, dict) else {str(c.get("id")): c for c in cards}
    dst = en_cards if isinstance(en_cards, dict) else {str(c.get("id")): c for c in en_cards}
    miss_name, miss_eff = [], []
    for cid in sorted(ids, key=lambda s: int(s) if s.isdigit() else 0):
        s = src.get(cid, {})
        d = dst.get(cid, {})
        if s.get("name") and not d.get("name"):
            miss_name.append((cid, s.get("name")))
        if s.get("effect_text") and not d.get("effect_text"):
            miss_eff.append((cid, s.get("name"), s.get("effect_text", "")[:50]))
    print("  缺 name:", len(miss_name), " 缺 effect_text:", len(miss_eff))
    for x in miss_name[:10]:
        print("    ", x)
    for x in miss_eff[:10]:
        print("    ", x)

    # ---------- 遗物 ----------
    print("\n=== 遗物 ===")
    relics = jload(ROOT / "relics.json")
    noncard_en = jload(I18N / "noncard_en.json")
    print("noncard_en 顶层:", list(noncard_en.keys()))
    rl = relics.get("relics", relics) if isinstance(relics, dict) else relics
    src_r = {str(r.get("id")): r for r in rl} if isinstance(rl, list) else {str(k): v for k, v in rl.items()}
    en_r = noncard_en.get("relics", {})
    en_r = {str(r.get("id")): r for r in en_r} if isinstance(en_r, list) else {str(k): v for k, v in en_r.items()}
    rm = [k for k in src_r if k not in en_r]
    print("relics.json:", len(src_r), " en:", len(en_r), " 缺:", len(rm))
    for k in rm[:10]:
        print("    ", k, src_r[k].get("name"))
    # 字段级
    miss_rd = [(k, src_r[k].get("name")) for k in src_r if k in en_r and src_r[k].get("desc") and not en_r[k].get("desc")]
    print("  缺 desc:", len(miss_rd), miss_rd[:6])

    # ---------- 职业 ----------
    print("\n=== 职业 / 其他 noncard ===")
    for sec in ("classes", "traps"):
        if sec in noncard_en:
            print(" ", sec, ":", list(noncard_en[sec].keys())[:8])

    # ---------- UI 调用 ----------
    print("\n=== UI 取文口覆盖 ===")
    calls = set()
    pat = re.compile(r'GameI18n\.ui\(\s*"([^"]+)"\s*,\s*"([^"]+)"')
    for gd in (ROOT / "scripts").glob("*.gd"):
        if gd.name.startswith("test_"):
            continue
        for m in pat.finditer(gd.read_text(encoding="utf-8")):
            calls.add((m.group(1), m.group(2), gd.name))
    en_ui = jload(I18N / "interface_en.json").get("scopes", {})
    en_keys = set()
    for scope, kv in en_ui.items():
        if isinstance(kv, dict):
            for k in kv:
                en_keys.add((scope, k))
    src_keys = set((s, k) for s, k, _ in calls)
    miss_ui = sorted(src_keys - en_keys)
    print("源码 ui() 调用:", len(calls), " 唯一 key:", len(src_keys))
    print("interface_en scopes:", len(en_ui), " key:", len(en_keys))
    print("缺英文 UI:", len(miss_ui))
    for s, k in miss_ui[:25]:
        f = [g for ss, kk, g in calls if ss == s and kk == k]
        print("    %s.%s  (%s)" % (s, k, f[0] if f else "?"))


if __name__ == "__main__":
    main()
