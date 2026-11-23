# -*- coding: utf-8 -*-
"""R812b：海妖鱼叉 6083 —— ① 自己追加的那一笔**不进计数**；② 追加伤害 6 → 4。

① 其实 `_harpoon_busy` 已经拦着了（追加走 `_hit_unit` → 又调 `_harpoon_tick` → 见到 busy 直接退），
   但**老测试分辨不出来**：3 次命中 + 两次追加 = 6 点基础 + 12 点追加 = 18，
   「追加算不算一次」两种口径的总伤害都是 18。所以这轮补一条直接读 `harpoon_hits` 的断言，
   把「追加不计数」真正锁住，而不是靠总伤害间接猜。
② 追加伤害 6 → 4：只改常量 `HARPOON_DMG`，所有读它的地方（引擎 / 演出 / 文本）自动跟。
"""
import io

ROOT = "E:/work/card_rogue/"


def read(rel):
    return io.open(ROOT + rel, encoding="utf-8", newline="").read()


def write(rel, text):
    io.open(ROOT + rel, "w", encoding="utf-8", newline="").write(text)


def sub(text, old, new, tag):
    n = text.count(old)
    assert n == 1, "[%s] 锚点命中 %d 次（应为 1）" % (tag, n)
    return text.replace(old, new)


# ─────────────────────────── ① 引擎：数值 + 口径注释 ───────────────────────────
p = "scripts/game_engine.gd"
s = read(p)
s = sub(s, "const HARPOON_DMG:= 6\r\n", "const HARPOON_DMG:= 4\r\n", "dmg")
s = sub(s,
        "\t## ⚠️ `_harpoon_busy`：自己补的那 6 点不许再算一次计数，否则会自我滚雪球。\r\n",
        "\t## ⚠️ `_harpoon_busy`：**自己追加的那一笔不进计数**（R812 口径）。追加伤害也走\r\n"
        "\t##    `_hit_unit` → 又会调回本函数，见到 busy 立刻退 —— 否则第 3 次命中补完又算第 4 次，\r\n"
        "\t##    等于自我滚雪球（而且玩家根本看不出是自己滚出来的）。\r\n",
        "busy_doc")
write(p, s)

# ─────────────────────────── ② 演出注释 ───────────────────────────
p = "scripts/battle_scene.gd"
s = read(p)
s = sub(s,
        "\t\t\t# R810 海妖鱼叉（6083）：同一回合第 3 次命中同一敌人 → 追加 6 点。\r\n"
        "\t\t\t# 这一下是**追加伤害**，`fx_impact` 可能被「同格 700ms 只演一次」吞掉，\r\n"
        "\t\t\t# 所以这里单独给一次更重的爆点 + 自己的飘字，保证「追加的那 6 点」看得见。\r\n",
        "\t\t\t# R810 海妖鱼叉（6083）：同一回合第 3 次命中同一敌人 → 追加 HARPOON_DMG 点\r\n"
        "\t\t\t# （R812 起为 4 点，且这一笔**不进自身的命中计数**）。\r\n"
        "\t\t\t# 这一下是**追加伤害**，`fx_impact` 可能被「同格 700ms 只演一次」吞掉，\r\n"
        "\t\t\t# 所以这里单独给一次更重的爆点 + 自己的飘字，保证「追加的那一下」看得见。\r\n",
        "fx_doc")
write(p, s)

