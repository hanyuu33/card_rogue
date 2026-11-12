# -*- coding: utf-8 -*-
"""R589 第七批：修 test_engine —— 棋盘坐标越界 + 池数量历史断言更新。

背景：`FieldState.BOARD_ROWS = 6` / `BOARD_COLS = 3`，`play_from_hand` 会拒绝越界的格子
（`state.place` 不校验，所以看起来「放下了」其实 play 直接返回 null）。R589 用例里
用了 (6,1) / (7,1) / (8,1) / (9,1)，导致 `use_after` 那段其实是「没打出去」。

用法：
    python tools/_patch_r589g.py --check-only
    python tools/_patch_r589g.py
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv
REL = "scripts/test_engine.gd"

PATCHES = [
    ("e.state.place(bear, Vector2i(6, 1), GameEngine.SIDE_SELF)",
     "e.state.place(bear, Vector2i(0, 1), GameEngine.SIDE_SELF)",
     "熊本体改到合法格 (0,1)"),
    ("e.state.place(inh, Vector2i(7, 1), GameEngine.SIDE_SELF)",
     "e.state.place(inh, Vector2i(1, 1), GameEngine.SIDE_SELF)",
     "继承探针改到合法格 (1,1)"),
    ("e.play_from_hand(e.state.hand.find(ua), Vector2i(8, 1))",
     "e.play_from_hand(e.state.hand.find(ua), Vector2i(3, 1))",
     "use_after 产物改到合法格 (3,1)"),
    ("""\t# 补零件：R582 充电装置 / 嵌合暴君进池（4 → 6 / 24 → 26），
\t# R584 无限装甲 8038 / 集束炮台 9166 再进两张（6 → 8 / 26 → 28）。
\t# 构装体 8026 是白板（不补零件、不进池），由 _open_combo 强制注入当底座。
\tvar r582_e0 := _new_engine([], 20, 20)
\tvar r582_mech: Array = r582_e0._combo_candidate_cards(PlayerClass.MECH)
\tvar r582_all: Array = r582_e0._combo_candidate_cards()
\tcheck(r582_mech.size() == 8 and r582_all.size() == 28,
\t\t\t"R582/R584 补零件：机械之心候选 8 张 / 全角色 28 张（实际 %d / %d）\"""",
     """\t# 补零件：R582 充电装置 / 嵌合暴君进池（4 → 6 / 24 → 26），
\t# R584 无限装甲 8038 / 集束炮台 9166 再进两张（6 → 8 / 26 → 28），
\t# R589 忒修斯奇械 9222 + 七张素材再进一批（8 → 9 / 28 → 36）。
\t# 构装体 8026 是白板（不补零件、不进池），由 _open_combo 强制注入当底座。
\tvar r582_e0 := _new_engine([], 20, 20)
\tvar r582_mech: Array = r582_e0._combo_candidate_cards(PlayerClass.MECH)
\tvar r582_all: Array = r582_e0._combo_candidate_cards()
\tcheck(r582_mech.size() == 9 and r582_all.size() == 36,
\t\t\t"R589 扩池：机械之心候选 9 张 / 全角色 36 张（实际 %d / %d）\"""",
     "R582 历史快照 8/28 → 9/36"),
    ("""\tcheck(r584_mech.size() == 8 and r584_all.size() == 28,
\t\t\t"R584 补零件：机械之心 8 张 / 全角色 28 张（实际 %d / %d）\"""",
     """\t# R589 扩池后：机械之心 9 张（忒修斯奇械 9222）/ 全角色 36 张。
\tcheck(r584_mech.size() == 9 and r584_all.size() == 36,
\t\t\t"R589 扩池：机械之心 9 张 / 全角色 36 张（实际 %d / %d）\"""",
     "R584 历史快照 8/28 → 9/36"),
]


def main():
    with io.open(os.path.join(ROOT, REL), "r", encoding="utf-8", newline="") as f:
        text = f.read()
    ok = True
    for old, new, note in PATCHES:
        cnt = text.count(old)
        use_old, use_new = old, new
        if cnt == 0:
            crlf_old = old.replace("\n", "\r\n")
            if text.count(crlf_old) == 1:
                use_old, use_new = crlf_old, new.replace("\n", "\r\n")
                cnt = 1
        if cnt != 1:
            print("[FAIL] %s（命中 %d 次）" % (note, cnt))
            ok = False
            continue
        text = text.replace(use_old, use_new, 1)
        print("[ok] %s" % note)
    # 只在本轮追加的 `_test_r589()` 段里换格子 —— 别处可能有同样的坐标，不能一起改。
    marker = "func _test_r589() -> void:"
    if text.count(marker) != 1:
        print("[FAIL] 找不到唯一的 _test_r589 段")
        return 1
    head, tail = text.split(marker, 1)
    n9 = tail.count("Vector2i(9, 1)")
    if n9 != 6:
        print("[FAIL] `_test_r589` 段内 `Vector2i(9, 1)` 命中 %d 处（期望 6）" % n9)
        ok = False
    else:
        text = head + marker + tail.replace("Vector2i(9, 1)", "Vector2i(0, 2)")
        print("[ok] 动作探针格子 (9,1) → (0,2) ×6")
    if not ok:
        return 1
    if CHECK:
        print("--check-only：未写文件。")
        return 0
    with io.open(os.path.join(ROOT, REL), "w", encoding="utf-8", newline="") as f:
        f.write(text)
    b = open(os.path.join(ROOT, REL), "rb").read()
    print("[write] %s（CRLF %d / bareLF %d）" % (REL, b.count(b"\r\n"), b.count(b"\n") - b.count(b"\r\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
