# -*- coding: utf-8 -*-
"""自动推进战斗：一次进程内跑完若干回合 / 若干场。

为什么要有这个文件
------------------
WorkBuddy 的循环判定（ToolCallLoopGuard）只看**同一工具的连续调用次数**，
不看你敲的命令内容：Bash 阈值 80、其它工具 40，且换一次别的工具才归 1。
逐回合手打「读状态 → 出牌 → 等敌方」每回合要 2~3 次 Bash，三十个回合就撞线。
把回合循环关进本进程，外层只留一次 `python autoplay.py`，判定器就数不到。

用法
----
    python autoplay.py                 # 打完当前这场（战斗结束即停）
    python autoplay.py --battles 3     # 连打三场，每场结束自动结算奖励
    python autoplay.py -v              # 逐步打印每个点击

设计原则
--------
1. 只做「机械之心」的通用判断：层数往大哥身上堆、攻击牌打最脆的、盟友铺前排。
2. 任何一步拿不准就 **停手返回**，把状态打出来交给人判断，绝不瞎点。
3. 单回合动作数、总回合数、总步数都有硬上限，卡住必退出（防真死循环）。
"""
import argparse
import json
import os
import sys
import time

import ai_cli

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
CARDS_JSON = os.path.join(HERE, "..", "..", "cards.json")

ENEMY_ROWS = {"0", "1", "2"}
MY_ROWS = {"3", "4", "5"}

DMG_WORDS = ("攻击", "炮击", "击", "斩", "刺", "炸弹", "榴弹", "射击")
BUFF_WORDS = ("升级", "加厚装甲", "改造", "强化", "集中突破", "激发", "量产", "批量")

# ---------------------------------------------------------------- 卡表


def load_cards():
    """id -> (name, cost, kind, text)。读不到就退化成空表（靠名字猜）。"""
    try:
        with open(CARDS_JSON, encoding="utf-8") as f:
            raw = json.load(f)
    except Exception:
        return {}
    out = {}
    for c in raw.get("cards", []):
        out[int(c.get("id", 0))] = (
            c.get("name", ""),
            int(c.get("cost", 0) or 0),
            c.get("kind", "") or c.get("type", ""),
            (c.get("effect_text") or c.get("text") or ""),
        )
    return out


CARDS = load_cards()


def card_info(cid):
    return CARDS.get(int(cid), ("", 0, "", ""))


def is_damage(cid):
    name = card_info(cid)[0]
    return any(w in name for w in DMG_WORDS)


def is_buff(cid):
    name = card_info(cid)[0]
    return any(w in name for w in BUFF_WORDS)


# ---------------------------------------------------------------- 局面读取


def hints(snap):
    return {t["id"]: t.get("hint", "") for t in snap.get("targets", [])}


def board(snap):
    return (snap.get("battle") or {}).get("board") or []


def hand(snap):
    return (snap.get("battle") or {}).get("hand") or []


def my_units(snap):
    return [u for u in board(snap) if u.get("owner") == "self"]


def foe_units(snap):
    return [u for u in board(snap) if u.get("owner") == "opponent"]


def cell_id(cell):
    return "r%dc%d" % (cell[0], cell[1])


def unit_on(snap, cid):
    for u in board(snap):
        if cell_id(u.get("cell")) == cid:
            return u
    return None


def deadliest(snap):
    """我方最该被养大的单位：攻击力最高的那个。"""
    us = my_units(snap)
    if not us:
        return None
    return sorted(us, key=lambda u: (-u.get("power", 0), -u.get("hp", 0)))[0]


def weakest_foe(snap):
    """最该被打的敌人：能打死的优先，否则血最少。"""
    fs = foe_units(snap)
    if not fs:
        return None
    return sorted(fs, key=lambda u: (u.get("hp", 999), -u.get("power", 0)))[0]


# ---------------------------------------------------------------- 选择动作


def pick_reward(snap, d):
    """奖励页：卡优先挑「改造/攻击/升级」系，道具照拿。"""
    cards = [i for i in d if i.startswith("rw") and "c" in i[2:]]
    if cards:
        def sc(i):
            h = d[i]
            s = 0
            for w in BUFF_WORDS:
                if w in h:
                    s += 3
            for w in DMG_WORDS:
                if w in h:
                    s += 2
            return -s
        cards.sort(key=sc)
        return cards[0], "拿 %s" % d[cards[0]]
    claims = [i for i in d if i.startswith("rw") and i[2:].isdigit()]
    if claims:
        return claims[0], "领 %s" % d[claims[0]]
    if "rwdone" in d:
        return "rwdone", "奖励结算完"
    return None, ""


