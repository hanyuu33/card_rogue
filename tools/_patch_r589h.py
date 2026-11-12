# -*- coding: utf-8 -*-
"""R589 第八批：把 test_engine 里的探针单位全部挪到**己方半场**合法格。

背景：`FieldState.BOARD_ROWS = 6` / `BOARD_COLS = 3`，且 `row < OPPONENT_ROWS(3)` 是敌方半场。
开局敌方会在自己那半场放单位，`state.place()` 撞到已占格会失败返回 null ——
于是「熊本体仍能主动发动」那条其实拿着一个 null 在问。

用法：
    python tools/_patch_r589h.py --check-only
    python tools/_patch_r589h.py
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv
REL = "scripts/test_engine.gd"

PATCHES = [
    ("e.state.place(bear, Vector2i(0, 1), GameEngine.SIDE_SELF)",
     "e.state.place(bear, Vector2i(3, 1), GameEngine.SIDE_SELF)",
     "熊本体 → (3,1) 己方半场"),
    ("e.state.place(inh, Vector2i(1, 1), GameEngine.SIDE_SELF)",
     "e.state.place(inh, Vector2i(3, 0), GameEngine.SIDE_SELF)",
     "继承探针 → (3,0)"),
    ("e.state.place(lt, Vector2i(2, 1), GameEngine.SIDE_SELF)",
     "e.state.place(lt, Vector2i(4, 0), GameEngine.SIDE_SELF)",
     "lethal 探针 → (4,0)"),
    ("e.play_from_hand(e.state.hand.find(ua), Vector2i(3, 1))",
     "e.play_from_hand(e.state.hand.find(ua), Vector2i(3, 2))",
     "use_after 产物 → (3,2)"),
]


def main():
    with io.open(os.path.join(ROOT, REL), "r", encoding="utf-8", newline="") as f:
        text = f.read()
    ok = True
    for old, new, note in PATCHES:
        if text.count(old) != 1:
            print("[FAIL] %s（命中 %d 次）" % (note, text.count(old)))
            ok = False
            continue
        text = text.replace(old, new, 1)
        print("[ok] %s" % note)
    marker = "func _test_r589() -> void:"
    head, tail = text.split(marker, 1)
    n0 = tail.count("Vector2i(0, 2)")
    if n0 != 6:
        print("[FAIL] `_test_r589` 段内 (0,2) 命中 %d 处（期望 6）" % n0)
        ok = False
    else:
        text = head + marker + tail.replace("Vector2i(0, 2)", "Vector2i(5, 0)")
        print("[ok] 动作探针格子 (0,2) → (5,0) ×6")
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
