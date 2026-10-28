# -*- coding: utf-8 -*-
"""示例 AI：完全靠接口（不截图）把一局打完。

它存在的意义有两个：
  1. 当接口的**冒烟测试** —— 能一路推进，说明每个场景的可点目标都齐；
  2. 当**接入样例** —— 真正的 AI 只需要替掉 `choose_*` 里那几行判断。

    python demo_bot.py            # 自动跑，直到本局结束或步数上限
    python demo_bot.py --steps 80 --verbose
"""
import argparse
import sys
import time

import ai_cli

ENEMY_ROWS = {"0", "1", "2"}


def hint_map(targets):
    return {t["id"]: t["hint"] for t in targets}


def choose_battle(snap):
    b = snap.get("battle") or {}
    d = hint_map(snap.get("targets", []))
    if not d:
        return None, "没有可点目标"
    if b.get("side") != "self" and not any(i.startswith("rw") for i in d):
        return None, "等敌方回合"

    rw = [i for i in d if i.startswith("rw")]
    if rw:                                           # 结算奖励优先
        cards = [i for i in rw if "c" in i[2:]]
        if cards:
            return cards[0], "拿奖励卡"
        claims = [i for i in rw if i[2:].isdigit()]
        if claims:
            return claims[0], "领奖励道具"
        if "rwdone" in d:
            return "rwdone", "奖励处理完"
    if "pok" in d:                                   # 选卡页 → 全确认
        return "pok", "选卡页确认"
    if "leave" in d:
        return "leave", "战斗已结束"

    spell = [i for i, h in d.items() if "目标格" in h]
    if spell:                                        # 技能选目标 → 优先打**有单位**的格
        # 只按行号挑会打到空格子（引擎把空格也列为合法目标），纯浪费一张牌
        occupied = {"r%dc%d" % (b["cell"][0], b["cell"][1])
                    for b in b.get("board", []) if b.get("owner") == "opponent"}
        on_unit = [i for i in spell if i in occupied]
        if on_unit:
            return on_unit[0], "施法（打单位）"
        enemy_rows = [i for i in spell if i[1:2] in ENEMY_ROWS]
        return (enemy_rows or spell)[0], "施法（空位）"

    atk = [i for i, h in d.items() if h.startswith("攻击")]
    if atk:                                          # 能打就打
        return atk[0], "攻击"

    place = [i for i, h in d.items() if "放到这里" in h]
    if place:                                        # 已选手中的盟友 → 放最前排
        place.sort(key=lambda x: (int(x[1]), x[3:]))
        return place[0], "放置"

    mv = [i for i, h in d.items() if "移动到这里" in h]
    if mv:                                           # 打不到才移动，往敌方压
        mv.sort(key=lambda x: int(x[1]))
        return mv[0], "移动"

    use = [i for i, h in d.items() if h.startswith("再点一次")]
    if use:
        return use[0], "使用手牌"

    hands = [i for i, h in d.items() if h.startswith("选中手牌") and "费用不足" not in h]
    if hands:
        return hands[0], "选牌"
    units = [i for i, h in d.items() if h.startswith("选中我方单位")]
    if units:
        return units[0], "选单位"
    if "end" in d:
        return "end", "结束回合"
    if "cancel" in d:
        return "cancel", "取消选择"
    return None, "无解"


MAP_PRIORITY = [("事件", 6), ("商店", 5), ("休息", 4), ("宝箱", 4),
                ("战斗", 3), ("精英", 2), ("Boss", 1)]


def choose_map(snap):
    targets = snap.get("targets", [])
    if not targets:
        return None, "地图上没有可去的房间"
    for t in targets:
        if t["id"] == "reward":
            return "reward", "打开奖励"
    best, best_score = None, -1
    for t in targets:
        sc = 0
        for key, val in MAP_PRIORITY:
            if key in t["hint"]:
                sc = val
                break
        if sc > best_score:
            best, best_score = t["id"], sc
    return best, "走 %s" % (best or "")


