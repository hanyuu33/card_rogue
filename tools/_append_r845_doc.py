# -*- coding: utf-8 -*-
"""在 暗影刺客_稀有史诗明细_R329.md 末尾追加 R845 平衡调整小节（LF 文件）。"""
import io

P = "暗影刺客_稀有史诗明细_R329.md"

SEC = """
## R845 平衡调整（2026-11-20）

> 上表是 R329 的历史快照，本节单独记账，不回改旧表。本轮共动 11 张暗影刺客卡。
> 全语种文本（中 / en / ja / es）与 `zh_canonical.json` 已同步；`zh_canonical.json` 只改文本，未动 `updated` / `changed_count`。

| id | 卡名 | 项目 | 改前 | 改后 |
|---|---|---|---|---|
| 8066 | 负重减轻 | 稀有度 | 史诗 | **稀有** |
| 9088 | 敲晕 | 伤害 | 3 | **2** |
| 9233 | 灵魂收割者 | 击杀效果 | 回复到生命上限 | **回复 2 点费用并抽 2 张牌** |
| 9087 | 连刺 | 伤害 | 4 | **5** |
| 9119 | 起手式 | 伤害 | 4 | **5** |
| 9090 | 偷袭 | 伤害 | 5 / 满血 12 | **4 / 满血 10** |
| 9173 | 身法 | 抽牌 | 5 | **4** |
| 9121 | 暗影步 | 伤害 | 8 | **13** |
| 9091 | 疾风 | 效果 | 每使用一张卡，随机对一个敌人造成 2 点伤害 | **同一个回合内每使用 3 张卡，对一个随机敌人造成 8 点伤害，并使其力量 -1。效果区多张本卡不可叠加** |
| 9176 | 本能 | 种类 / 费用 / 效果 | 技能；打开面板选一个减伤选项 | **2 费效果卡：接下来一次你受到的大于 1 的伤害变为 1，然后抽 2 张牌** |
| 8062 | 夜蚀 | 效果 | 回合结束按剩余费用回复生命 | **回合结束对所有敌人造成 X 点伤害，X = 自己剩余费用** |

实现要点：

- **疾风**：`_gale_tick()` 改读 `self_card_plays` / `opp_card_plays`，`plays % GALE_NEED == 0` 时触发（含本卡，第 3 / 6 / 9 张）；`_zone_has_id()` 判存在即可，「不可叠加」= 两张同名只触发一次。
- **本能**：不再是技能 → `_instinct_panel_open()` / `_instinct_cast()` 整段删除，改为 `_damage_player()` 内、`_hp_damage_taken()` 之后调用 `_instinct_absorb()`；伤害 ≤1 不消耗。
- **夜蚀**：`_night_erosion_heal()` 删除，改 `_night_erosion_strike()`；先收集再结算，避免遍历中改 `board`。组合枝 `heal_per_energy` → `damage_per_energy`（`assemble_rules.gd` / `card_data.gd` 白名单同步）。
- **灵魂收割者**：抽牌只给玩家侧（AI 只拿费用），与起手式一致。
- 技能计数：暗影刺客技能 118 → **117**（本能转效果卡），伤害技能数 48 不变。
"""

with io.open(P, "r", encoding="utf-8", newline="") as f:
    s = f.read()

assert "## R845 平衡调整" not in s, "已追加过"
if not s.endswith("\n"):
    s += "\n"
s += SEC

with io.open(P, "w", encoding="utf-8", newline="") as f:
    f.write(s)

d = open(P, "rb").read()
print("CRLF", d.count(b"\r\n"), "LF", d.count(b"\n"), "尾部", repr(d[-40:]))
