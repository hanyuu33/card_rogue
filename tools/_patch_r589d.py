# -*- coding: utf-8 -*-
"""R589 第四批：把七个新动作登记进 `ASSEMBLE_EFFECT_TYPES` 白名单。

（第一批只改了校验分支与文案，漏了白名单本身 —— 校验的第一关就是
`type not in ASSEMBLE_EFFECT_TYPES`，所以七个动作全被判成「不可执行」。）

用法：
    python tools/_patch_r589d.py --check-only
    python tools/_patch_r589d.py
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv
REL = "scripts/card_data.gd"

OLD = '''\t# R585：把指定卡加入抽牌库（集束炮台 9166 的入场句）。
\t"add_card_to_deck",
]'''
NEW = '''\t# R585：把指定卡加入抽牌库（集束炮台 9166 的入场句）。
\t"add_card_to_deck",
\t# R589：七条新动作 —— 每条都有母卡实现口，组合与母卡共用同一个函数：
\t#   小精灵 9074 / 斑鸠 9052 / 水元素 9068 / 影魔 8007（两条）/ 巨鼠 9046 / 乌鸦 9039。
\t"next_effect_discount", "next_ally_discount", "add_effect_from_deck",
\t"hand_skill_discount", "hp_per_zero_skill",
\t"fetch_cheapest_ally", "recall_ally_from_discard",
]'''


def main():
    with io.open(os.path.join(ROOT, REL), "r", encoding="utf-8", newline="") as f:
        text = f.read()
    cnt = text.count(OLD)
    if cnt == 0:
        crlf = OLD.replace("\n", "\r\n")
        if text.count(crlf) == 1:
            OLD2, NEW2 = crlf, NEW.replace("\n", "\r\n")
            cnt = 1
        else:
            print("[FAIL] 锚点命中 0 次")
            return 1
    else:
        if cnt != 1:
            print("[FAIL] 锚点命中 %d 次（要求 1）" % cnt)
            return 1
        OLD2, NEW2 = OLD, NEW
    text = text.replace(OLD2, NEW2, 1)
    print("[ok] ASSEMBLE_EFFECT_TYPES 加七个动作")
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
