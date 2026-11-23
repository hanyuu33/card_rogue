# -*- coding: utf-8 -*-
"""R787：把「模拟被商店附魔过的卡」的测试数据也降到 +8。

⚠️ 只改**模拟当前形态**的用例；明确测「老存档 mod 反推」的保留 +10
   （`test_smoke` 的 `{"power": 10}` 无 id 用例 / `enchant_id_of` 反推用例）——
   那正是 R787 之前真实写出去的东西，改掉就等于不测兼容了。
"""
import io
import sys

ROOT = "E:/work/card_rogue/"


def load(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def save(rel, s):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(s)


def rep(s, old, new, tag):
    """幂等替换：已经改过（old 不在、new 在）就跳过 —— 脚本可能被重跑。"""
    n = s.count(old)
    if n == 0 and s.count(new) >= 1:
        return s
    if n != 1:
        print("FAIL [%s] 命中 %d 次：%r" % (tag, n, old[:70]))
        sys.exit(1)
    return s.replace(old, new, 1)


EOL = "\r\n"

# ── run_state.gd（LF）──
P = "scripts/run_state.gd"
s = load(P)
s = rep(s,
        "消费点与商店的「伤害 +10」完全同源",
        "消费点与商店的「伤害 +8」完全同源", "rs-4142")
save(P, s)
print("OK", P)

# ── shop_scene.gd（CRLF）──
P = "scripts/shop_scene.gd"
s = load(P)
s = rep(s,
        "##   * 伤害 +10（**只可「能直接造成伤害」的技能卡**",
        "##   * 伤害 +8（**只可「能直接造成伤害」的技能卡**", "shop-7")
s = rep(s,
        "##     技能卡造成的伤害 +10）价 60",
        "##     技能卡造成的伤害 +8）价 60", "shop-8")
s = rep(s,
        "（截图核对「伤害 +10 只能选技能卡」）",
        "（截图核对「伤害 +8 只能选技能卡」）", "shop-239")
s = rep(s,
        '## R210：`ench_id` 可传 "damage" 出「伤害 +10 只能选技能卡」的对比图。',
        '## R210：`ench_id` 可传 "damage" 出「伤害 +8 只能选技能卡」的对比图。', "shop-1708")
save(P, s)
print("OK", P)

# ── test_engine.gd（CRLF）──
P = "scripts/test_engine.gd"
s = load(P)

# ① R259 终结预览：5 + 8 = 13
s = rep(s,
        "\tr259_ench.power = 10   # 附魔「伤害 +10」烤进 power",
        "\tr259_ench.power = 8    # 附魔「伤害 +8」烤进 power", "te-19256a")
s = rep(s,
        "check(int(r259.spell_now(r259_ench).get(\"dmg\", -1)) == 15,",
        "check(int(r259.spell_now(r259_ench).get(\"dmg\", -1)) == 13,", "te-19256b")
s = rep(s,
        "\"R262 终结：附魔 +10 也算进预览（5+10=15）\"",
        "\"R262 终结：附魔 +8 也算进预览（5+8=13）\"", "te-19256c")

# ② R210：17 + 8 = 25
s = rep(s,
        "\t# ---- R210：伤害 +10 附魔只给技能卡",
        "\t# ---- R210：伤害 +8 附魔只给技能卡", "te-38430")
s = rep(s,
        "r210_spell_up.power += 10                             # 模拟商店附魔烤进 power",
        "r210_spell_up.power += 8                              # 模拟商店附魔烤进 power", "te-38457")
s = rep(s,
        "check(r210_e0._spell_dmg(GameEngine.SIDE_SELF, 17, r210_spell_up) == 27,",
        "check(r210_e0._spell_dmg(GameEngine.SIDE_SELF, 17, r210_spell_up) == 25,", "te-38458")
s = rep(s,
        "\"R210 附魔：被「伤害 +10」附魔的技能卡 → 同一张卡 17 伤变 %d\"",
        "\"R210 附魔：被「伤害 +8」附魔的技能卡 → 同一张卡 17 伤变 %d\"", "te-38452")
# build_deck 烤数值 + 卡面补标注（当前形态）
s = rep(s,
        '\tRunState.deck_mods = [{"power": 10}, {}]',
        '\tRunState.deck_mods = [{"power": 8}, {}]', "te-38478")
s = rep(s,
        "check(r210_built.size() == 2 and r210_built[0].power == 10",
        "check(r210_built.size() == 2 and r210_built[0].power == 8", "te-38480")
s = rep(s,
        '\tRunState._apply_mod(r210_noted, {"power": 10, "note": "伤害 +10"})',
        '\tRunState._apply_mod(r210_noted, {"power": 8, "note": "伤害 +8"})', "te-38492")
s = rep(s,
        'check("【附魔】伤害 +10" in r210_noted.effect_text,',
        'check("【附魔】伤害 +8" in r210_noted.effect_text,', "te-38494")
s = rep(s,
        "\"R210 附魔：技能卡的卡面文字补上「【附魔】伤害 +10」（%s）\"",
        "\"R210 附魔：技能卡的卡面文字补上「【附魔】伤害 +8」（%s）\"", "te-38496")

# ③ 老存档反推：**故意保留 +10**（R787 之前真实写出的形态）
s = rep(s,
        '\t\t\tand RunState.enchant_id_of({"power": 10, "note": "伤害 +10"}) == "damage"',
        '\t\t\t# ⚠️ 这里**故意**写 R787 之前的 +10：反推只认「有没有增量」，\r\n'
        '\t\t\t#    不认具体数值，老存档必须仍然认成 damage。\r\n'
        '\t\t\tand RunState.enchant_id_of({"power": 10, "note": "伤害 +10"}) == "damage"',
        "te-38884")

# ④ R224/R226 说明性文案
s = rep(s, "伤害 +10 只给技能卡（盟友被拒）", "伤害 +8 只给技能卡（盟友被拒）", "te-20569")
s = rep(s, "R226：伤害 +10 拒绝", "R226：伤害 +8 拒绝", "te-20597")
s = rep(s, "R226：伤害 +10 仍给流星雨", "R226：伤害 +8 仍给流星雨", "te-20637")

# ⑤ R306 / R316 / R317 / R406 说明性文案
s = rep(s, "（可吃「伤害 +10」附魔）", "（可吃「伤害 +8」附魔）", "te-40085")
s = rep(s, "（吃「伤害 +10」附魔），极速不能", "（吃「伤害 +8」附魔），极速不能", "te-53421")
s = rep(s, "（附魔「伤害 +10」走这条路）", "（附魔「伤害 +8」走这条路）", "te-53503")
s = rep(s, "（不吃「伤害 +10」附魔）", "（不吃「伤害 +8」附魔）", "te-53655")
s = rep(s, "（吃「伤害 +10」附魔资格", "（吃「伤害 +8」附魔资格", "te-65195")
s = rep(s, "「伤害 +10」与契约核心共用的消费点", "「伤害 +8」与契约核心共用的消费点", "te-66799")

# ⑥ R348：17 + 8 = 25
s = rep(s,
        "\tr348_fx_card.power = 10      # 附魔「伤害 +10」烤进 power",
        "\tr348_fx_card.power = 8       # 附魔「伤害 +8」烤进 power", "te-56632a")
s = rep(s,
        "check(int(r348_fx.spell_now(r348_fx_card).get(\"dmg\", -1)) == 27,",
        "check(int(r348_fx.spell_now(r348_fx_card).get(\"dmg\", -1)) == 25,", "te-56632b")
s = rep(s,
        "\"R348 固定卡：附魔 +10 → 预览 27 伤\"",
        "\"R348 固定卡：附魔 +8 → 预览 25 伤\"", "te-56632c")

# ⑦ R349：expr 17＋8
s = rep(s,
        "\tr349_fx_card.power = 10",
        "\tr349_fx_card.power = 8", "te-56800a")
s = rep(s,
        "check(int(r349_fn.get(\"base\", -1)) == 17 and str(r349_fn.get(\"expr\", \"\")) == \"17＋10\",",
        "check(int(r349_fn.get(\"base\", -1)) == 17 and str(r349_fn.get(\"expr\", \"\")) == \"17＋8\",",
        "te-56800b")
s = rep(s,
        "\"R349 引擎：火焰箭附魔 → base=17 / expr=17＋10\"",
        "\"R349 引擎：火焰箭附魔 → base=17 / expr=17＋8\"", "te-56800c")

# ⑧ R387：14 + 8 = 22
s = rep(s,
        "\tr387_spell.power = 10   # 商店附魔「技能伤害 +10」：纸面 14 → 24",
        "\tr387_spell.power = 8    # 商店附魔「技能伤害 +8」：纸面 14 → 22", "te-62196a")
s = rep(s,
        "check(r387_tank.health == r387_tank_hp - 24,",
        "check(r387_tank.health == r387_tank_hp - 22,", "te-62196b")
s = rep(s,
        "\"R387 火墙术：附魔 +10 → 即时 24（%d→%d）\"",
        "\"R387 火墙术：附魔 +8 → 即时 22（%d→%d）\"", "te-62196c")

# ⑨ R406 / R580：只断言「有没有确定加成」，数值跟着真源
s = rep(s,
        "\tr406_lone.power = 10      # 附魔「伤害 +10」烤进 power（确定加成）",
        "\tr406_lone.power = 8       # 附魔「伤害 +8」烤进 power（确定加成）", "te-65325")
s = rep(s,
        "哪怕有确定加成（附魔 +10）也不报数",
        "哪怕有确定加成（附魔 +8）也不报数", "te-65327")
s = rep(s,
        "\tr580_fb.power = 10   # 商店附魔「伤害 +10」烤进技能卡的 power（R210 口径）",
        "\tr580_fb.power = 8    # 商店附魔「伤害 +8」烤进技能卡的 power（R210 口径）", "te-72877")

# ⑩ R621 复制术：模拟一张带附魔的盟友
s = rep(s,
        "\t# ④ 复制术 9165：复制场上带「伤害 +10」附魔的盟友 → 复制品回到原攻击力",
        "\t# ④ 复制术 9165：复制场上带「伤害 +8」附魔的盟友 → 复制品回到原攻击力", "te-75499")
s = rep(s,
        "\tr621_dp.power += 10",
        "\tr621_dp.power += 8", "te-75507")
s = rep(s,
        '\tr621_dp.effect_text += "\\n【附魔】伤害 +10"',
        '\tr621_dp.effect_text += "\\n【附魔】伤害 +8"', "te-75513")

bad = s.count("\n") - s.count(EOL)
if bad != 0:
    print("FAIL EOL 裸 LF %d" % bad)
    sys.exit(1)
save(P, s)
print("OK", P)
