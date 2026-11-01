# -*- coding: utf-8 -*-
"""一整局的自动驾驶：选房间 → 打战斗 → 领奖励 → 篝火 / 商店 / 事件。

    python roam.py              # 从当前局面一直玩到这一局结束（或步数上限）
    python roam.py --steps 60
    python roam.py -q           # 少打印

为什么要有它
------------
advance.py 只管「走进一个房间 + 打一场」，房间之间的取舍（要不要绕去篝火、
顺路进不进商店、低血时要不要跳精英）以前靠人肉每步喂一条命令 ——
步数一多就撞循环守卫，而且**血量这本全局账没人记**。

实测五局全死在一层，死法几乎是同一个：普通战斗单场掉 12~64 血，
篝火只回 40%（≈32），血池越打越薄，最后十几血撞普通战斗即死。
所以这里把「血量经济」直接写死成策略：

    血 < 55%  → 篝火 > 商店 > 宝箱 > 事件 > 战斗 > 精英
    血 < 85%  → 商店 > 大宝箱 > 宝箱 > 篝火 > 事件 > 战斗 > 精英
    血 ≥ 85%  → 商店 > 大宝箱 > 宝箱 > 事件 > 战斗 > 精英 > 篝火（满血不去睡）

拿卡的优先级沿用 mech_pilot 的聚能炮击口径（产能优先，有产能才收增幅）。
"""
import argparse
import io
import json
import re
import sys
import time

import ai_cli
import autoplay as ap
import mech_pilot as mp

# 奖励三选一统一走机械之心的炮击口径
ap.pick_reward = mp.pick_reward

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

VERB = True

# ── 商店 ────────────────────────────────────────────────────────────────
# R474：不再用固定「必买名单」死守一条牌路 —— 货架上所有卡都过 mech_pilot 的
# card_value()，谁分高买谁（含探索加分，没试过的牌会自然浮上来）。
# 只在分太低时放弃，避免把钱败在废牌上。
BUY_MIN_SCORE = 62
BUY_SERVICES = ["最大生命 +", "删除一张卡"]

# ── 开场道具优先级 ──────────────────────────────────────────────────────
# 洞窟绳 > 类固醇：类固醇只 +10 上限（一层全程要吃 100+ 血，这是零头），
# 洞窟绳能直接跳掉一场 40 血的爆血关，等于一次性换回 40 血。
OPEN_RELICS = ["洞窟绳", "类固醇", "行囊", "勇气徽章", "惊奇盒子"]

# ── 事件：这些选项一律不碰（实测直接毁局或白送资源） ───────────────────────
EVENT_AVOID = ["鸭之低语", "源数之力", "失去 5 点最大生命", "锻造"]
# 这些看着划算
EVENT_LIKE = ["护符", "烟斗", "最大生命", "回复", "宝箱", "挑 1 张", "选 1 张",
              "获得道具", "获得卡片", "加入卡组", "抽"]

# ── 删卡优先级（越靠前越是垃圾） ──────────────────────────────────────────
JUNK = ["木栅栏", "攻击", "素体", "构装体", "升级"]


# 桥里 `scene` 是**场景文件名**（title / curtain / battle / map / shop / event /
# deck_edit…），不是界面上的中文名 —— 第 1 次试跑就栽在把 "curtain" 当成认不出的场景。
SCENE_KIND = {
    "title": "标题", "curtain": "开场", "class_pick": "开场",
    "battle": "战斗", "map": "地图", "shop": "商店",
    "event": "事件", "campfire": "事件", "deck_edit": "卡组编辑",
    "relic_pick": "道具", "ban": "禁卡", "gallery": "标题",
}


def scene_kind(snap):
    raw = snap.get("scene") or ""
    if raw in SCENE_KIND:
        return SCENE_KIND[raw]
    if "卡组" in raw:
        return "卡组编辑"
    if "事件" in raw or "休息" in raw:
        return "事件"
    return raw


def hp_pct(snap):
    hp = snap.get("hp") or 0
    mx = snap.get("max_hp") or 1
    try:
        return float(hp) / float(mx or 1)
    except Exception:  # noqa: BLE001
        return 1.0