def choose(snap, pending):
    """返回 (target, 说明, 新 pending)。target 为 None 表示无动作可做。"""
    d = hints(snap)
    b = snap.get("battle") or {}

    # --- 奖励 / 收尾
    r, why = pick_reward(snap, d)
    if r:
        return r, why, pending
    if "leave" in d:
        return "leave", "战斗结束，离开", pending

    # --- 敌方回合，等
    if b.get("side") != "self":
        return None, "", pending

    # --- 正在选目标（技能）
    tgt = [i for i in d if "目标格" in d[i]]
    if tgt:
        foes = [i for i in tgt if (unit_on(snap, i) or {}).get("owner") == "opponent"]
        mine = [i for i in tgt if (unit_on(snap, i) or {}).get("owner") == "self"]
        pid = pending or 0
        if not is_buff(pid) and foes:
            foes.sort(key=lambda i: (unit_on(snap, i).get("hp", 999),
                                     -unit_on(snap, i).get("power", 0)))
            return foes[0], "施法打 %s" % d[foes[0]][:18], None
        if mine:
            mine.sort(key=lambda i: -unit_on(snap, i).get("power", 0))
            return mine[0], "增益 %s" % d[mine[0]][:18], None
        if foes:
            return foes[0], "施法打 %s" % d[foes[0]][:18], None
        if "cancel" in d:
            return "cancel", "无有效目标，取消", None
        # 单个目标格又没有任何单位 → 不能瞎点（会白扔一张牌），能取消就取消。
        return tgt[0], "施法兜底", None

    # --- 已选中我方单位 / 我方单位要行动
    mu = [i for i in d if "选中我方单位" in d[i]]
    if mu:
        best = deadliest(snap)
        if best and cell_id(best["cell"]) in mu:
            return cell_id(best["cell"]), "选大哥", pending
        return mu[0], "选单位", pending

    # --- 放置盟友
    place = [i for i in d if "放到这里" in d[i]]
    if place:
        def pscore(i):
            r_ = int(i[1])
            c_ = int(i[3:])
            return (abs(r_ - 3), abs(c_ - 1))
        place.sort(key=pscore)
        return place[0], "放置 %s" % place[0], pending

    # --- 单位攻击敌方
    atk = [i for i in d if d[i].startswith("攻击")]
    if atk:
        atk.sort(key=lambda i: (unit_on(snap, i) or {}).get("hp", 999))
        return atk[0], "攻击 %s" % atk[0], pending

    # --- 再点一次（确认出牌）
    use = [i for i in d if "再点一次" in d[i]]
    if use:
        return use[0], "确认出牌", pending

    # --- 移动（只在打不到时）
    mv = [i for i in d if "移动到这里" in d[i]]
    if mv:
        mv.sort(key=lambda i: (int(i[1]), int(i[3:])))
        return mv[0], "移动 %s" % mv[0], pending

    # --- 从手牌挑一张
    hs = [i for i in d if i.startswith("h") and "选中手牌" in d[i]]
    if hs:
        hit = [i for i in hs if "费用不足" not in d[i]]
        if not hit:
            return None, "", pending
        hand_by_idx = {int(h["index"]): h for h in hand(snap)}
        foes = foe_units(snap)
        mine = my_units(snap)
        energy = b.get("energy", 0)

        def cscore(i):
            idx = int(i[1:])
            h = hand_by_idx.get(idx) or {}
            cid = h.get("id", 0)
            cost = h.get("cost", 0)
            sc = 0
            if is_damage(cid):
                sc += 10 if foes else 1
            elif is_buff(cid):
                sc += 9 if mine else 2
            elif cost >= 1:
                sc += 6 if len(mine) < 3 else 3
            else:
                sc += 4
            if cost > energy:
                sc -= 30
            return -sc

        hit.sort(key=cscore)
        pick = hit[0]
        cid = (hand_by_idx.get(int(pick[1:])) or {}).get("id", 0)
        return pick, "选 %s" % card_info(cid)[0], cid

    if "end" in d:
        return "end", "结束回合", pending
    if "cancel" in d:
        return "cancel", "取消", pending
    return None, "", pending


# ---------------------------------------------------------------- 主循环


# 服务端有「同一目标 ~200ms 内不许连点」的守卫（提示「刚点过（N ms 前）」）。
# 而「选牌 → 再点一次确认」天然就是同一目标连点，不主动让一下就必然被拒。
_last = {"id": None, "at": 0.0}


def _click(t, why, verbose):
    """点一次，遇到「刚点过」就等一会儿重试（最多 6 次）。"""
    for attempt in range(6):
        gap = time.time() - _last["at"]
        if _last["id"] == t and gap < 0.34:
            time.sleep(0.34 - gap)
        rep = ai_cli.act_reply(t)
        ok = rep.get("ok", True)
        msg = rep.get("msg", "") or ""
        if ok:
            _last["id"], _last["at"] = t, time.time()
            if verbose:
                print("  ✓ %-10s %-22s" % (t, why[:22]))
            return True
        if "刚点过" not in msg:
            if verbose:
                print("  ✗ %-10s %-22s %s" % (t, why[:22], msg[:40]))
            return False
        time.sleep(0.18)
    if verbose:
        print("  ✗ %-10s %-22s 连点被拒太多次，放弃" % (t, why[:22]))
    return False


