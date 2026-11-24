# -*- coding: utf-8 -*-
"""R832：把「显示用中文」同步到 canonical。

背景：三语（cards_en/ja/es、noncard_en/ja/es）都是按 `i18n/zh_canonical.json` /
`i18n/noncard_zh_canonical.json` 翻的，但玩家看到的**中文**来自 `cards.json` /
`relics.json`，两处长期没跟上术语规范化（手卡→手牌、卡组→抽牌库、弃牌堆→弃牌区、
生命值→生命、一回合行动两次→每回合可以行动两次）与后续补充说明（获得时：…）。
结果：中文说「从卡组」，英文说 "from your Draw Pile"，同一个效果两种口径。

本脚本只做**原文替换**（不重整 JSON 格式、不动行尾），逐条断言 count==1。
"""
import io
import json
import sys

ROOT = "E:/work/card_rogue/"


def load_text(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def dump_text(rel, s):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(s)


def jstr(s):
    return json.dumps(s, ensure_ascii=False)


def sync(path, pairs, label):
    s = load_text(path)
    bad = []
    for old, new, tag in pairs:
        o, n = jstr(old), jstr(new)
        c = s.count(o)
        if c != 1:
            bad.append((tag, c, old[:40]))
            continue
        s = s.replace(o, n, 1)
    if bad:
        print("!! %s 有 %d 条无法唯一定位：" % (label, len(bad)))
        for tag, c, t in bad:
            print("   %s count=%d %r" % (tag, c, t))
        sys.exit(1)
    dump_text(path, s)
    print("ok %s：替换 %d 条" % (label, len(pairs)))


cards = json.load(io.open(ROOT + "cards.json", encoding="utf-8"))["cards"]
zh = json.load(io.open(ROOT + "i18n/zh_canonical.json", encoding="utf-8"))["cards"]
pairs = []
for c in cards:
    a = c.get("effect_text", "")
    b = zh[str(c["id"])]["effect_text"]
    if a != b:
        pairs.append((a, b, "%d %s" % (c["id"], c["name"])))
print("卡待同步 %d 条" % len(pairs))
sync("cards.json", pairs, "cards.json")

rel = json.load(io.open(ROOT + "relics.json", encoding="utf-8"))["relics"]
nz = json.load(io.open(ROOT + "i18n/noncard_zh_canonical.json", encoding="utf-8"))["relics"]
rp = []
for r in rel:
    a = r.get("desc", "")
    b = nz[str(r["id"])]["desc"]
    if a != b:
        rp.append((a, b, "%d %s" % (r["id"], r["name"])))
print("道具待同步 %d 条" % len(rp))
sync("relics.json", rp, "relics.json")
