# -*- coding: utf-8 -*-
"""R595d：体检脚本认 `art_plan.json` 的 `skip` —— 弃用卡不算「缺图」。

9158 罐子（工事）在 skip 里写着「永久不出图」（店长 2026-11-11 定案，
旧召唤物机制已弃用）。它一直挂在「真缺」里会让报告永远收不了口。
"""
import io

P = "tools/audit_release_assets.py"
s = io.open(P, encoding="utf-8").read()


def sub(old, new, n=1):
    global s
    c = s.count(old)
    assert c == n, "anchor count=%d want %d: %r" % (c, n, old[:60])
    s = s.replace(old, new)


sub('''CLASS_SUFFIX = ["_forest", "_mech", "_shadow"]
miss_cards = []      # 两张都没有 = 真待生成
pend_cards = []      # 正式库没有、_pending 有 = 等审批
for c in items:
    cid = c["id"]
    variants = []''',
    '''CLASS_SUFFIX = ["_forest", "_mech", "_shadow"]
# `art_plan.json.skip` 里的是**已定案不再出图**的卡（如 9158 弃用的旧召唤物机制）。
# 它们既不算「缺」也不算「待办」，单列一态，否则报告永远收不了口。
try:
    _plan = load_json("art_plan.json")
    SKIP = {int(k): v for k, v in (_plan.get("skip") or {}).items()}
except Exception:                                              # noqa: BLE001
    SKIP = {}
miss_cards = []      # 两张都没有 = 真待生成
pend_cards = []      # 正式库没有、_pending 有 = 等审批
skip_cards = []      # 已定案永久不出图
for c in items:
    cid = c["id"]
    variants = []''')

sub('''    if png_pend(str(cid)):
        pend_cards.append(row)
    else:
        miss_cards.append(row)
report["cards"] = {"total": len(items),
                   "have": len(items) - len(miss_cards) - len(pend_cards),
                   "pending": pend_cards, "missing": miss_cards}''',
    '''    if cid in SKIP:
        row["reason"] = SKIP[cid]
        skip_cards.append(row)
    elif png_pend(str(cid)):
        pend_cards.append(row)
    else:
        miss_cards.append(row)
report["cards"] = {"total": len(items),
                   "have": len(items) - len(miss_cards) - len(pend_cards) - len(skip_cards),
                   "pending": pend_cards, "missing": miss_cards, "skipped": skip_cards}''')

sub('''L.append("卡图　　已归档 %3d ／ 待审批 %3d ／ 真缺 %3d（共 %d）"
         % (len(items) - len(miss_cards) - len(pend_cards), len(pend_cards),
            len(miss_cards), len(items)))''',
    '''L.append("卡图　　已归档 %3d ／ 待审批 %3d ／ 真缺 %3d ／ 已弃用 %d（共 %d）"
         % (len(items) - len(miss_cards) - len(pend_cards) - len(skip_cards),
            len(pend_cards), len(miss_cards), len(skip_cards), len(items)))''')

sub('''if report["cards"]["orphan"]:''',
    '''if skip_cards:
    L.append("── 已弃用·不出图 %d 张（art_plan.json.skip）──" % len(skip_cards))
    for m in skip_cards:
        L.append("  %5d  %s —— %s" % (m["id"], m["name"], m.get("reason", "")))
    L.append("")
if report["cards"]["orphan"]:''')

io.open(P, "w", encoding="utf-8", newline="\n").write(s)
print("patched", len(s), "bytes")