# ─────────────────────────── ③ 描述：五处 6 → 4 ───────────────────────────
DESCS = [
    ("relics.json",
     "同一回合内，每对一个敌人造成 3 次伤害，对其造成 6 点伤害。",
     "同一回合内，每对一个敌人造成 3 次伤害，对其造成 4 点伤害。"),
    ("i18n/noncard_zh_canonical.json",
     "同一回合内，每对一个敌人造成 3 次伤害，对其造成 6 点伤害。",
     "同一回合内，每对一个敌人造成 3 次伤害，对其造成 4 点伤害。"),
    ("i18n/noncard_en.json",
     "Within the same turn, every 3rd time you deal damage to an enemy, deal 6 damage to it.",
     "Within the same turn, every 3rd time you deal damage to an enemy, deal 4 damage to it."),
    ("i18n/noncard_ja.json",
     "同じターン中、1 体の敵に 3 回ダメージを与えるたび、その敵に 6 ダメージを与える。",
     "同じターン中、1 体の敵に 3 回ダメージを与えるたび、その敵に 4 ダメージを与える。"),
    ("i18n/noncard_es.json",
     "Dentro del mismo turno, cada 3.ª vez que infliges daño a un enemigo, le infliges 6 de daño.",
     "Dentro del mismo turno, cada 3.ª vez que infliges daño a un enemigo, le infliges 4 de daño."),
]
for rel, old, new in DESCS:
    s = read(rel)
    s = sub(s, old, new, rel)
    write(rel, s)

# ─────────────────────────── ④ 测试 ───────────────────────────
p = "scripts/test_engine.gd"
s = read(p)

s = sub(s,
        "6083: [\"海妖鱼叉\", \"一般\", \"同一回合内，每对一个敌人造成 3 次伤害，对其造成 6 点伤害。\"],",
        "6083: [\"海妖鱼叉\", \"一般\", \"同一回合内，每对一个敌人造成 3 次伤害，对其造成 4 点伤害。\"],",
        "desclock")

s = sub(s,
        "\t##   海妖鱼叉 6083（一般）：同一回合内同一个敌人每挨 3 次伤害 → 追加 6 点；\r\n",
        "\t##   海妖鱼叉 6083（一般）：同一回合内同一个敌人每挨 3 次伤害 → 追加 4 点；\r\n",
        "headdoc")

s = sub(s,
        "\t# ── ④ 海妖鱼叉：同一回合内同一个敌人每 3 次伤害 → 追加 6 ──\r\n",
        "\t# ── ④ 海妖鱼叉：同一回合内同一个敌人每 3 次伤害 → 追加 4（R812 由 6 下调）──\r\n",
        "secdoc")

s = sub(s,
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tcheck(r810_p5.health == r810_h5 - 3 - 6,\r\n"
        "\t\t\t\"R810 海妖鱼叉：第 3 次 → 1 点 + 追加 6 点（累计 %d）\"\r\n"
        "\t\t\t% (r810_h5 - r810_p5.health))\r\n"
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tcheck(r810_p5.health == r810_h5 - 6 - 12,\r\n"
        "\t\t\t\"R810 海妖鱼叉：第 6 次再追加一次（累计 %d）\" % (r810_h5 - r810_p5.health))\r\n",
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tcheck(r810_p5.health == r810_h5 - 3 - 4,\r\n"
        "\t\t\t\"R812 海妖鱼叉：第 3 次 → 1 点 + 追加 4 点（累计 %d）\"\r\n"
        "\t\t\t% (r810_h5 - r810_p5.health))\r\n"
        "\t# ⚠️ 关键断言：追加的那一笔**不许把自己算成第 4 次命中**。\r\n"
        "\t# 老测试只比总伤害，分辨不出这件事 —— 两种口径的总数都是 18（6 基础 + 6×2 追加）。\r\n"
        "\tcheck(r810_p5.harpoon_hits == 3,\r\n"
        "\t\t\t\"R812 海妖鱼叉：追加伤害不进计数（第 3 次命中后仍是 3，实际 %d）\"\r\n"
        "\t\t\t% r810_p5.harpoon_hits)\r\n"
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tr810_e5._hit_unit(r810_p5, 1, \"测试\")\r\n"
        "\tcheck(r810_p5.health == r810_h5 - 6 - 8,\r\n"
        "\t\t\t\"R812 海妖鱼叉：第 6 次再追加一次（累计 %d）\" % (r810_h5 - r810_p5.health))\r\n"
        "\tcheck(r810_p5.harpoon_hits == 6,\r\n"
        "\t\t\t\"R812 海妖鱼叉：两次追加都没混进计数（6 次命中 = 6，实际 %d）\"\r\n"
        "\t\t\t% r810_p5.harpoon_hits)\r\n",
        "tests")
write(p, s)

print("R812b patch OK")