def head(snap):
    return "hp %s/%s  gold %s  牌库 %s" % (
        snap.get("hp"), snap.get("max_hp"), snap.get("gold"), snap.get("deck"))


# 「点了但局面毫无变化」的键 —— 有些子界面（如惊喜运单的挑货页）ai_bridge 一个
# 可点目标都没暴露，主按钮却还在，于是同一个键被连点七八次，直到被判卡住。
# 这里按场景记账：同一场景里点过且没进展的键，下次换一个。
_TRIED = {}
_LAST = {"key": None}


def act(tid, why=""):
    _LAST["key"] = tid
    if VERB:
        print("  ✓ %-9s %s" % (tid, why))
    try:
        ai_cli.act(tid)
    except Exception as e:  # noqa: BLE001
        print("  ✗ %s 失败：%s" % (tid, e))
        return False
    time.sleep(0.28)
    return True


# ── 地图 ────────────────────────────────────────────────────────────────
def map_nodes(snap):
    out = []
    for k, v in ap.hints(snap).items():
        if not (k.startswith("n") and k[1:].isdigit()):
            continue
        if "走进" not in v:
            continue
        kind = "其它"
        for t in ("大宝箱", "宝箱", "精英", "商店", "休息", "事件", "战斗"):
            if t in v:
                kind = t
                break
        out.append((k, kind))
    return out


def node_score(kind, snap):
    p = hp_pct(snap)
    gold = snap.get("gold") or 0
    shop_ok = gold >= 40
    if p < 0.55:
        table = {"休息": 100, "商店": 92 if shop_ok else 20, "大宝箱": 84, "宝箱": 84,
                 "事件": 62, "战斗": 40, "精英": 5, "其它": 30}
    elif p < 0.85:
        table = {"商店": 100 if shop_ok else 25, "大宝箱": 92, "宝箱": 92, "休息": 74,
                 "事件": 70, "战斗": 50, "精英": 10, "其它": 30}
    else:
        table = {"商店": 100 if shop_ok else 25, "大宝箱": 96, "宝箱": 96, "事件": 80,
                 "战斗": 60, "精英": 42, "休息": 20, "其它": 30}
    return table.get(kind, 30)


_NODE_TRIES = {}
_LAST_NODE = [None]


def do_map(snap):
    d = ap.hints(snap)
    # 地图上还挂着没领的奖励（宝箱 / 精英掉落）→ 先领
    if any(k.startswith("rw") for k in d):
        if VERB:
            print("  先处理待领奖励")
        r, why = mp.pick_reward(snap, d)
        if r:
            act(r, why)
        elif "rwdone" in d:
            act("rwdone", "关掉奖励窗")
        return
    nodes = map_nodes(snap)
    if not nodes:
        # 只剩「离开」这类按钮（事件收尾）
        for k, v in d.items():
            if "离开" in v:
                act(k, "离开")
                return
        return
    nodes.sort(key=lambda t: (-node_score(t[1], snap), t[0]))
    # 防重入：同一格连续点 3 次都没推进就换下一格。
    # ⚠️ 实测「骑士冲锋」被反复进入 **9 次**、每次血量纹丝不动（57→57），整局卡死 ——
    # 原因是那一场一进去就 e.over（瞬间结束），leave 回地图后地图**没有推进**，
    # do_map 又把同一格选出来，于是无限循环。
    pick = nodes[0]
    if _LAST_NODE[0] != pick[0]:
        _NODE_TRIES.clear()
        _LAST_NODE[0] = pick[0]
    alive = [t for t in nodes if _NODE_TRIES.get(t[0], 0) < 3]
    if alive:
        pick = alive[0]
    _NODE_TRIES[pick[0]] = _NODE_TRIES.get(pick[0], 0) + 1
    if _NODE_TRIES[pick[0]] >= 3 and VERB:
        print("  ⚑ %s 进了 %d 次都没推进 → 换格" % (pick[0], _NODE_TRIES[pick[0]]))
    act(pick[0], "走进 %s（血 %d%%）" % (pick[1], int(hp_pct(snap) * 100)))
    # 等转场真发生：地图点格到切场景有几百毫秒延迟，原来按固定 sleep 会在还没切走时
    # 再点一次同一格（日志里每格都点 3 次，白烧时间）
    for _ in range(12):
        if scene_kind(ai_cli.snapshot()) != "地图":
            return
        time.sleep(0.25)