def choose_generic(snap):
    scene = snap.get("scene")
    targets = snap.get("targets", [])
    if not targets:
        return None, "没有可点目标"
    ids = [t["id"] for t in targets]
    d = hint_map(targets)

    if scene == "title":
        return ids[0], "开始对战"
    if scene == "class_pick":
        return "c1", "选暗影刺客"
    if scene == "relic_pick":
        return ids[0], "选道具"
    if scene == "curtain":
        picks = [i for i in ids if i != ids[0] or len(ids) == 1]
        take = [i for i in ids if d[i].startswith("「")]
        if take:
            return take[0], "拿道具"
        return ids[0], "离开开场"
    if scene == "deck_edit":
        if "ok" in d:
            return "ok", "确认"
        ds = [i for i in ids if i.startswith("d")]
        if ds:
            return ds[0], "选卡（%s）" % d[ds[0]]
        return "leave", "没得选，放弃"
    if scene == "event":
        # 先把「能拿好处」的选项点掉，实在没有才离开
        skip_words = ("离开", "返回", "算了", "不拿", "什么都不做")
        gain = [i for i in ids if not any(w in d[i] for w in skip_words)]
        if gain:
            return gain[0], "事件：%s" % d[gain[0]]
        return ids[-1], "事件：离开"
    if scene == "shop":
        # 先买（买不起的目标桥接会明确拒绝），买不动了再离开
        buy = [i for i in ids if i.startswith("s") and "买不起" not in d.get(i, "")]
        if buy:
            return buy[0], "买：%s" % d[buy[0]]
        leave = [i for i in ids if "离开" in d.get(i, "")]
        if leave:
            return leave[0], "离开商店"
        return ids[0], "看看商店"
    if scene == "battle":
        return choose_battle(snap)
    return ids[0], "兜底"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--steps", type=int, default=120)
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--sleep", type=float, default=0.25)
    args = ap.parse_args()

    stuck, dead = {}, set()
    prev_sig = ""
    for step in range(1, args.steps + 1):
        try:
            snap = ai_cli.snapshot()
        except ai_cli.BridgeError as e:
            print("接口断了：%s" % e)
            return 1
        scene = snap.get("scene")
        if scene == "none" or snap.get("busy"):
            time.sleep(0.35)
            continue
        if scene == "battle":
            target, why = choose_battle(snap)
        elif scene == "map":
            target, why = choose_map(snap)
        else:
            target, why = choose_generic(snap)

        hp = snap.get("hp")
        if args.verbose:
            print("[%3d] %-10s hp=%-4s → %-6s %s" % (step, scene, hp, target, why))
        if target in dead:
            alive = [i for i in [t2["id"] for t2 in snap.get("targets", [])] if i not in dead]
            target = alive[0] if alive else None
        if target is None:
            time.sleep(0.5)
            continue
        try:
            rep = ai_cli.act_reply(target)
        except ai_cli.BridgeError as e:
            print("动作失败（%s）：%s" % (target, e))
            return 1
        # 判定「有没有真的推进」：服务端 ok=false 一定没推进；
        # ok=true 但 sig（去掉「上一步」的局面指纹）没变 → 同样没推进。
        # ⚠️ 别拿 state 全文比 —— 「上一步：…」每次动作都变，永远看起来像推进了。
        progressed = bool(rep.get("ok")) and rep.get("sig") != prev_sig
        if not progressed:
            stuck[target] = stuck.get(target, 0) + 1
            if args.verbose:
                print("        ↳ %s 没生效（%s）%d/3"
                      % (target, (rep.get("msg") or "").splitlines()[0][:40], stuck[target]))
            if stuck[target] >= 3:
                dead.add(target)
        else:
            stuck.clear()
            dead.clear()
        prev_sig = rep.get("sig")
        time.sleep(args.sleep)

        if snap.get("run_finished"):
            print("本局结束")
            break
    print(ai_cli.state())
    return 0


if __name__ == "__main__":
    sys.exit(main())
