# -*- coding: utf-8 -*-
"""R794b：从 HEAD 版 run_state.gd 重建「只含本轮商店涨价改动」的干净副本。

工作区那份 run_state.gd 里混着并行线的 **兔脚 6076** 三处改动（常量块 /
roll_battle_tool_drop / rabbit_foot_gold），提交时必须把它们留在工作区、不进这一笔。

产出：
  E:/tmp/r794b_run_state_clean.gd   —— 干净副本
  并打印它和工作区版本的 diff（应当正好是兔脚的 3 个 hunk）
"""
import io, subprocess, sys

ROOT = "E:/work/card_rogue/"
CLEAN = "E:/tmp/r794b_run_state_clean.gd"

base = subprocess.run(["git", "-C", ROOT, "show", "HEAD:scripts/run_state.gd"],
                      capture_output=True, check=True).stdout.decode("utf-8")
s = base

pairs = [
    # 1) 注释块
    (
        "# 档位只在角色选择界面改，不属于 run 状态（end_run / start_run 都不动它）。\n",
        "#   11 = 第三层上锁（R543）：要凑齐完美螺钉 / 生命之种 / 屠戮匕首三样信物才开门。\n"
        "#   12 = 昂贵（R794b）：商店商品售价 +40%，**信物除外**（信物 = 上面那三把钥匙）。\n"
        "# 档位只在角色选择界面改，不属于 run 状态（end_run / start_run 都不动它）。\n",
        "注释块",
    ),
    # 2) COUNT
    ("const DIFFICULTY_COUNT := 12", "const DIFFICULTY_COUNT := 13", "COUNT"),
    # 3) NAMES
    (
        '\t\t"疲惫", "凶暴", "贫瘠", "匆忙", "虚弱", "噩梦", "上锁"]',
        '\t\t"疲惫", "凶暴", "贫瘠", "匆忙", "虚弱", "噩梦", "上锁", "昂贵"]',
        "NAMES",
    ),
    # 4) TEXTS
    (
        '\t"第三层上锁，获取三个信物以解锁第三层",\n]',
        '\t"第三层上锁，获取三个信物以解锁第三层",\n'
        '\t"商店商品售价 +40%（信物除外）",\n]',
        "TEXTS",
    ),
    # 5) BATTLE_HEAL
    (
        "const DIFFICULTY_BATTLE_HEAL: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  # 战斗胜利回复量",
        "const DIFFICULTY_BATTLE_HEAL: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]  # 战斗胜利回复量",
        "BATTLE_HEAL",
    ),
    # 6) REST_PCT
    (
        "const DIFFICULTY_REST_PCT: Array[float] = [0.40, 0.25, 0.25, 0.25, 0.25, 0.25,\n"
        "\t\t0.25, 0.25, 0.25, 0.25, 0.25, 0.25]                                   # 休息回复百分比",
        "const DIFFICULTY_REST_PCT: Array[float] = [0.40, 0.25, 0.25, 0.25, 0.25, 0.25,\n"
        "\t\t0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25]                             # 休息回复百分比",
        "REST_PCT",
    ),
    # 7) 新常量
    (
        "const KEY_RELIC_IDS: Array[int] = [SCREW_RELIC_ID, SEED_RELIC_ID, DAGGER_RELIC_ID]\n",
        "const KEY_RELIC_IDS: Array[int] = [SCREW_RELIC_ID, SEED_RELIC_ID, DAGGER_RELIC_ID]\n"
        "## R794b（用户口径）：难度 12「昂贵」—— 商店里卖的东西一律 +40%，**信物除外**。\n"
        "## ⚠️ 唯一消费点 = `shop_scene._shelf_price()`：价签 / 悬停详情 / 扣款 / 遥测\n"
        "##    四个口共用一个倍率，谁都不许自己乘 1.4。\n"
        "##    信物目前只有第三行那条「屠戮匕首」—— 由调用方传 `key_relic = true` 跳过加价。\n"
        "const DIFF_SHOP_PRICE_FROM := 12   # 12 档起「商店涨价」\n"
        "const DIFF_SHOP_PRICE_MUL := 1.4   # +40%\n",
        "新常量",
    ),
    # 8) summary
    (
        '\tif d >= DIFF_ELITE_FROM:\n\t\tbits.append("精英 ×%.1f" % elite_weight_mul())\n',
        '\tif d >= DIFF_ELITE_FROM:\n\t\tbits.append("精英 ×%.1f" % elite_weight_mul())\n'
        '\tif d >= DIFF_SHOP_PRICE_FROM:\n\t\tbits.append("商店 ×%.1f" % shop_price_mul())\n',
        "summary",
    ),
    # 9) shop_price_mul
    (
        '\treturn " · ".join(bits)\n',
        '\treturn " · ".join(bits)\n'
        "\n"
        "\n"
        "static func shop_price_mul(is_key_relic := false) -> float:\n"
        "\t## R794b：商店成交价的难度倍率（**唯一判据**）。\n"
        "\t## 信物（`KEY_RELIC_IDS`）恒不打折也不加价 → 跟「+40%」这条 debuff 无关；\n"
        "\t## 其余商品在难度 ≥12 时 ×1.4，低难度恒 1.0。\n"
        "\t## ⚠️ 别在 `shop_scene` 里另写一份 `if difficulty >= 12` —— 档位口径只许有这一处。\n"
        "\tif is_key_relic:\n"
        "\t\treturn 1.0\n"
        "\treturn DIFF_SHOP_PRICE_MUL if _diff() >= DIFF_SHOP_PRICE_FROM else 1.0\n",
        "shop_price_mul",
    ),
]

for old, new, tag in pairs:
    n = s.count(old)
    if n != 1:
        print("!! %s 命中 %d 次" % (tag, n))
        sys.exit(1)
    s = s.replace(old, new, 1)

io.open(CLEAN, "wb").write(s.encode("utf-8"))
print("write %s  (%d 行)" % (CLEAN, s.count("\n")))

# 与工作区版本比：差异应当**只剩**兔脚那三处
live = io.open(ROOT + "scripts/run_state.gd", "rb").read().decode("utf-8")
print("--- 干净版 vs 工作区（应只有兔脚 3 个 hunk）---")
subprocess.run(["git", "-C", ROOT, "diff", "--no-index", "--stat",
                CLEAN, ROOT + "scripts/run_state.gd"])