# ── 战斗 ────────────────────────────────────────────────────────────────
# 每场战斗的掉血逐场记下来 —— 「抓的牌有没有用」不能靠感觉，只能看这个数。
_BATTLES = []


def do_battle(snap):
    # ⚠️ 战斗内我方 HP 在 `battle.hp_self`，`snap["hp"]` 是局外 RunState.hp，
    # 只在战斗**胜利**时被写回；打输那场它原地不动，用它记账会得到「掉血 0」。
    hp0 = (snap.get("battle") or {}).get("hp_self") or snap.get("hp")
    # 记下这场的身份（关卡名 / 敌方血池 / 限时等）—— 复盘时「哪类关在爆血」
    # 只能靠这个，光有掉血数字看不出原因。
    meta = {k: v for k, v in (snap.get("battle") or {}).items()
            if k not in ("hand", "units", "board", "field")}
    try:
        # \s 会连换行一起吃掉，把关卡名后面的「第 1 回合 / 我方」也抓进来 → 只用空格制表符
        m = re.search(r"关卡[：:][ \t]*([^\n]{1,24})", ai_cli.state())
        if m:
            meta["level"] = m.group(1).strip()
    except Exception:  # noqa: BLE001
        pass
    snap = mp.run(verbose=VERB)
    # 胜利瞬间 engine.over 已为真，但结算面板还没跑完 —— 这一段里 pending_rewards
    # 是空的、hints 只有 leave，直接按 leave 会把整组奖励吞掉（实测吞过四场）。
    time.sleep(1.8)
    ap.settle_rewards(verbose=VERB)
    s = ai_cli.snapshot()
    fail = False
    try:
        _tail = ai_cli.state()
        fail = "对局结束：失败" in _tail
    except Exception:  # noqa: BLE001
        pass
    hp1 = 0 if fail else s.get("hp")
    try:
        _BATTLES.append({"n": s.get("node"), "hp0": hp0, "hp1": hp1,
                         "lost": max(0, (hp0 or 0) - (hp1 or 0)),
                         "fail": fail,
                         "meta": meta, "deck": s.get("deck")})
    except Exception:  # noqa: BLE001
        pass
    d = ap.hints(s)
    if "leave" in d:
        # 诊断：把引擎的「对局结束：胜利/失败（原因）」打出来。
        # 之前几局出现「血还剩一大半、一场掉 0 血却回到标题」—— 光看血量分不清是
        # 打输、打赢后整局结束、还是结算吞掉，必须让引擎自己说。
        if VERB:
            try:
                tail = [ln.strip() for ln in ai_cli.state().splitlines()
                        if "对局结束" in ln or "失败" in ln or "胜利" in ln]
                print("  ⚑ 结算：%s" % (" | ".join(tail[-3:]) if tail else "（无结束行）"))
            except Exception:  # noqa: BLE001
                pass
        act("leave", "结算离场")


# ── 篝火 ────────────────────────────────────────────────────────────────
def do_campfire(snap):
    d = ap.hints(snap)
    rest = next((k for k, v in d.items() if "休息" in v and "回复" in v), None)
    dele = next((k for k, v in d.items() if "删" in v or "柴" in v), None)
    if rest and (hp_pct(snap) < 0.72 or not dele):
        act(rest, "休息回血")
    elif dele:
        act(dele, "删一张垃圾")
    elif rest:
        act(rest, "休息")
    else:
        for k, v in d.items():
            if "离开" in v:
                act(k, "离开")
                return


