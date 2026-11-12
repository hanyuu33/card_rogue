# -*- coding: utf-8 -*-
"""R589 组装素材扩展 —— 第一批：扳机 + 动作地基（assemble_rules.gd / card_data.gd）。

用法：
    python tools/_patch_r589.py --check-only   # 只校验锚点，不写文件
    python tools/_patch_r589.py                # 打补丁 + 语法校验提示
可重跑：每处替换都带 count==1 断言，重复执行会立刻报「锚点已被改过」。
"""
import io
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECK = "--check-only" in sys.argv


def read(rel):
    with io.open(os.path.join(ROOT, rel), "r", encoding="utf-8", newline="") as f:
        return f.read()


def write(rel, text):
    with io.open(os.path.join(ROOT, rel), "w", encoding="utf-8", newline="") as f:
        f.write(text)


PATCHES = []


def patch(rel, old, new, note):
    PATCHES.append((rel, old, new, note))


# ══════════════════════════════════════════════════════════════════════════
# ① assemble_rules.gd —— 三条新扳机
# ══════════════════════════════════════════════════════════════════════════
patch("scripts/assemble_rules.gd",
      '''const TRIGGERS := ["use", "enter", "death", "upgraded", "turn_end", "turn_start",
\t"attack", "attacked", "damaged", "effect_played", "turn_first_play", "after_draw", "action_end"]''',
      '''## R589：三条新扳机 ——
##   · `use_after`「使用后」：母卡原文写「使用后」的那批（小精灵 9074 / 巨鼠 9046 /
##     乌鸦 9039 / 斑鸠 9052）。结算时机与 `use` 同处（打出结算完立刻），区别只在卡面文案 ——
##     所以引擎里两者走**同一个分发点**，不另开一条时序（另开会变成「说使用后、实际使用时」）。
##   · `active`「主动发动」：玩家点单位、花掉这次行动（之后横置），每单位在场只能发动一次。
##     规则句见 `TRIGGER_RULES`，与 `can_activate` / `activate` 的实现在同一条口径上。
##   · `lethal`「每次生命降到 0 或更低」：**跨越**判定（扣血前 > 0 且扣血后 <= 0）。
##     超负荷让单位负血留在场上，按「处于」判会每挨一下都再触发一次（忒修斯 9222 的老坑）。
const TRIGGERS := ["use", "use_after", "enter", "death", "upgraded", "turn_end", "turn_start",
\t"attack", "attacked", "damaged", "effect_played", "turn_first_play", "after_draw", "action_end",
\t"active", "lethal"]''',
      "TRIGGERS 加 use_after / active / lethal")

patch("scripts/assemble_rules.gd",
      '''"after_draw": "抽牌后", "action_end": "行动结束时"}''',
      '''"after_draw": "抽牌后", "action_end": "行动结束时",
\t"use_after": "使用后", "active": "主动发动", "lethal": "每次生命降到 0 或更低"}
## R589：带**固有规则**的扳机 —— 规则句印在效果后面，且和结算同源：
## `active` 的「之后横置 / 在场只能发动一次」就是 `can_activate` + `activate` 的实现口径。
## 别在卡面另写一份（写了就会和引擎漂移：卡面说只能一次、实际能按两次）。
const TRIGGER_RULES := {"active": "，之后横置。在场只能发动一次。"}''',
      "LABELS 加三条 + TRIGGER_RULES")

# ② 无 value 的动作（取一张，没有数值分量）
patch("scripts/assemble_rules.gd",
      '''\tif fx.type in ["shield", "taunt", "freeze", "stun", "absorb_linked"]:
\t\treturn true''',
      '''\tif fx.type in ["shield", "taunt", "freeze", "stun", "absorb_linked",
\t\t\t"fetch_cheapest_ally", "recall_ally_from_discard"]:
\t\treturn true''',
      "无 value 动作白名单")

# ③ add_effect_from_deck：value + discount 两分量
patch("scripts/assemble_rules.gd",
      '''\t\treturn int(ad_id) > 0 and int(fx.value) >= 1''',
      '''\t\treturn int(ad_id) > 0 and int(fx.value) >= 1
\t# R589：水元素 9068「从卡组将一张效果卡加入手卡，费用减少 N」。
\t# 两个分量都要查：0 张 = 空动作；discount 缺省 0 是合法的（只取牌不减费）。
\tif fx.type == "add_effect_from_deck":
\t\tif not fx.get("value") is int and not fx.get("value") is float:
\t\t\treturn false
\t\tvar aed_d: Variant = fx.get("discount", 0)
\t\tif not aed_d is int and not aed_d is float:
\t\t\treturn false
\t\treturn int(fx.value) >= 1 and int(aed_d) >= 0''',
      "add_effect_from_deck 校验")

