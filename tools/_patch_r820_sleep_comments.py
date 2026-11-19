#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R820 补丁 2：清掉「沉睡」机制里残留的恶魔鸭专属说法。
「沉睡」是通用 trait（恶魔鸭 9116 / 激光巨炮 9241 …），注释不该再写成恶魔鸭专属，
否则后人会照着注释给它加鸭子专属语义。函数名 `_demon_duck_hurt` 保留不动
（改动面太大，且它确实是 R63 为恶魔鸭写的入口），只在注释里点明「历史命名」。
"""
import io


def patch(path: str, pairs):
    with io.open(path, "rb") as f:
        raw = f.read()
    crlf = b"\r\n" in raw
    text = raw.decode("utf-8")
    for old, new in pairs:
        if crlf:
            old = old.replace("\n", "\r\n")
            new = new.replace("\n", "\r\n")
        n = text.count(old)
        assert n == 1, "%s: 锚点命中 %d 次\n---\n%s" % (path, n, old)
        text = text.replace(old, new)
    with io.open(path, "wb") as f:
        f.write(text.encode("utf-8"))
    print("[OK] %s（%s）" % (path, "CRLF" if crlf else "LF"))


patch("scripts/field_state.gd", [
    ("\t\t\t\t# 沉睡（恶魔鸭 9116，R63）：还在睡 → 本回合**不行动**（复用横置通道，",
     "\t\t\t\t# 沉睡（带「沉睡」trait 的单位，R63；如恶魔鸭 9116 / 激光巨炮 9241）：\n"
     "\t\t\t\t# 还在睡 → 本回合**不行动**（复用横置通道，"),
])

patch("scripts/game_engine.gd", [
    ("\t##   沉睡（9116 恶魔鸭）→ 还在睡：sleep_left -1（受伤口；与回合口 _sleep_tick 并存）；",
     "\t##   沉睡（**任何**带「沉睡」trait 的单位：9116 恶魔鸭 / 9241 激光巨炮 …）\n"
     "\t##     → 还在睡：sleep_left -1（受伤口；与回合口 _sleep_tick 并存）；"),
])

patch("scripts/battle_scene.gd", [
    ("# 沉睡（恶魔鸭 9116）：紫脉冲环 + Zzz（还差 N 下挨打就醒）",
     "# 沉睡（带「沉睡」trait 的单位：恶魔鸭 9116 / 激光巨炮 9241）：紫脉冲环 + Zzz（还差 N 下挨打就醒）"),
    ("恶魔鸭苏醒的挣脱环（R72）", "沉睡单位苏醒的挣脱环（R72）"),
])

print("R820 patch2 done")