# ── 卡组编辑（删卡） ──────────────────────────────────────────────────────
def do_deck_edit(snap):
    d = ap.hints(snap)
    names = {}
    try:
        txt = ai_cli.state()
        for cid, nm in re.findall(r"\[(d\d+)\]\s*([^（\n]+)", txt):
            names[cid] = nm.strip()
    except Exception:  # noqa: BLE001
        pass
    target = None
    for junk in JUNK:
        for cid, nm in names.items():
            if nm == junk:
                target = cid
                break
        if target:
            break
    if target is None and names:
        target = sorted(names)[-1]      # 认不出名字就删最后一张（新拿的通常最没用）
    if target:
        act(target, "选 %s" % names.get(target, "?"))
        time.sleep(0.5)
        d = ap.hints(ai_cli.snapshot())
        if "ok" in d:
            act("ok", "确认遗忘")
            return
    if "leave" in d:
        act("leave", "放弃这次编辑")


def do_card_pick(snap):
    """商店买「删除一张卡 / 附魔」后会进选卡子界面：从 [pN] 名字 里挑一张。"""
    names = {}
    try:
        txt = ai_cli.state()
        for pid, nm in re.findall(r"\[(p\d+)\]\s*([^（\n]+)", txt):
            names[pid] = nm.strip()
    except Exception:  # noqa: BLE001
        pass
    d = ap.hints(snap)
    if not names:
        for k, v in d.items():
            if re.fullmatch(r"p\d+", k):
                act(k, "选第一张并成交")
                return True
        return False
    target = None
    for junk in JUNK:
        for pid, nm in names.items():
            if nm == junk:
                target = pid
                break
        if target:
            break
    if target is None:
        target = sorted(names, key=lambda x: int(x[1:]))[0]
    act(target, "选 %s 并成交" % names.get(target, "?"))
    return True


# ── 商店 ────────────────────────────────────────────────────────────────
_PRICE = re.compile(r"（(\d+)\s*金币）")
_NAME = re.compile(r"「([^」]+)」")


def do_shop(snap, budget=4):
    # 已经在「商店 · 选卡」子界面（刚买过删卡 / 附魔）→ 先把这张选完
    if any("并成交" in v for v in ap.hints(snap).values()):
        do_card_pick(snap)
        time.sleep(0.8)
        return
    bought = 0
    for _ in range(budget + 2):
        snap = ai_cli.snapshot()
        d = ap.hints(snap)
        gold = snap.get("gold") or 0
        # 0) 血少先保命：「最大生命 +」既回血又扩池，比任何一张卡都值。
        #    实测栽过一次：14/66 血进商店买了两张卡，下一场直接被打死 —— 卡还没捂热。
        if hp_pct(snap) < 0.40:
            heal = next((k for k, v in d.items()
                         if k.startswith("s3") and "最大生命" in v), None)
            if heal:
                m = _PRICE.search(d[heal])
                price = int(m.group(1)) if m else 50
                if price <= gold:
                    act(heal, "保命：最大生命 +（%d）" % price)
                    bought += 1
                    if bought >= budget:
                        break
                    continue
        pick, why = None, ""
        # 1) 卡：货架上每张都过 card_value，谁分高买谁（同分买便宜的）
        cands = []
        for k, v in d.items():
            if not k.startswith("s1"):
                continue
            m = _NAME.search(v)
            if not m:
                continue
            m2 = _PRICE.search(v)
            price = int(m2.group(1)) if m2 else 50
            if price > gold:
                continue
            ids = mp._NAME2IDS.get(m.group(1)) or []
            sc = max([mp.card_value(i) for i in ids], default=0)
            if sc < BUY_MIN_SCORE:
                continue
            cands.append((sc - price * 0.15, k, "买 %s（%d 金 · %d 分）" % (m.group(1), price, sc)))
        if cands:
            cands.sort(reverse=True)
            pick, why = cands[0][1], cands[0][2]
        # 2) 服务：血不满先补最大生命，卡组垃圾多就删
        if not pick:
            for want in BUY_SERVICES:
                for k, v in d.items():
                    if not k.startswith("s3"):
                        continue
                    if want in v:
                        m = _PRICE.search(v)
                        price = int(m.group(1)) if m else 50
                        if price <= gold and (want != "最大生命 +" or hp_pct(snap) < 0.95):
                            pick, why = k, "买服务 %s（%d）" % (want, price)
                        break
                if pick:
                    break
        if not pick:
            break
        act(pick, why)
        nm = _NAME.search(why)
        if nm:
            for cid in (mp._NAME2IDS.get(nm.group(1)) or [])[:1]:
                mp._PICKED[cid] = mp._PICKED.get(cid, 0) + 1
                mp._save_picked()
        bought += 1
        if bought >= budget:
            break
    d = ap.hints(ai_cli.snapshot())
    for k, v in d.items():
        if "离开" in v:
            act(k, "离开商店")
            return