# ④ 数值 >= 1 的动作组
patch("scripts/assemble_rules.gd",
      '''\tif fx.type in ["add_random_effect", "hand_discount", "hand_upgrade",
\t\t\t"buff_per_ally", "heal_per_energy", "draw_random_skill",
\t\t\t"hand_cost_raise", "add_copy", "buff_allies_atk"]:
\t\treturn int(fx.value) >= 1''',
      '''\tif fx.type in ["add_random_effect", "hand_discount", "hand_upgrade",
\t\t\t"buff_per_ally", "heal_per_energy", "draw_random_skill",
\t\t\t"hand_cost_raise", "add_copy", "buff_allies_atk",
\t\t\t# R589：减 0 费 / 每张 +0 生命同样是空动作。
\t\t\t"next_effect_discount", "next_ally_discount",
\t\t\t"hand_skill_discount", "hp_per_zero_skill"]:
\t\treturn int(fx.value) >= 1''',
      "数值 >=1 动作组扩表")

# ⑤ effect_text 文案
patch("scripts/assemble_rules.gd",
      '''\t\t"add_card_to_deck": return "将%d张「%s」加入抽牌库" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]''',
      '''\t\t"add_card_to_deck": return "将%d张「%s」加入抽牌库" % [maxi(1, n), card_label(int(fx.get("card_id", 0)))]
\t\t# ── R589：七条「母卡已有实现」的动作。文案逐字对着原卡 effect_text 写，
\t\t#    `test_assemble._fx_in_text()` 有保真锁 —— 改这里必须连判据一起改。
\t\t#    小精灵 9074：「使用后，你使用的下一张效果卡费用减少 2」
\t\t"next_effect_discount": return "你使用的下一张效果卡费用减少 %d" % n
\t\t# 斑鸠 9052：「使用后，本回合使用下一个盟友时，费用 -1」
\t\t"next_ally_discount": return "本回合使用下一个盟友时，费用 -%d" % n
\t\t# 水元素 9068：「使用时，从卡组将一张效果卡加入手卡，费用减少 2」
\t\t"add_effect_from_deck": return "从卡组将%d张效果卡加入手卡，费用减少 %d" % [
\t\t\t\tmaxi(1, n), int(fx.get("discount", 0))]
\t\t# 影魔 8007 前半：「手卡中所有技能牌本回合费用 -1」
\t\t"hand_skill_discount": return "手卡中所有技能牌本回合费用 -%d" % n
\t\t# 影魔 8007 后半：「手卡每有一张费用为 0 的技能卡，这张卡获得 +3 生命」
\t\t"hp_per_zero_skill": return "手卡每有一张费用为 0 的技能卡，这张卡获得 +%d 生命" % n
\t\t# 巨鼠 9046：「使用后从抽牌库将一张费用最低的盟友加入手卡」
\t\t"fetch_cheapest_ally": return "从抽牌库将一张费用最低的盟友加入手卡"
\t\t# 乌鸦 9039：「使用后选择弃牌堆中一张盟友回到手卡」
\t\t"recall_ally_from_discard": return "选择弃牌堆中一张盟友回到手卡"''',
      "effect_text 七条文案")

# ⑥ 产物文本带上扳机固有规则
patch("scripts/assemble_rules.gd",
      '''\tvar one := str(LABELS.get(t, "")) + "：" + out''',
      '''\t# R589：扳机的固有规则句（目前只有 `active`）跟着产物一起印 —— 卡面写了才敢这么结算。
\tvar one := str(LABELS.get(t, "")) + "：" + out + str(TRIGGER_RULES.get(t, ""))''',
      "assembled_text 追加规则句")

# ⑦ card_data.gd：历史识别表
patch("scripts/card_data.gd",
      '''\t"effect_played", "turn_first_play", "random_gained", "after_draw", "action_end",
]''',
      '''\t"effect_played", "turn_first_play", "random_gained", "after_draw", "action_end",
\t# R589：主动发动 / 使用后 / 生命降到 0 或更低。
\t"active", "use_after", "lethal",
]''',
      "ASSEMBLE_TRIGGERS 同步")


def main():
    ok = True
    files = {}
    for rel, old, new, note in PATCHES:
        if rel not in files:
            files[rel] = read(rel)
        cnt = files[rel].count(old)
        use_old, use_new = old, new
        # card_data.gd 等文件是 CRLF：锚点按 LF 写，命中不到就换 CRLF 再试一次。
        # 写回时同样转成 CRLF，避免把整文件行尾洗成 LF。
        if cnt == 0:
            crlf_old = old.replace("\n", "\r\n")
            if files[rel].count(crlf_old) == 1:
                use_old, use_new = crlf_old, new.replace("\n", "\r\n")
                cnt = 1
        if cnt != 1:
            print("[FAIL] %s：锚点命中 %d 次（要求 1）—— %s" % (rel, cnt, note))
            ok = False
            continue
        files[rel] = files[rel].replace(use_old, use_new, 1)
        print("[ok] %s：%s" % (rel, note))
    if not ok:
        print("\n有锚点没命中，未写任何文件。")
        return 1
    if CHECK:
        print("\n--check-only：锚点全中，未写文件。")
        return 0
    for rel, text in files.items():
        write(rel, text)
        print("[write] %s" % rel)
    return 0


if __name__ == "__main__":
    sys.exit(main())
