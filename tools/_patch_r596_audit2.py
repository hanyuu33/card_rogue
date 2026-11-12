# -*- coding: utf-8 -*-
"""R596 素材体检口径修正（2）：稀有度缎带按**卡库实际用到的 rarity** 反查。

`ribbon_0..5` 齐全，但卡库里 rarity 6（诅咒）有 4 张卡在用 —— `ribbon_6.png` 不存在，
这 4 张卡面右上角会回退成程序绘制的小旗，和另外 312 张不一致。
"""
import io

P = "tools/audit_release_assets.py"
s = io.open(P, encoding="utf-8").read()

anchor = '''report["relics"] = {"total": len(ritems), "missing_icon": miss_icon, "missing_rim": miss_rim}'''
add = anchor + '''

# ── ②b 稀有度缎带（按卡库实际用到的 rarity 反查）───────────────────────
# `UiAssets.rarity_ribbon(r)` → `ribbon_<r>.png`，下标同 CardData.RARITY_COLORS（0..6）。
# 诅咒卡 rarity=6，素材名 ribbon_6 —— 只按 0..5 数会漏掉「诅咒卡没有缎带」。
used_rarity = sorted({int(c.get("rarity", 0)) for c in items})
rib_missing = [r for r in used_rarity if not png_ui("ribbon_%d" % r)]
by_rarity = {}
for c in items:
    by_rarity.setdefault(int(c.get("rarity", 0)), []).append(c["id"])
report["ribbon"] = {"used": used_rarity, "missing": rib_missing,
                    "missing_cards": {str(r): by_rarity[r] for r in rib_missing}}'''
assert s.count(anchor) == 1
s = s.replace(anchor, add)

anchor2 = '''L.append("职业素材缺 %2d（%s）"'''
add2 = '''L.append("稀有度缎带缺 %2d ／ %d 档在用   %s"
         % (len(rib_missing), len(used_rarity),
            " ".join("ribbon_%d(卡%s)" % (r, by_rarity[r]) for r in rib_missing)))
''' + anchor2
assert s.count(anchor2) == 1
s = s.replace(anchor2, add2)

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("patched ok")
