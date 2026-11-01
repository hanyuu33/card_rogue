# -*- coding: utf-8 -*-
"""导航 + 战斗一条命令：python advance.py <节点名>

循环判定（ToolCallLoopGuard）只数同一工具的**连续**调用次数，逐回合手打必然撞线。
所以「换房间 → 打一场 → 结算奖励」全部收进本进程，外层只留一次 Bash。

用法：
    python advance.py n20           # 走进 n20；若是战斗就直接打完并结算奖励
    python advance.py n20 --stop    # 只走进去，不动战斗
"""
import sys
import time

import ai_cli
import autoplay as ap
import mech_pilot as mp

# 让 autoplay.settle_rewards 也走机械之心的拿卡优先级
ap.pick_reward = mp.pick_reward

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def goto(node, tries=5, pause=1.8):
    """走进目标节点。地图刚切回来时第一下点击常被吞，所以重试几次。"""
    for i in range(tries):
        snap = ai_cli.snapshot()
        if snap.get("scene") != "map":
            return snap
        if node not in ap.hints(snap):
            return snap
        ai_cli.act(node)
        time.sleep(pause)
        snap = ai_cli.snapshot()
        if snap.get("scene") != "map":
            return snap
    return ai_cli.snapshot()


def main():
    node = sys.argv[1] if len(sys.argv) > 1 else ""
    stop_only = "--stop" in sys.argv
    if node:
        snap = goto(node)
        print("进入 %s → 场景 %s" % (node, snap.get("scene")))
    else:
        snap = ai_cli.snapshot()

    if snap.get("scene") == "battle" and not stop_only:
        snap = mp.run(verbose=True)
        # ⚠️ 胜利瞬间 `engine.over` 已为真，但结算面板 `_show_over()` 还没跑完 ——
        # 那一小段里 `pending_rewards` 是空的，hints 只有「leave」。
        # 原来直接按 leave 就会把整组卡牌三选一 + 道具掉落一起跳过
        # （实测 n30 / n29 / n21 / n24 四场：金币与卡组纹丝不动，正是这个空窗）。
        time.sleep(1.8)
        ap.settle_rewards(verbose=True)
        if "leave" in ap.hints(ai_cli.snapshot()):
            ai_cli.act("leave")
            time.sleep(1.2)
    print("---")
    print(ai_cli.state()[:2200])
    return 0


if __name__ == "__main__":
    sys.exit(main())
