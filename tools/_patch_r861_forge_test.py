# -*- coding: utf-8 -*-
"""R861：太阳熔炉双动判据修复（id==9131 → is_mass_produced 全族）配套测试。

补两条，锁住「判据必须是全族」这件事从**判据层**一直对到**行为层 / 预览层**：

  ①b 双动光环的行为层：9138（名字前缀来源）/ 8074（trait 来源）也要 acts_left == 2。
      原测试只断言 9131 —— 判据退回 `id == SUN_FORGE_FURY_ID` 时它照样全绿，
      R856 的 bug 就是这么溜过去的。
  ③b 技能 -2 的**第二个实现口** `preview_hit_damage()`（悬停预览）与
      `_unit_damage_taken()`（真结算）必须同判据（R815：规则逻辑要查所有入口）。

⚠️ 本文件行间是「每行之间一个空行」的排版，插入时按同一风格（`\r\n\r\n` 分隔）。
"""
import io
import sys

P = "scripts/test_engine.gd"
SEP = "\r\n\r\n"

A_ANCHOR = '\t\t\t"R135 光环只给俄倪厄：赫利俄斯自己仍 1 次行动（实际 %d）" % r135_h.acts_left)'
A_BLOCK = [
    '\t# ①b R856：光环的受惠者是**整个量产型族**，上面那条只钉住 9131 ——',
    '\t#     判据一旦退回 `id == SUN_FORGE_FURY_ID`，它仍然全绿（R856 的 bug 就是这么溜过去的）。',
    '\t#     所以这里从**行为层**再钉两张：名字前缀来源（9138，trait 里没有「量产型」）',
    '\t#     与 trait 来源（8074，名字带前缀同时挂 trait）。',
    '\tvar r135_mass_n: CardData = repo.get_card(9138)',
    '\tvar r135_mass_t: CardData = repo.get_card(8074)',
    '\tcheck(r135_mass_n != null and r135_mass_t != null,',
    '\t\t\t"R856 前置：9138 量产型赫菲斯托斯 / 8074 量产型代达罗斯都在卡库里")',
    '\tvar r135_mass_np := r135_e.state.place(CardData.from_dict(r135_mass_n.to_dict()),',
    '\t\t\tVector2i(2, 2), GameEngine.SIDE_OPPONENT)',
    '\tvar r135_mass_tp := r135_e.state.place(CardData.from_dict(r135_mass_t.to_dict()),',
    '\t\t\tVector2i(1, 2), GameEngine.SIDE_OPPONENT)',
    '\tr135_e.state.reset_units(GameEngine.SIDE_OPPONENT)',
    '\tcheck(r135_mass_np.acts_left == GameEngine.SUN_FORGE_ACTIONS,',
    '\t\t\t"R856 全族双动：名字前缀来源（9138）也吃光环（实际 %d）" % r135_mass_np.acts_left)',
    '\tcheck(r135_mass_tp.acts_left == GameEngine.SUN_FORGE_ACTIONS,',
    '\t\t\t"R856 全族双动：trait 来源（8074）也吃光环（实际 %d）" % r135_mass_tp.acts_left)',
]

B_ANCHOR = '\t# ④ 两条光环都以「赫利俄斯还在场」为前提 → 拆塔立刻断'
B_BLOCK = [
    '\t# ③b 技能 -2 有**两个实现口**：`_unit_damage_taken()`（真结算）与',
    '\t#     `preview_hit_damage()`（悬停预览伤害）。R815 的教训：规则逻辑要查所有入口 ——',
    '\t#     预览与实战不一致，玩家会照着一个错数字去决策（比不显示更糟）。',
    '\tcheck(r135_e2.preview_hit_damage(r135_f2, 10, false)',
    '\t\t\t== 10 - GameEngine.SUN_FORGE_SPELL_REDUCE,',
    '\t\t\t"R856 预览口同判据：技能预览也是 -%d（%d）"',
    '\t\t\t% [GameEngine.SUN_FORGE_SPELL_REDUCE, r135_e2.preview_hit_damage(r135_f2, 10, false)])',
    '\tcheck(r135_e2.preview_hit_damage(r135_f2, 10, true) == 10,',
    '\t\t\t"R856 预览口同判据：普攻预览不吃减伤（%d）"',
    '\t\t\t% r135_e2.preview_hit_damage(r135_f2, 10, true))',
]


def main() -> int:
    with io.open(P, encoding="utf-8", newline="") as f:
        s = f.read()
    for anchor, block, where, tag in ((A_ANCHOR, A_BLOCK, "after", "①b"),
                                      (B_ANCHOR, B_BLOCK, "before", "③b")):
        n = s.count(anchor)
        if n != 1:
            print("FAIL %s 锚点出现 %d 次" % (tag, n))
            return 1
        payload = SEP + SEP.join(block)
        if where == "after":
            s = s.replace(anchor, anchor + payload, 1)
        else:
            s = s.replace(anchor, payload + SEP + anchor, 1)
    with io.open(P, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("ok test_engine.gd 已插入 ①b / ③b")
    return 0


if __name__ == "__main__":
    sys.exit(main())
