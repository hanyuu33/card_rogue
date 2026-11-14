# -*- coding: utf-8 -*-
"""卡牌实例身份体检（R737）

背景：`state.card_discount` / `turn_card_discount` / `hand_free` / `hand_cost_delta` /
`hand_cost_turn` / `curse_raise` 全部以 **CardData 对象**为键。而 `FieldState.draw()` 会在
抽牌时把「还没独立化」的卡复制成新对象（`own_copy = true`）。于是只要某条路径把
「牌库 / 弃牌区里的共享实例」直接塞进手牌（绕开 draw），就会出现两种沉默故障：

  ① 共享实例直接进手 → 给它减费等于给所有同名卡减费（R281）；
  ② 它身上的永久减费在「弃回牌库 → 再抽到」后换了个对象 → 旧键查不到 → 减费清零。

所以规矩是：**任何进入手牌的 CardData 都必须先过 `_own_card()` / `_new_own_card()`
（或已 explicit 设 `own_copy`）**。本脚本把违反这条的函数列出来。

用法：
    python tools/check_card_own_copy.py          # 只看高危项（从牌库/弃牌区取卡）
    python tools/check_card_own_copy.py --all    # 连「进手但没独立化」一起看
"""
import re
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = ["scripts/game_engine.gd"]

# 合法例外：函数名 -> 理由（硬编码，加一条就说明「这里不复制是对的」）
ALLOW = {
    "_grant_to_hand": "本身是投递口，独立化由调用方负责（见文件内注释）",
    "_instinct_cast": "临时借道手牌去 use_spell，卡是牌库那张、用完即离手",
    "_cast_generated_spell": "临时借道手牌去正常结算，卡是组合产物、用完即离手",
    "_fort_play": "同上：凭空技能卡临时借道手牌去正常结算，用完即离手",
    "use_spell": "回响 9102 用后返回手卡，card 就是刚打出的那张（早就是独立实例）",
    "_destroy": "思想钢印回手的是场上那张（场上卡从不与牌库共享）",
    "play_from_hand": "交换把顶回的是场上单位卡（同上）",
}


def split_funcs(lines):
    funcs = []
    cur = None
    for i, ln in enumerate(lines):
        m = re.match(r"^func\s+([A-Za-z0-9_]+)", ln)
        if m:
            if cur:
                funcs.append(cur)
            cur = {"name": m.group(1), "line": i + 1, "lines": []}
        elif cur is not None:
            cur["lines"].append((i + 1, ln))
    if cur:
        funcs.append(cur)
    return funcs


def main():
    show_all = "--all" in sys.argv
    bad_high = []
    bad_low = []
    for rel in TARGETS:
        path = os.path.join(ROOT, rel)
        lines = open(path, encoding="utf-8", errors="replace").read().split("\n")
        for f in split_funcs(lines):
            body = "\n".join(x[1] for x in f["lines"])
            writes_hand = [x for x in f["lines"]
                           if "state.hand.append(" in x[1]
                           or "_grant_to_hand(" in x[1]
                           or re.search(r"state\.hand\[[^\]]*\]\s*=(?!=)", x[1])]
            if not writes_hand:
                continue
            fenced = ("_own_card(" in body or "_new_own_card(" in body
                      or "own_copy" in body
                      or "_migrate_card_state(" in body
                      or "_renew_field_card(" in body)
            if fenced:
                continue
            takes = ("state.deck[" in body or "state.discard[" in body)
            item = (rel, f["name"], f["line"], writes_hand[0][0], writes_hand[0][1].strip(),
                    ALLOW.get(f["name"], ""))
            if takes:
                bad_high.append(item)
            else:
                bad_low.append(item)

    def dump(title, items):
        print("=" * 60)
        print(title, "(%d)" % len(items))
        for rel, name, fl, wl, wline, why in items:
            print("  %s:%d  func %s()   写入手牌 @%d: %s" % (rel, fl, name, wl, wline))
            if why:
                print("      ⚠ 白名单理由：%s" % why)
            else:
                print("      ⚠ 未豁免 —— 请改走 _own_card() / _new_own_card()")

    dump("高危：从牌库 / 弃牌区取卡进手，却没独立化", bad_high)
    if show_all:
        dump("提示：其余「凭空造卡进手」但没打 own_copy", bad_low)

    hard = [x for x in bad_high if not x[5]]
    if hard:
        print("\n结论：有 %d 处高危未处理。" % len(hard))
        return 1
    print("\n结论：高危项已清零（白名单 %d 条）。" % len([x for x in bad_high if x[5]]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
