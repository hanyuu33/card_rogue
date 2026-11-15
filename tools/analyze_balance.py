# -*- coding: utf-8 -*-
"""平衡分析：读 `telemetry.jsonl` 出「能拿去改数值」的几张表。

用法
----
    python tools/analyze_balance.py                       # 读默认存档位置
    python tools/analyze_balance.py path/to/telemetry.jsonl
    python tools/analyze_balance.py --csv out/            # 额外导出 CSV
    python tools/analyze_balance.py --sim                 # 只算机器人模拟局
    python tools/analyze_balance.py --real                # 只算真实玩家（默认两种都算并分开列）

产出
----
    balance_report.html   （内嵌样式，双击就能看；含条形对比）
    balance_*.csv         （--csv 时）

设计要点（为什么这么算）
------------------------
1. **选择率的分母是「被提议次数」，不是「被选择次数」的总和。**
   卡片在奖励里出现过几次，才是它被比较过的次数；跳过整组也算一次空白选项。
2. **胜率必须分层看。** 同一张卡在难度 0 和难度 11 的胜率差异，比「强卡 vs 弱卡」的差异
   还大。默认按 (难度档) 分组算 lift，并给「玩家熟练度」（开局前总局数）分层的中位数。
3. **raw 胜率会骗人。** 强玩家爱选上限卡、弱玩家爱选保命卡 —— 直接平均会把回血卡算成神卡。
   所以主指标用 **lift = 带这张卡的通关率 − 同难度基线通关率**，并同时给出样本量；
   样本不足的头尾一律标 `?`，不假装有结论。
4. **「选得多」不等于「有用」。** 关键指标是 **实际打出率**：选了它、整局却一次没打出去的
   比例。死卡（高分但从不使用）比没人选的卡更该改。
5. **敌人看掉血，不只看待胜率。** 普通战胜率常年 95%+，没有信息量；`平均掉血%` 才能
   分辨「这个精英有点疼」和「这个精英在屠杀」。
"""
import argparse
import html
import json
import os
import statistics
import sys
from collections import Counter, defaultdict

# ---------------------------------------------------------------- 读