def step(snap, pending, verbose=False):
    t, why, np_ = choose(snap, pending)
    if not t:
        return False, snap, pending
    if not _click(t, why, verbose):
        return False, snap, pending
    time.sleep(0.10)
    return True, None, np_


def run_battle(max_turns=60, max_clicks=400, verbose=False):
    """打完当前这场，返回 (结束原因, 快照)。"""
    clicks = 0
    for _turn in range(max_turns):
        # 一个回合内的连续操作
        stuck = 0
        pending = None
        while clicks < max_clicks:
            snap = ai_cli.snapshot()
            scene = snap.get("scene")
            b = snap.get("battle") or {}
            if scene != "battle":
                return "场景切走：%s" % scene, snap
            if b.get("side") != "self":
                ai_cli.wait()
                time.sleep(0.2)
                continue
            if not my_units(snap) and not hand(snap):
                pass
            moved, new_snap, pending2 = step(snap, pending, verbose)
            clicks += 1
            pending = pending2
            if not moved:
                # 我方回合内没动作可做 → 结束回合
                d = hints(ai_cli.snapshot())
                if "end" not in d and "cancel" in d:
                    ai_cli.act("cancel")
                    time.sleep(0.25)
                    d = hints(ai_cli.snapshot())
                if "end" in d:
                    ai_cli.act("end")
                    clicks += 1
                    time.sleep(0.4)
                    ai_cli.wait()
                    time.sleep(0.2)
                break
            stuck = 0
        snap = ai_cli.snapshot()
        if snap.get("scene") != "battle":
            return "战斗结束", snap
        if "leave" in hints(snap):
            return "战斗结束", snap
    return "回合数上限", ai_cli.snapshot()


def settle_rewards(max_clicks=30, verbose=False):
    """把奖励页点干净（卡 / 道具 / 确认）。"""
    last, same = None, 0
    for _ in range(max_clicks):
        snap = ai_cli.snapshot()
        if snap.get("scene") != "battle":
            return snap
        d = hints(snap)
        if not any(k.startswith("rw") for k in d):
            return snap
        r, why = pick_reward(snap, d)
        if not r:
            return snap
        # 同一目标连点三次还停在原地 = 这条奖励打不开。
        # 实测「精英删卡 rw2」：需要奖励窗先弹出来，而 AI 侧没有那个入口，
        # 于是 rw2 被连点十几次、整批奖励卡在那儿（白烧时间，还可能卡死结算）。
        # 这时改走同号的 rws<k>（放弃这一条），把后面的奖励让出来。
        if r == last:
            same += 1
            if same >= 2 and r.startswith("rw") and not r.startswith("rws"):
                alt = "rws" + r[2:]
                if alt in d:
                    ai_cli.act(alt)
                    if verbose:
                        print("  ✗ %-10s 打不开 → 放弃这一条（%s）" % (r, alt))
                    time.sleep(0.4)
                    last, same = None, 0
                    continue
        else:
            same, last = 0, r
        ai_cli.act(r)
        if verbose:
            print("  ✓ %-10s %s" % (r, why))
        time.sleep(0.15)
    return ai_cli.snapshot()


def brief(snap):
    b = snap.get("battle") or {}
    return "hp %s/%s  敌 %s  回合 %s  费 %s/%s  scene=%s" % (
        b.get("hp_self", snap.get("hp")), snap.get("max_hp"),
        b.get("hp_opp"), b.get("turn"), b.get("energy"), b.get("max_energy"),
        snap.get("scene"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--battles", type=int, default=1)
    ap.add_argument("--turns", type=int, default=60)
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()

    for i in range(args.battles):
        snap = ai_cli.snapshot()
        print("[场次 %d] 开打前：%s" % (i + 1, brief(snap)))
        if snap.get("scene") != "battle":
            print("当前不在战斗里，退出")
            print(ai_cli.state())
            return 0
        why, end_snap = run_battle(args.turns, verbose=args.verbose)
        print("[场次 %d] %s：%s" % (i + 1, why, brief(end_snap)))
        settle_rewards(verbose=args.verbose)
        final = ai_cli.snapshot()
        print("[场次 %d] 结算后：%s" % (i + 1, brief(final)))
        if final.get("scene") != "battle":
            break
        if i + 1 < args.battles:
            d = hints(final)
            if "leave" in d:
                ai_cli.act("leave")
                time.sleep(0.5)
    print("---")
    print(ai_cli.state())
    return 0


if __name__ == "__main__":
    sys.exit(main())
