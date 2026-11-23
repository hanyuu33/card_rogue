"""R848 补丁 2：修 test_smoke 里两处 Variant 推断失败（`scene` 是 Variant）。"""
import io
import os
import sys

P = "E:/work/card_rogue/scripts/test_smoke.gd"


def sub1(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        print("FAIL %s: count=%d" % (tag, n))
        sys.exit(1)
    return s.replace(old, new)


with io.open(P, "r", encoding="utf-8", newline="") as f:
    s = f.read().replace("\r\n", "\n")

s = sub1(s,
         "\t\t\t\tvar lw := scene._font.get_string_size(str(ln),\n"
         "\t\t\t\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, fs).x\n",
         "\t\t\t\tvar lw: float = scene._font.get_string_size(str(ln),\n"
         "\t\t\t\t\t\tHORIZONTAL_ALIGNMENT_LEFT, -1, fs).x\n",
         "lw 类型")

s = sub1(s,
         "\tvar copy_n := scene._body_lines.size()\n",
         "\tvar copy_n: int = scene._body_lines.size()\n",
         "copy_n 类型")

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s.replace("\n", "\r\n"))
print("OK test_smoke.gd 类型修正")
