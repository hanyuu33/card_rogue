# -*- coding: utf-8 -*-
"""在 暗影刺客_稀有史诗明细_R329.md 末尾追加 R846 小节（LF 文件）。"""
import io

P = "暗影刺客_稀有史诗明细_R329.md"

SEC = """
## R846 平衡调整（2026-11-20）

> 与 R845 同一本账：旧表照旧当历史快照，不回改。本轮动 7 张，其中 3 张是**机制改版**
> （回转 / 闪躲 / 影子猫），另外 4 张是数值或触发补丁。

| id | 卡名 | 项目 | 改前 | 改后 |
|---|---|---|---|---|
| 8006 | 影子猫 | 移速 | 5 | **2** |
| 8006 | 影子猫 | 打出时 | 含本卡本回合第 3 张 → 卡组随机技能卡入手 | **本回合已使用 3 张其他卡 → 抽 2 张** |
| 8019 | 地狱猫 | 初始力量 | 1 | **0**（回合结束 +1 力 / +2 血 的成长规则不变） |
| 9231 | 噩兆 | 使用时 | 无 | **若场上没有标记 → 随机标记一个格子**（回合结束的 4X 伤害不变） |
| 9089 | 回转 | 效果 | 抽 X 张（X = 本回合已用卡牌数） | **对一个目标造成 X 伤 + 抽 X 张**，X = 本回合你已使用**其他**卡的张数；抽到的牌本回合结束仍不弃 |
| 9103 | 闪躲 | 稀有度 | 普通 | **稀有** |
| 9103 | 闪躲 | 效果 | 这个回合，所有友方单位获得嘲讽 | **使一个敌方单位力量 -X**，X = 你本回合打出的牌数 |
| 9190 | 猫鼠游戏 | 费用 | 5 | **4** |
| 9111 | 暗影之刃 | X 的口径 | 本回合已使用的**费用数** | 本回合已使用的**卡牌张数** |

实现要点：

- **影子猫**：`_shadow_cat_trigger()` 的判据从 `self_card_plays + 1 >= 3`（含本卡）改成 `self_card_plays >= 3`（**其他**卡）—— 这个钩子在 `_play_from_hand_body` 里跑，**先于** `_note_card_played()`，计数器天然不含它自己。抽牌走 `_draw_many(2)`；组合下半句从 `fetch_skill + if_third` 换成新动作 **`draw_if_third`**（`card_data.ASSEMBLE_EFFECT_TYPES` / `assemble_rules.valid_effect` / `effect_text` / 引擎 `_assemble_apply_fx` 四处齐改）。
- **噩兆**：直接复用致命 9226 / 恐惧化身 9230 的 `_auto_mark_if_none(why, any_cell)`，传 `any_cell = true`（候选整块棋盘，排除己方 HP 行，与致命同口径）；已有标记时什么都不做。
- **回转**：`target_mode` 改 `unit`；先 `_op_deal_damage` 再抽牌，抽到的仍进 `state.turn_keep`。左栏不报数（未进 `SPELL_BASE_DMG`，卡面写的是 X）。
- **闪躲**：`_dodge_spell(side, card, target)` 重写；**R48~R845 的「全员嘲讽窗口」整条删除**（`_taunt_all_active` 字段、`taunt_all_active()`、`unit_has_taunt()` 里的第二个来源、费用面板与状态槽的联动、HUD 的 dodge 参数一起清掉）。降力与敲晕同源（`atk_debuff` + `debuff_stage = 1`），可叠加。X 读 `self_card_plays`，**自身不计入**（与终结 9086 同口径）。可选目标格只列敌方单位。
- **暗影之刃**：X 从 `energy_spent_of()` 改读 `*_card_plays`；回合结束结算，所以本回合打过的每一张都在内。与「花没花钱」彻底脱钩 —— 「剩 5 费一分没花也照样打 2 张卡的伤害」。
- **地狱猫 / 猫鼠游戏**：纯数据（`power` 1→0 / `cost` 5→4），引擎一行未动。
- 伤害判据 `is_damage_spell()`：回转的新文案含「造成…伤害」→ 自动进判据，玩家伤害技能 48 → **49**；闪躲仍不含「造成」二字 → 技能数 117 不变。
"""


def main():
    s = io.open(P, "r", encoding="utf-8", newline="").read()
    assert "## R846 平衡调整" not in s, "已追加过"
    if not s.endswith("\n"):
        s += "\n"
    s += SEC
    io.open(P, "w", encoding="utf-8", newline="").write(s)
    d = open(P, "rb").read()
    print("CRLF", d.count(b"\r\n"), "LF", d.count(b"\n"))


if __name__ == "__main__":
    main()
