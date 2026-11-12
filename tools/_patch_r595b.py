# -*- coding: utf-8 -*-
"""R595b：素材体检脚本补两处漏判 —— ① `assets/pics/_pending/` 待审目录 ② 三态区分。

背景：R595 报告把 92 张「缺图」全归为待生成，实际有 89 张早已在 `_pending/` 里等审批。
纯 LF 文件，逐段 exact-replace + assert count==1。
"""
import io

P = "tools/audit_release_assets.py"
s = io.open(P, encoding="utf-8").read()


def sub(old, new, n=1):
    global s
    c = s.count(old)
    assert c == n, "anchor count=%d want %d: %r" % (c, n, old[:60])
    s = s.replace(old, new)


# ① 路径常量 + 取图判定
sub('''PICS = os.path.join(ROOT, "assets", "pics")''',
    '''PICS = os.path.join(ROOT, "assets", "pics")
# R595b：`_pending/` 是「已出图、等店长审批」的暂存层（同 448×403 规格）。
# 它不属于 assets/pics 正式库，但**绝不能算成「没做过」** —— R595 就是漏了这层，
# 把 89 张已完成的图报成待生成。
PEND = os.path.join(PICS, "_pending")''')

sub('''def png_pic(name):
    return os.path.exists(os.path.join(PICS, name + ".png"))''',
    '''def png_pic(name):
    return os.path.exists(os.path.join(PICS, name + ".png"))


def png_pend(name):
    return os.path.exists(os.path.join(PEND, name + ".png"))''')

# ② 卡图三态
sub('''CLASS_SUFFIX = ["_forest", "_mech", "_shadow"]
miss_cards = []
for c in items:
    cid = c["id"]
    if png_pic(str(cid)):
        continue
    variants = [s for s in CLASS_SUFFIX if png_pic(str(cid) + s)]
    if len(variants) == len(CLASS_SUFFIX):       # 三职业变体齐全 = 不缺
        continue
    miss_cards.append({"id": cid, "name": c.get("name", ""), "kind": c.get("kind", ""),
                       "rarity": c.get("rarity", 0), "group": c.get("group", ""),
                       "card_class": c.get("class", ""), "variants": variants})
report["cards"] = {"total": len(items),
                   "have": len(items) - len(miss_cards), "missing": miss_cards}''',
    '''CLASS_SUFFIX = ["_forest", "_mech", "_shadow"]
miss_cards = []      # 两张都没有 = 真待生成
pend_cards = []      # 正式库没有、_pending 有 = 等审批
for c in items:
    cid = c["id"]
    variants = []
    if png_pic(str(cid)):
        continue
    variants = [s for s in CLASS_SUFFIX if png_pic(str(cid) + s)]
    if len(variants) == len(CLASS_SUFFIX):       # 三职业变体齐全 = 不缺
        continue
    row = {"id": cid, "name": c.get("name", ""), "kind": c.get("kind", ""),
           "rarity": c.get("rarity", 0), "group": c.get("group", ""),
           "card_class": c.get("class", ""), "variants": variants}
    if png_pend(str(cid)):
        pend_cards.append(row)
    else:
        miss_cards.append(row)
report["cards"] = {"total": len(items),
                   "have": len(items) - len(miss_cards) - len(pend_cards),
                   "pending": pend_cards, "missing": miss_cards}

# `_pending` 里有、卡库里已经没有的 id（卡被删或改号后的残留，只报不删）
known = {c["id"] for c in items}
orphan = sorted(int(os.path.basename(p)[:-4]) for p in __import__("glob").glob(
    os.path.join(PEND, "*.png")) if os.path.basename(p)[:-4].isdigit())
report["cards"]["orphan"] = [i for i in orphan if i not in known]''')

# ③ 文本摘要行
sub('''L.append("卡图　　缺 %3d / %d" % (len(miss_cards), len(items)))''',
    '''L.append("卡图　　已归档 %3d ／ 待审批 %3d ／ 真缺 %3d（共 %d）"
         % (len(items) - len(miss_cards) - len(pend_cards), len(pend_cards),
            len(miss_cards), len(items)))''')

# ④ 缺卡清单段：分开列
sub('''if miss_cards:
    by = {}
    for m in miss_cards:
        by.setdefault((m["group"], m["kind"]), []).append(m)
    L.append("── 缺卡图 %d 张（按 阵营/种类）──" % len(miss_cards))
    for (g, k), v in sorted(by.items(), key=lambda x: -len(x[1])):
        L.append("  %-6s %-4s %d 张" % (g, k, len(v)))
    L.append("")
    for m in miss_cards:
        L.append("  %5d  %-3s %-4s r%-2s %-12s %s"
                 % (m["id"], m["group"][:3], m["kind"], m["rarity"], m["card_class"], m["name"]))''',
    '''if miss_cards:
    by = {}
    for m in miss_cards:
        by.setdefault((m["group"], m["kind"]), []).append(m)
    L.append("── 真缺卡图 %d 张（按 阵营/种类）──" % len(miss_cards))
    for (g, k), v in sorted(by.items(), key=lambda x: -len(x[1])):
        L.append("  %-6s %-4s %d 张" % (g, k, len(v)))
    L.append("")
    for m in miss_cards:
        L.append("  %5d  %-3s %-4s r%-2s %-12s %s"
                 % (m["id"], m["group"][:3], m["kind"], m["rarity"], m["card_class"], m["name"]))
    L.append("")
if pend_cards:
    L.append("── 待审批 %d 张（图在 assets/pics/_pending/，未 approve 未提交）──"
             % len(pend_cards))
    L.append("  " + "  ".join("%d %s" % (m["id"], m["name"]) for m in pend_cards))
    L.append("")
if report["cards"]["orphan"]:
    L.append("── _pending 孤儿 id（不在卡库）── " + " ".join(map(str, report["cards"]["orphan"])))
    L.append("")''')

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("patched", len(s), "bytes")
