# -*- coding: utf-8 -*-
"""R589 第十批：素体永不进候选池（用户口径「记录一下素体永不加入」）的**代码级**守卫。

光靠「现在没写 upper/lower 零件所以进不来」是巧合，不是约束 —— 将来谁给 8025 补了
零件就会静默入池。这里按 `TECH_FUSION_BASE_ID` 的同一写法钉死。

用法：python tools/_patch_r589j.py [--check-only]
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv

PATCHES = [
    ("scripts/game_engine.gd",
     '''\t\tif c.id == TECH_FUSION_BASE_ID:
\t\t\tcontinue''',
     '''\t\tif c.id == TECH_FUSION_BASE_ID:
\t\t\tcontinue
\t\t# R589（用户口径「记录一下素体永不加入」）：素体 8025 是**万用素材** ——
\t\t# 任何改造都额外吃一口血、还带「留手」不弃，放进候选池就等于让人用一张
\t\t# 1 费白板当属性槽白嫖身材。这是硬约束，不是「它现在没零件所以进不来」的巧合。
\t\t# （堡垒 8034「纯持续效果」不同：它没有扳机，天然进不了池，不必写死 id。）
\t\tif c.id == PROTO_ID:
\t\t\tcontinue''',
     "_combo_candidate_cards 挡掉素体"),

    ("scripts/test_engine.gd",
     '''\t# ── ② lethal：跨越判定 ────────────────────────────────────────────────''',
     '''\t# 素体永不进候选池（用户口径）—— 即使将来有人给它补了上下半零件，也得挡在这里
\tvar r589_no_proto := true
\tfor r589_pc: CardData in e._combo_candidate_cards():
\t\tif r589_pc.id == GameEngine.PROTO_ID:
\t\t\tr589_no_proto = false
\tcheck(r589_no_proto, "R589：素体 8025 永不进组装候选池")
\t# ── ② lethal：跨越判定 ────────────────────────────────────────────────''',
     "test_engine 加素体守卫断言"),
]


def main():
    ok = True
    files = {}
    for rel, old, new, note in PATCHES:
        if rel not in files:
            with io.open(os.path.join(ROOT, rel), "r", encoding="utf-8", newline="") as f:
                files[rel] = f.read()
        cnt = files[rel].count(old)
        use_old, use_new = old, new
        if cnt == 0:
            crlf_old = old.replace("\n", "\r\n")
            if files[rel].count(crlf_old) == 1:
                use_old, use_new = crlf_old, new.replace("\n", "\r\n")
                cnt = 1
        if cnt != 1:
            print("[FAIL] %s：锚点命中 %d 次 —— %s" % (rel, cnt, note))
            ok = False
            continue
        files[rel] = files[rel].replace(use_old, use_new, 1)
        print("[ok] %s：%s" % (rel, note))
    if not ok:
        return 1
    if CHECK:
        print("--check-only：未写文件。")
        return 0
    for rel, text in files.items():
        with io.open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as f:
            f.write(text)
        b = open(os.path.join(ROOT, rel), "rb").read()
        print("[write] %s（CRLF %d / bareLF %d）"
              % (rel, b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
