# -*- coding: utf-8 -*-
"""R775：更新 test_engine.gd 组合候选池数量断言（堡垒/影子猫/幽灵/鸭妈妈 入池）。
CRLF 文件，读写用 newline="" 保行尾。exact-replace + assert count==1。
"""
import io

P = "scripts/test_engine.gd"
with io.open(P, "r", encoding="utf-8", newline="") as f:
    s = f.read()

reps = [
    # 断言 1（r582 机械之心 9→10 / 全角色 36→40）
    ("check(r582_mech.size() == 9 and r582_all.size() == 36,",
     "check(r582_mech.size() == 10 and r582_all.size() == 40,"),
    ("机械之心候选 9 张 / 全角色 36 张",
     "机械之心候选 10 张 / 全角色 40 张"),
    # 断言 2（r584）
    ("check(r584_mech.size() == 9 and r584_all.size() == 36,",
     "check(r584_mech.size() == 10 and r584_all.size() == 40,"),
    ("机械之心 9 张 / 全角色 36 张",
     "机械之心 10 张 / 全角色 40 张"),
    # 注释：R589 后补 R775 四张
    ("（8 → 9 / 28 → 36）。",
     "（8 → 9 / 28 → 36）。\r\n\t# R775 堡垒 8034 / 影子猫 8006 / 幽灵 8008 / 鸭妈妈 9250 再进四张（9 → 10 / 36 → 40）。"),
    ("# R589 扩池后：机械之心 9 张（忒修斯奇械 9222）/ 全角色 36 张。",
     "# R589 扩池后：机械之心 9 张（忒修斯奇械 9222）/ 全角色 36 张。R775 起 10 / 40（堡垒 + 影子猫 + 幽灵 + 鸭妈妈）。"),
]

for old, new in reps:
    c = s.count(old)
    assert c == 1, "count=%d for %r" % (c, old)
    s = s.replace(old, new)

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s)

print("OK: 6 处替换完成")
