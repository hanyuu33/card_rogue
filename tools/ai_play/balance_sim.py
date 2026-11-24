# -*- coding: utf-8 -*-
"""Phase C：让机器人跑 N 局，产出与玩家端**同一 schema** 的事件流。

用法
----
    python launch.py --headless --sim --telemetry     # 先起带 AI 接口的游戏进程
    python balance_sim.py --runs 20                   # 再跑 20 局
    python analyze_balance.py --sim                   # 最后出「AI 先验」报告

为什么需要它
------------
刚上架时玩家只有几十个，而卡池有 320 张 —— 真实数据里每张卡只有个位数样本，
算不出任何结论（置信区间比效应还大）。所以**先用机器人把先验跑出来**：
机器人的选择是固定策略（`mech_pilot` 的卡面评分），它的胜率反映的是「数值上限」，
玩家的胜率反映的是「体感与策略」。两者**对不上的地方**才是真正要改的卡：

    * AI 觉得强、玩家不用 → 大概太贵 / 太慢 / 需要配合，或者说明写得看不懂；
    * AI 不选、玩家抢着要 → 大概是「体感爽」但数值弱，值得微调数值而不是砍设计。

实现
----
本脚本**只做编排**，不做决策：
    1. 调 `ai_cli.new()` 按职业 + 种子开新局（种子可复现，出了问题能原地重放）；
    2. 调 `roam.py`（已有的一整局自动驾驶）当子进程打完整局；
    3. 事件流由游戏侧 `Telemetry` 写（需要启动时带 `--telemetry --sim`）。
单局之间用子进程隔离 —— `roam.py` 的全局状态（血量账、买过的服务）不该跨局残留。
"""
import argparse
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PY = sys.executable or "python"

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def bridge_alive() -> bool:
    try:
        import ai_cli
        ai_cli.state()
        return True
    except Exception:  # noqa: BLE001
        return False


def run_one(cls: str, seed: str, steps: int, quiet: bool) -> dict:
    """打一局，返回 {ok, result, secs, tail}。"""
    import ai_cli
    t0 = time.time()
    try:
        rep = ai_cli.new_run(cls, seed)
        if not rep.get("ok"):
            return {"ok": False, "result": "new_failed", "secs": 0.0,
                    "tail": str(rep.get("msg", ""))[:200]}
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "result": "bridge_error", "secs": 0.0, "tail": str(e)[:200]}

    args = [PY, os.path.join(HERE, "roam.py"), "--steps", str(steps)]
    if quiet:
        args.append("-q")
    p = subprocess.run(args, cwd=HERE, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    out = (p.stdout or "") + (p.stderr or "")
    result = "unknown"
    if "通关" in out or "胜利" in out:
        result = "win"
    if "失败" in out or "死亡" in out or "血归零" in out:
        result = "lose"
    m = re.search(r"步数用完", out)
    if m:
        result = "timeout"
    return {"ok": True, "result": result, "secs": time.time() - t0,
            "tail": out.strip().splitlines()[-1][:200] if out.strip() else ""}


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--runs", type=int, default=10)
    ap.add_argument("--class", dest="cls", default="机械之心",
                    help="职业（机械之心 / 暗影刺客 / 森林精魄）")
    ap.add_argument("--steps", type=int, default=260, help="单局步数上限")
    ap.add_argument("--seed0", type=int, default=1000, help="起始种子（逐局 +1）")
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args(argv)

    if not bridge_alive():
        print("AI 接口没起来。先跑：\n  python launch.py --headless --sim --telemetry")
        return 2

    tally = {}
    t_all = time.time()
    for i in range(args.runs):
        # 种子码必须是 **10 位 A-Z / 0-9**（`RunState.seed_value_of()` 的口径），
        # 直接传 "1000" 会被 new_run 打回「种子码不合法」。补零成 10 位数字最省事。
        seed = str(args.seed0 + i).zfill(10)
        r = run_one(args.cls, seed, args.steps, args.quiet)
        tally[r["result"]] = tally.get(r["result"], 0) + 1
        print("[%d/%d] seed=%s  %-9s %5.1fs  %s"
              % (i + 1, args.runs, seed, r["result"], r["secs"], r["tail"]))
    print("---")
    print("共 %d 局 / 用时 %.0fs / 结果 %s"
          % (args.runs, time.time() - t_all,
             "  ".join("%s=%d" % (k, v) for k, v in sorted(tally.items()))))
    print("下一步：python analyze_balance.py --sim")
    return 0


if __name__ == "__main__":
    sys.exit(main())