def load_events(paths):
    evs = []
    for p in paths:
        if not os.path.isfile(p):
            continue
        with open(p, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    e = json.loads(line)
                except Exception:
                    continue          # 半行 / 坏行：跳过，不因为一行毁掉整份分析
                if isinstance(e, dict) and "ev" in e:
                    evs.append(e)
    evs.sort(key=lambda e: (e.get("ts", 0), e.get("q", 0)))
    return evs


def split_runs(evs, want_sim=None):
    """按 run 切开，返回 [(run_id, run_start, [events...])]。"""
    runs = {}
    order = []
    for e in evs:
        rid = e.get("run", "")
        if rid == "":
            continue
        if rid not in runs:
            runs[rid] = {"start": None, "evs": []}
            order.append(rid)
        runs[rid]["evs"].append(e)
        if e["ev"] == "run_start" and runs[rid]["start"] is None:
            runs[rid]["start"] = e
    out = []
    for rid in order:
        st = runs[rid]["start"] or {}
        sim = bool(st.get("sim", False))
        if want_sim is not None and sim != want_sim:
            continue
        out.append((rid, st, runs[rid]["evs"]))
    return out


# ---------------------------------------------------------------- 小工具

def wilson(k, n, z=1.96):
    """二项比例的 Wilson 置信区间 —— 小样本下比 k/n 正常得多。"""
    if n <= 0:
        return (0.0, 0.0, 0.0)
    p = k / n
    d = 1 + z * z / n
    c = p + z * z / (2 * n)
    m = z * ((p * (1 - p) / n + z * z / (4 * n * n)) ** 0.5)
    return (p, max(0.0, (c - m) / d), min(1.0, (c + m) / d))


def pct(v):
    return "?" if v is None else "%.1f%%" % (v * 100.0)


def bar(v, vmax, color="#c8a24a"):
    """HTML 小条：不引前端库，纯 div 宽度。"""
    w = 0.0 if vmax <= 0 else max(0.0, min(1.0, v / vmax)) * 100.0
    return ('<span class="bar"><span class="fill" style="width:%.1f%%;background:%s">'
            '</span></span>' % (w, color))


# ---------------------------------------------------------------- 主统计

def analyze(runs, label):
    """返回一个 dict：所有表都用它渲染。"""
    # ── 局级结果
    win_by_run = {}
    diff_by_run = {}
    runs_before = {}
    for rid, st, evs in runs:
        diff_by_run[rid] = int(st.get("diff", 0))
        runs_before[rid] = int(st.get("runs", 0))
        win = None
        for e in evs:
            if e["ev"] == "run_end":
                win = bool(e.get("win", False))
        win_by_run[rid] = win

    finished = [r for r in win_by_run if win_by_run[r] is not None]
    base_by_diff = {}
    for d in set(diff_by_run[r] for r in finished):
        rs = [r for r in finished if diff_by_run[r] == d]
        base_by_diff[d] = (sum(1 for r in rs if win_by_run[r]), len(rs))

    # ── 卡牌：提议 / 选择 / 打出
    card_offers = Counter()      # id -> 被提议次数
    card_picks = Counter()       # id -> 被选次数
    card_pick_runs = defaultdict(set)     # id -> 选了它的 run
    card_src = defaultdict(Counter)       # id -> {src: picks}
    card_skip_by_id = Counter()  # 整组跳过时，被跳过的那些 id 各算一次「没被选」
    offer_of_run = defaultdict(dict)      # run -> {oid: (cand, src)}
    skip_cand = Counter()
    played_by_run = {}
    relic_offers = Counter()
    relic_picks = Counter()
    tool_offers = Counter()
    tool_picks = Counter()
    for rid, st, evs in runs:
        for e in evs:
            k = e.get("ev")
            if k == "offer":
                cand = [int(x) for x in (e.get("cand") or [])]
                src = str(e.get("src", ""))
                offer_of_run[rid][int(e.get("oid", 0))] = (cand, src)
                c = {"card": card_offers, "relic": relic_offers,
                     "tool": tool_offers}.get(str(e.get("k", "")))
                if c is not None:
                    for cid in cand:
                        c[cid] += 1
            elif k == "pick":
                oid = int(e.get("oid", 0))
                cand, src = offer_of_run[rid].get(oid, ([], ""))
                kind = str(e.get("k", ""))
                if bool(e.get("skip", False)):
                    for cid in cand:
                        skip_cand[cid] += 1
                    continue
                cid = int(e.get("id", 0))
                if cid <= 0:
                    continue
                if kind == "card":
                    card_picks[cid] += 1
                    card_pick_runs[cid].add(rid)
                    card_src[cid][src] += 1
                elif kind == "relic":
                    relic_picks[cid] += 1
                elif kind == "tool":
                    tool_picks[cid] += 1
            elif k == "run_end":
                played_by_run[rid] = set(int(x) for x in (e.get("played") or []))

    # ── 战斗 / 敌人
    battles = []          # 每条：{key, win, hp_loss_ratio, turns, layer, diff, run}
    death_at = Counter()
    for rid, st, evs in runs:
        d = diff_by_run[rid]
        last_lose = None
        for e in evs:
            if e["ev"] != "battle":
                continue
            key = str(e.get("key", "")) or str(e.get("name", "?"))
            win = bool(e.get("win", False))
            mhp = int(e.get("mhp", 0)) or 1
            loss = max(0, int(e.get("hp0", 0)) - int(e.get("hp1", 0)))
            dmg_in = int(e.get("dmg_in", 0))
            battles.append({
                "key": key, "win": win, "diff": d, "layer": int(e.get("layer", 0)),
                "loss": (dmg_in if dmg_in > 0 else loss) / float(mhp),
                "turns": int(e.get("turns", 0)), "run": rid,
                "out": str(e.get("out", "")),
            })
            if not win and str(e.get("out", "")) != "flee":
                last_lose = key
        if last_lose:
            death_at[last_lose] += 1

    # ── 卡组变化（删 / 变形）与商店
    deck_del = Counter()
    deck_tr = Counter()
    shelf = Counter()
    bought = Counter()
    for rid, st, evs in runs:
        for e in evs:
            if e["ev"] == "deck":
                if str(e.get("op", "")) == "del":
                    deck_del[int(e.get("old", 0))] += 1
                else:
                    deck_tr[int(e.get("old", 0))] += 1
            elif e["ev"] == "shop_shelf":
                for it in (e.get("items") or []):
                    if str(it.get("k", "")) in ("card", "trap") and int(it.get("id", 0)) > 0:
                        shelf[(str(it["k"]), int(it["id"]))] += 1
            elif e["ev"] == "shop" and bool(e.get("bought", False)):
                bought[(str(e.get("k", "")), int(e.get("id", 0)))] += 1

    # ── 卡片表
    cards = []
    for cid, n_off in card_offers.items():
        if n_off <= 0:
            continue
        n_pick = card_picks.get(cid, 0)
        p, lo, hi = wilson(n_pick, n_off)
        picked_runs = card_pick_runs.get(cid, set())
        fin = [r for r in picked_runs if win_by_run.get(r) is not None]
        # 分层 lift：只在「这局难度」的基线里比
        lift = None
        if len(fin) >= 8:
            num = 0
            den = 0.0
            for r in fin:
                d = diff_by_run.get(r, 0)
                b = base_by_diff.get(d)
                if not b or b[1] <= 0:
                    continue
                num += 1 if win_by_run[r] else 0
                den += b[0] / float(b[1])
            if num > 0 or den > 0:
                lift = (num / float(len(fin))) - (den / float(len(fin)))
        # 实际打出率：选了它、整局却一次没打出的比例
        dead = None
        if picked_runs:
            miss = 0
            tot = 0
            for r in picked_runs:
                pl = played_by_run.get(r)
                if pl is None:
                    continue
                tot += 1
                if cid not in pl:
                    miss += 1
            if tot > 0:
                dead = miss / float(tot)
        cards.append({
            "id": cid, "offers": n_off, "picks": n_pick, "rate": p,
            "lo": lo, "hi": hi, "skips": skip_cand.get(cid, 0),
            "runs": len(picked_runs), "lift": lift, "dead": dead,
            "src": dict(card_src.get(cid, {})),
        })
    cards.sort(key=lambda c: (-c["rate"], -c["offers"]))

    # ── 敌人表
    by_enemy = defaultdict(list)
    for b in battles:
        by_enemy[b["key"]].append(b)
    enemies = []
    for key, bs in by_enemy.items():
        n = len(bs)
        w = sum(1 for b in bs if b["win"])
        p, lo, hi = wilson(w, n)
        losses = [b["loss"] for b in bs]
        turns = [b["turns"] for b in bs if b["turns"] > 0]
        enemies.append({
            "key": key, "n": n, "wins": w, "rate": p, "lo": lo, "hi": hi,
            "loss_med": statistics.median(losses) if losses else 0.0,
            "loss_mean": sum(losses) / n if n else 0.0,
            "turns_med": statistics.median(turns) if turns else 0,
            "deaths": death_at.get(key, 0),
        })
    enemies.sort(key=lambda x: (-x["loss_med"], -x["n"]))

    # ── 道具 / 工具
    def simple(off, pick):
        out = []
        for i, n in off.items():
            p, lo, hi = wilson(pick.get(i, 0), n)
            out.append({"id": i, "offers": n, "picks": pick.get(i, 0),
                        "rate": p, "lo": lo, "hi": hi})
        out.sort(key=lambda x: (-x["rate"], -x["offers"]))
        return out

    overall = {
        "runs": len(runs),
        "finished": len(finished),
        "wins": sum(1 for r in finished if win_by_run[r]),
        "battles": len(battles),
        "baseline": base_by_diff,
        "skill_median": statistics.median(runs_before.values()) if runs_before else 0,
    }
    return {
        "label": label, "overall": overall, "cards": cards, "enemies": enemies,
        "relics": simple(relic_offers, relic_picks),
        "tools": simple(tool_offers, tool_picks),
        "deck_del": deck_del, "deck_tr": deck_tr,
        "shelf": shelf, "bought": bought,
    }


# ---------------------------------------------------------------- 渲染

CSS = """
body{background:#151a16;color:#d8d4c4;font:13px/1.55 "Segoe UI",system-ui,sans-serif;margin:0;padding:32px}
h1{font:600 22px/1.3 "Segoe UI";color:#e8dcc0;margin:0 0 4px}
h2{font:600 16px/1.3 "Segoe UI";color:#e8dcc0;margin:34px 0 8px;border-bottom:1px solid #3a4038;padding-bottom:6px}
.meta{color:#8d9187;margin-bottom:20px}
table{border-collapse:collapse;width:100%;margin-top:6px}
th,td{padding:5px 8px;border-bottom:1px solid #262c26;text-align:left;white-space:nowrap}
th{color:#9aa08f;font-weight:600;font-size:12px;background:#1b211c}
td.num,th.num{text-align:right;font-variant-numeric:tabular-nums}
.bar{display:inline-block;width:90px;height:8px;background:#242a24;vertical-align:middle;margin-right:6px;border-radius:2px;overflow:hidden}
.fill{display:block;height:100%}
.warn{color:#d08a5a}.good{color:#8fbf7f}.dim{color:#6f7468}
.note{color:#8d9187;font-size:12px;margin:6px 0 0}
"""


def table(headers, rows, aligns=None):
    """headers: [(标题, 是否数字列)]；rows: [[单元格 html...]]"""
    out = ["<table><thead><tr>"]
    for h, is_num in headers:
        out.append('<th class="num">%s</th>' % html.escape(h) if is_num
                   else "<th>%s</th>" % html.escape(h))
    out.append("</tr></thead><tbody>")
    for r in rows:
        out.append("<tr>")
        for i, cell in enumerate(r):
            is_num = headers[i][1] if i < len(headers) else False
            out.append('<td class="num">%s</td>' % cell if is_num
                       else "<td>%s</td>" % cell)
        out.append("</tr>")
    out.append("</tbody></table>")
    return "".join(out)


def render(blocks):
    parts = ["<!doctype html><meta charset='utf-8'>",
             "<title>Quackill 平衡报告</title><style>%s</style>" % CSS,
             "<h1>平衡报告</h1>",
             "<div class='meta'>数据源：telemetry.jsonl　|　生成于运行时分析脚本 "
             "(tools/analyze_balance.py)</div>"]
    for b in blocks:
        parts.append(b)
    return "".join(parts)


def block_analysis(a):
    o = a["overall"]
    wr = (o["wins"] / o["finished"]) if o["finished"] else None
    out = ["<h2>%s</h2>" % html.escape(a["label"])]
    out.append("<p class='note'>已完成 %d 局 / 通关 %d 局（%s）　对战场次 %d　"
               "玩家局数中位数 %d</p>"
               % (o["finished"], o["wins"], pct(wr), o["battles"], o["skill_median"]))
    # 难度基线
    rows = []
    for d in sorted(o["baseline"]):
        w, n = o["baseline"][d]
        p, lo, hi = wilson(w, n)
        rows.append([str(d), str(n), pct(p), "%s–%s" % (pct(lo), pct(hi))])
    if rows:
        out.append("<h2>难度基线（后面所有 lift 都以它为准）</h2>")
        out.append(table([("难度", True), ("局数", True), ("通关率", True), ("95% 区间", True)], rows))

    # 卡牌选择率
    cards = a["cards"]
    if cards:
        top = cards[:40]
        bad = [c for c in cards if c["offers"] >= 20 and c["rate"] <= 0.06]
        rows = []
        for c in top:
            rows.append([
                "#%d" % c["id"], str(c["offers"]), str(c["picks"]),
                bar(c["rate"], 1.0) + pct(c["rate"]),
                "%s–%s" % (pct(c["lo"]), pct(c["hi"])),
                pct(c["dead"]) if c["dead"] is not None else "?",
                ("%+.1f%%" % (c["lift"] * 100)) if c["lift"] is not None else "?",
            ])
        out.append("<h2>卡牌选择率（分母 = 被提议次数）</h2>")
        out.append(table([("卡 id", False), ("提议", True), ("被选", True),
                          ("选择率", False), ("95% 区间", False),
                          ("选了却没用", True), ("同难度 lift", True)], rows))
        out.append("<p class='note'>「选了却没用」= 选了它、整局一次都没打出去的比例 —— "
                   "这一列高说明卡是<strong>死卡</strong>（占卡位但没人愿意用），"
                   "比选择率低更该改。lift 的分层基线见上一张表。</p>")
        if bad:
            out.append("<p class='warn'>没人要的卡（≥20 次提议、选择率 ≤6%%）：%s</p>"
                       % ", ".join("#%d(%.0f%%)" % (c["id"], c["rate"] * 100) for c in bad[:30]))

    # 敌人
    enemies = a["enemies"]
    if enemies:
        vmax = max(e["loss_med"] for e in enemies) or 1.0
        rows = []
        for e in enemies:
            dmg = e["loss_med"]
            rows.append([
                html.escape(e["key"]), str(e["n"]), pct(e["rate"]),
                bar(dmg, vmax, "#b96a4a" if dmg > 0.3 else "#6f8f6a") + pct(dmg),
                str(e["turns_med"]), str(e["deaths"]),
            ])
        out.append("<h2>敌人：胜率 + 掉血（按中位数排序）</h2>")
        out.append(table([("关卡 key", False), ("场次", True), ("胜率", True),
                          ("平均掉血 / 最大生命", False), ("中位回合", True),
                          ("死在这里", True)], rows))
        out.append("<p class='note'>普通战胜率常年很高，<strong>掉血</strong>才是敏感指标；"
                   "掉血超过 30% 的关卡值得单独看录像。</p>")

    # 道具 / 工具
    for key, title in (("relics", "道具领取率"), ("tools", "工具领取率")):
        items = a[key]
        if not items:
            continue
        rows = []
        for it in items[:30]:
            rows.append(["#%d" % it["id"], str(it["offers"]), str(it["picks"]),
                         bar(it["rate"], 1.0) + pct(it["rate"])])
        out.append("<h2>%s</h2>" % title)
        out.append(table([("id", False), ("掉落", True), ("领取", True),
                          ("领取率", False)], rows))

    # 删卡 / 商店
    if a["deck_del"]:
        rows = [["#%d" % i, str(n)] for i, n in a["deck_del"].most_common(20)]
        out.append("<h2>被删最多的卡（玩家投的负票）</h2>")
        out.append(table([("卡 id", False), ("被删次数", True)], rows))
    if a["shelf"]:
        rows = []
        for (k, i), n in a["shelf"].most_common(25):
            b = a["bought"].get((k, i), 0)
            p, lo, hi = wilson(b, n)
            rows.append([k, "#%d" % i, str(n), str(b), pct(p)])
        out.append("<h2>商店：上架 vs 成交</h2>")
        out.append(table([("类型", False), ("id", False), ("上架", True),
                          ("成交", True), ("成交率", True)], rows))
    return "".join(out)


def write_csvs(a, outdir):
    os.makedirs(outdir, exist_ok=True)
    tag = "sim" if "sim" in a["label"] else "real"

    def dump(name, headers, rows):
        p = os.path.join(outdir, "balance_%s_%s.csv" % (tag, name))
        with open(p, "w", encoding="utf-8-sig", newline="") as f:
            f.write(",".join(headers) + "\n")
            for r in rows:
                f.write(",".join('"%s"' % str(x).replace('"', "'") for x in r) + "\n")

    dump("cards", ["id", "offers", "picks", "pick_rate", "ci_lo", "ci_hi",
                   "skips", "dead_rate", "lift"],
         [[c["id"], c["offers"], c["picks"], round(c["rate"], 4),
           round(c["lo"], 4), round(c["hi"], 4), c["skips"],
           "" if c["dead"] is None else round(c["dead"], 4),
           "" if c["lift"] is None else round(c["lift"], 4)] for c in a["cards"]])
    dump("enemies", ["key", "n", "wins", "rate", "loss_median", "turns_median", "deaths"],
         [[e["key"], e["n"], e["wins"], round(e["rate"], 4),
           round(e["loss_med"], 4), e["turns_med"], e["deaths"]] for e in a["enemies"]])
    print("  CSV → %s" % outdir)


# ---------------------------------------------------------------- 入口

def default_paths():
    """默认去 Godot 的 user:// 目录找（Windows：%APPDATA%/Godot/app_userdata/<项目名>/）。

    ⚠️ 项目名不一定是英文 —— 这个工程 `project.godot` 里写的是「卡牌肉鸽」，
    user:// 就落在同名中文目录下。所以先读 project.godot 的 config/name，
    再挂一组历史候选兜底（改名之前的旧目录也一并找）。
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    names = []
    try:
        with open(os.path.join(root, "project.godot"), "r", encoding="utf-8",
                  errors="replace") as f:
            for line in f:
                if line.startswith("config/name="):
                    names.append(line.split("=", 1)[1].strip().strip('"'))
                    break
    except OSError:
        pass
    for n in ("卡牌肉鸽", "Quackill", "DuckCardsRogue", "card_rogue"):
        if n not in names:
            names.append(n)
    appdata = os.environ.get("APPDATA", "")
    out = []
    if appdata:
        for n in names:
            out.append(os.path.join(appdata, "Godot", "app_userdata", n, "telemetry.jsonl"))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="*", help="事件流文件（默认去 Godot user:// 找）")
    ap.add_argument("--csv", default="", help="导出 CSV 的目录")
    ap.add_argument("--out", default="balance_report.html")
    ap.add_argument("--sim", action="store_true", help="只算机器人模拟局")
    ap.add_argument("--real", action="store_true", help="只算真实玩家局")
    args = ap.parse_args(argv)

    paths = args.paths or default_paths()
    found = []
    for p in paths:
        for cand in (p, p + ".1"):
            if os.path.isfile(cand):
                found.append(cand)
    if not found:
        print("找不到事件流。试过：\n  " + "\n  ".join(paths))
        print("\n事件流只在**发布版**里写（GameBuild.is_release()）。"
              "编辑器里验证用：godot -- --release [--sim]")
        return 2

    evs = load_events(found)
    if not evs:
        print("事件流是空的：%s" % ", ".join(found))
        return 2

    want = None
    if args.sim and not args.real:
        want = True
    elif args.real and not args.sim:
        want = False

    blocks = []
    real_runs = split_runs(evs, False if want is None else want)
    if real_runs:
        a = analyze(real_runs, "真实玩家" if not (want is True) else "模拟局")
        blocks.append(block_analysis(a))
        if args.csv:
            write_csvs(a, args.csv)
    else:
        blocks.append("<h2>没有可分析的局</h2><p class='note'>事件流里没有 run_start / "
                      "run_end 配对，或者被 --sim / --real 过滤光了。</p>")

    with open(args.out, "w", encoding="utf-8", newline="") as f:
        f.write(render(blocks))
    print("报告 → %s（%d 条事件 / %d 局）" % (args.out, len(evs), len(real_runs)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