# ── 事件 ────────────────────────────────────────────────────────────────
def do_event(snap):
    d = ap.hints(snap)
    if any("休息" in v and "回复" in v for v in d.values()):
        do_campfire(snap)
        return
    btns = [(k, v) for k, v in d.items() if re.fullmatch(r"b\d+", k)]
    if not btns:
        for k, v in d.items():
            if any(w in v for w in ("离开", "继续", "确定", "关闭", "收下", "放弃")):
                act(k, "离开")
                return
        # 一个认得的按钮都没有（选卡 / 展示页 / 特殊子界面）→ 把第一个可点的点掉，
        # 总比干坐着强（实测在地图事件里连点 7 步，局面签名完全不变被判卡住）。
        for k, v in d.items():
            if re.fullmatch(r"[a-z]+\d*", k) and k not in ("ok", "leave"):
                act(k, "兜底点击 %s（%s）" % (k, (v or "")[:14]))
                return
        return
    # 只剩一个按钮（事件收尾）
    if len(btns) == 1:
        act(btns[0][0], "离开")
        return
    leave = next((k for k, v in btns if "离开" in v or "放弃" in v or "不" in v), None)
    tried = _TRIED.get("事件", set())
    good = [k for k, v in btns if k not in tried and not any(b in v for b in EVENT_AVOID)
            and any(w in v for w in EVENT_LIKE)]
    safe = [k for k, v in btns if k not in tried and not any(b in v for b in EVENT_AVOID)]
    if good:
        act(good[0], "好选项")
    elif safe:
        act(safe[0], "安全选项")
    elif leave:
        act(leave, "避开坑，离开")
    else:
        act(btns[0][0], "默认")


# ── 开场 ────────────────────────────────────────────────────────────────
def do_opening(snap):
    d = ap.hints(snap)
    for want in OPEN_RELICS:
        for k, v in d.items():
            if want in v:
                act(k, "拿 %s" % want)
                time.sleep(0.8)
                d = ap.hints(ai_cli.snapshot())
                for k2, v2 in d.items():
                    if "离开" in v2:
                        act(k2, "离开")
                        return
                return
    # 三选一里没有手册点名的道具：也别空手走人。上一局就是没命中直接点「不拿」，
    # 等于把开局资源白扔。先按 EVENT_LIKE 挑，实在没有才认输。
    for k, v in d.items():
        if not re.fullmatch(r"b\d+", k):
            continue
        if "摇摇头" in v or "不拿" in v:
            continue
        if any(w in v for w in EVENT_LIKE):
            act(k, "拿 %s" % v.replace("\n", " ")[:18])
            time.sleep(0.8)
            for k2, v2 in ap.hints(ai_cli.snapshot()).items():
                if "离开" in v2:
                    act(k2, "离开")
                    return
            return
    for k, v in d.items():
        if "摇摇头" in v:
            act(k, "不拿")
            return
    do_map(snap)


_RUNS_FILE = ".runs.jsonl"


def _picked_names(before):
    """本局新拿到的卡（对比开跑前的 _PICKED 计数）。"""
    out = []
    for cid, n in mp._PICKED.items():
        d = n - before.get(cid, 0)
        if d > 0:
            nm = ap.card_info(cid)[0] or str(cid)
            out.append("%s×%d" % (nm, d))
    return out


