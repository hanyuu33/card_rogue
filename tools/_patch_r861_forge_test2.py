# -*- coding: utf-8 -*-
"""R861 修正：`preview_hit_damage()` 返回 `{"dmg": int, "tag": String}`，不是 int。
把 ③b 那两条断言改成先取 `["dmg"]` 再比。
"""
import io
import sys

P = "scripts/test_engine.gd"
START = "\t# ③b 技能 -2 有**两个实现口**"
END = "% r135_e2.preview_hit_damage(r135_f2, 10, true))"

NEW = "\r\n".join([
    "\t# ③b 技能 -2 有**两个实现口**：`_unit_damage_taken()`（真结算）与",
    "\t#     `preview_hit_damage()`（悬停预览伤害，返回 {dmg, tag}）。R815 的教训：",
    "\t#     规则逻辑要查所有入口 —— 预览与实战不一致，玩家会照着错数字决策。",
    "\tvar r135_pv_spell := int(r135_e2.preview_hit_damage(r135_f2, 10, false)[\"dmg\"])",
    "\tvar r135_pv_atk := int(r135_e2.preview_hit_damage(r135_f2, 10, true)[\"dmg\"])",
    "\tcheck(r135_pv_spell == 10 - GameEngine.SUN_FORGE_SPELL_REDUCE,",
    "\t\t\t\"R856 预览口同判据：技能预览也是 -%d（%d）\"",
    "\t\t\t% [GameEngine.SUN_FORGE_SPELL_REDUCE, r135_pv_spell])",
    "\tcheck(r135_pv_atk == 10,",
    "\t\t\t\"R856 预览口同判据：普攻预览不吃减伤（%d）\" % r135_pv_atk)",
])


def main() -> int:
    with io.open(P, encoding="utf-8", newline="") as f:
        s = f.read()
    i = s.find(START)
    if i < 0 or s.count(START) != 1:
        print("FAIL 起始锚点 %d 次" % s.count(START))
        return 1
    j = s.find(END, i)
    if j < 0:
        print("FAIL 结束锚点没找到")
        return 1
    j += len(END)
    s = s[:i] + NEW + s[j:]
    with io.open(P, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("ok ③b 已改为取 [\"dmg\"]")
    return 0


if __name__ == "__main__":
    sys.exit(main())