def record(seed, steps, snap, new_cards, how, cls=""):
    row = {
        "seed": seed, "class": cls or "",
        "steps": steps, "how": how,
        "layer": snap.get("layer"), "node": snap.get("node"),
        "hp": snap.get("hp"), "max_hp": snap.get("max_hp"),
        "gold": snap.get("gold"), "deck": snap.get("deck"),
        "new_cards": new_cards,
        "battles": list(_BATTLES),
    }
    try:
        with io.open(_RUNS_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    except Exception:  # noqa: BLE001
        pass
    print("本局拿到：%s" % ("、".join(new_cards) if new_cards else "（无）"))
    if _BATTLES:
        print("每场掉血：%s（合计 %d）" % (
            " / ".join("%s→%s%s" % (b["hp0"], b["hp1"],
                                     ("[" + str((b.get("meta") or {}).get("level", ""))[:8] + "]")
                                     if (b.get("meta") or {}).get("level") else "")
                       for b in _BATTLES),
            sum(b["lost"] for b in _BATTLES)))
    print("记录已追加 → %s" % _RUNS_FILE)


def main():
    global VERB
    p = argparse.ArgumentParser()
    p.add_argument("--steps", type=int, default=80)
    p.add_argument("-q", "--quiet", action="store_true")
    p.add_argument("--seed", default="", help="开局种子；给了就先开新局")
    p.add_argument("--class", dest="cls", default="机械之心", help="职业（配 --new/--seed）")
    p.add_argument("--new", action="store_true", help="先开新局再跑")
    a = p.parse_args()
    VERB = not a.quiet

    # 开新局（换种子）：上一个种子连着打不过就别死磕，换个种子重来。
    if a.new or a.seed:
        try:
            ai_cli.new_run(a.cls, a.seed)
        except Exception as e:  # noqa: BLE001
            print("开新局失败：%s" % e)
            return
        time.sleep(1.2)
        print("新局：%s 种子 %s" % (a.cls, a.seed or "（随机）"))

    picked_before = dict(mp._PICKED)

    last_sig, same = None, 0
    for i in range(a.steps):
        snap = ai_cli.snapshot()
        sc = scene_kind(snap)
        print("[%02d] %-6s %s" % (i + 1, sc, head(snap)))
        if sc == "标题":
            print("一局结束（回到标题）")
            how = "全灭"
            break
        # 真卡住的判据 = **局面签名**连续 6 次一模一样（场景名重复是正常的：
        # 在地图上连领 6 条宝箱奖励，场景一直是「地图」）
        sig = (sc, tuple(sorted(ap.hints(snap).keys())),
               snap.get("hp"), snap.get("gold"), len(snap.get("deck") or []))
        if sig == last_sig:
            same += 1
            if _LAST["key"]:
                _TRIED.setdefault(sc, set()).add(_LAST["key"])
                _LAST["key"] = None
        else:
            same, last_sig = 0, sig
            _TRIED.pop(sc, None)
        if same >= 6:
            print("⚠ 在「%s」卡住，停手" % sc)
            print(ai_cli.state()[:1500])
            how = "卡住"
            break

        if sc == "开场":
            do_opening(snap)
        elif sc == "地图":
            do_map(snap)
        elif sc == "战斗":
            do_battle(snap)
        elif sc == "商店":
            do_shop(snap)
        elif "选卡" in (snap.get("scene") or "") or "选卡" in sc:
            do_card_pick(snap)
        elif "卡组" in sc:
            do_deck_edit(snap)
        elif "事件" in sc or "休息" in sc:
            do_event(snap)
        else:
            d = ap.hints(snap)
            hit = next((k for k, v in d.items() if "离开" in v or "确定" in v), None)
            if hit:
                act(hit, "兜底离开")
            else:
                print("认不出的场景，停手")
                print(ai_cli.state()[:1500])
                how = "认不出场景"
                break
        time.sleep(0.35)

    else:
        how = "步数用完"
    print("---")
    print(ai_cli.state()[:1800])
    try:
        record(a.seed or (ai_cli.snapshot().get("seed") or ""), i + 1,
               ai_cli.snapshot(), _picked_names(picked_before), how, a.cls)
    except Exception as e:  # noqa: BLE001
        print("记账失败：%s" % e)


if __name__ == "__main__":
    main()
