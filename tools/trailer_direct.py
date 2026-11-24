# -*- coding: utf-8 -*-
"""按顺序执行操作 / 自动推进，同时用 Movie Maker 录制。

    # 固定序列
    python tools/trailer_direct.py --out seg.avi --ops "new:暗影刺客;act:b0;pick:战斗"

    # 自动打：自己看局面走地图、进战斗、出牌、结束回合
    python tools/trailer_direct.py --out battle.avi --cls 暗影刺客 --auto 40 --duration 70

开局事件是随机的（开场选道具 / 卡组改造 / 直接给道具），地图房间编号也随机，
所以自动模式每一步都重新读 /state 再决定动作，不预设坐标。
"""
import argparse
import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get(
    "CARD_ROGUE_GODOT",
    str(Path.home() / ".workbuddy/binaries/godot/Godot_v4.3-stable_win64.exe"),
))
PORT = int(os.environ.get("CARD_ROGUE_AI_PORT", "8771"))
OUTDIR = ROOT / "release" / "trailer" / "raw"


def port_open():
    with socket.socket() as s:
        s.settimeout(0.3)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def _opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def get(path, timeout=10.0):
    with _opener().open("http://127.0.0.1:%d%s" % (PORT, path), timeout=timeout) as r:
        return r.read().decode("utf-8")


def post(path, payload, timeout=40.0):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        "http://127.0.0.1:%d%s" % (PORT, path), data=data, method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"})
    with _opener().open(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def find_target(txt, kw, prefer=None):
    """在 state 文本里找含 kw 的 [id]；prefer 命中则优先。"""
    cands = []
    for line in txt.splitlines():
        if kw in line and "[" in line and "]" in line:
            tid = line.split("[", 1)[1].split("]", 1)[0]
            if prefer and prefer in line:
                return tid
            cands.append(tid)
    return cands[0] if cands else None


def auto_step(allow_card=True):
    """读一次局面，决定并执行一个动作。返回 (说明, 是否还在推进)。"""
    txt = get("/state")
    # 卡组编辑这类界面先退出去，别在里面空转
    if "[leave]" in txt:
        if "放弃这次编辑" in txt or "回地图" in txt:
            post("/act", {"target": "leave"})
            return "放弃编辑回地图", True
    # 0) 已选好卡、正在挑目标格
    if "的目标格" in txt:
        t = (find_target(txt, "的目标格", prefer="r2c1")
             or find_target(txt, "的目标格", prefer="r2")
             or find_target(txt, "的目标格"))
        if t:
            post("/act", {"target": t})
            return "指定目标 %s" % t, True
    # 1) 放置型卡牌（盟友/工事）优先落位；"再点一次"对这类卡只是取消选择
    if "放到这里" in txt:
        t = find_target(txt, "放到这里", prefer="r5c1") or find_target(txt, "放到这里")
        if t:
            post("/act", {"target": t})
            return "落位 %s" % t, True
    if "再点一次" in txt:
        t = find_target(txt, "再点一次")
        if t:
            post("/act", {"target": t})
            return "确认使用 %s" % t, True
    if "选中第" in txt and "张" in txt:
        t = find_target(txt, "选中第")
        if t:
            post("/act", {"target": t})
            return "选取卡组 %s" % t, True
    if "确定" in txt and "[ok]" in txt:
        post("/act", {"target": "ok"})
        return "确定", True
    # 2) 战斗中出牌 —— 正常打：攻击 > 放盟友 > 移动 > 技能 > 结束回合
    if "场景：战斗" in txt:
        if allow_card:
            # 优先打攻击
            t = find_target(txt, "选中手牌「攻击」") or find_target(txt, "选中手牌「幽影」")
            if t:
                post("/act", {"target": t})
                return "出牌 %s" % t, True
            # 放盟友到前排
            if "放到这里" in txt:
                t = find_target(txt, "放到这里", prefer="r5c1") or find_target(txt, "放到这里")
                if t:
                    post("/act", {"target": t})
                    return "落位 %s" % t, True
            # 移动压线
            if "移动到这里" in txt:
                t = find_target(txt, "移动到这里")
                if t:
                    post("/act", {"target": t})
                    return "移动 %s" % t, True
            # 技能选目标（打有单位的格子）
            if "的目标格" in txt:
                t = find_target(txt, "的目标格")
                if t:
                    post("/act", {"target": t})
                    return "指定目标 %s" % t, True
            # 确认使用
            if "再点一次" in txt:
                t = find_target(txt, "再点一次")
                if t:
                    post("/act", {"target": t})
                    return "确认使用 %s" % t, True
            # 选其他手牌
            t = find_target(txt, "选中手牌")
            if t and "费用不足" not in txt:
                post("/act", {"target": t})
                return "选牌 %s" % t, True
        t = find_target(txt, "结束回合")
        if t:
            post("/act", {"target": t})
            return "结束回合", True
        return "战斗中等待（敌方回合/结算中）", True
    # 3) 地图前进
    if "走进" in txt:
        t = find_target(txt, "走进 战斗") or find_target(txt, "走进")
        if t:
            post("/act", {"target": t})
            return "前进 %s" % t, True
    # 4) 事件 / 开场 / 卡组编辑的出口
    for kw in ("[leave]", "离开", "继续", "[b0]"):
        t = find_target(txt, kw)
        if t:
            post("/act", {"target": t})
            return "离开 %s" % t, True
    return "无可用动作", False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="seg_direct.avi")
    ap.add_argument("--frames", type=int, default=7200)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--ops", default="")
    ap.add_argument("--cls", default="")
    ap.add_argument("--auto", type=int, default=0, help="自动步数上限")
    ap.add_argument("--duration", type=float, default=60.0, help="自动模式总时长（真实秒）")
    ap.add_argument("--step-gap", type=float, default=1.1)
    ap.add_argument("--passive", action="store_true", help="只结束回合，不出牌（录敌人行动）")
    ap.add_argument("--interval", type=float, default=1.8)
    ap.add_argument("--boot-wait", type=float, default=2.0)
    ap.add_argument("--lang", default="", help="游戏内语言覆盖，如 en / zh")
    args = ap.parse_args()

    OUTDIR.mkdir(parents=True, exist_ok=True)
    out = OUTDIR / args.out
    if out.exists():
        out.unlink()

    log = open(ROOT / ".trailer_game.log", "w", encoding="utf-8")
    cmd = [str(GODOT), "--path", str(ROOT),
           "--write-movie", str(out), "--fixed-fps", str(args.fps),
           "--quit-after", str(args.frames), "--", "--ai-bridge=%d" % PORT]
    if args.lang:
        cmd.append("--lang=%s" % args.lang)
    t0 = time.time()
    print("run:", args.out, flush=True)
    proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, cwd=str(ROOT))
    try:
        ok = False
        for _ in range(200):
            if port_open():
                ok = True
                break
            if proc.poll() is not None:
                break
            time.sleep(0.2)
        print("port_ready %s (+%.1fs)" % (ok, time.time() - t0), flush=True)
        if not ok:
            return 1
        time.sleep(args.boot_wait)

        if args.auto:
            if args.cls:
                rep = post("/new", {"class": args.cls, "seed": ""})
                print("[+%.1fs] new %s ok=%s" % (time.time() - t0, args.cls, rep.get("ok")))
                time.sleep(1.0)
                post("/act", {"target": "b0"})
                print("[+%.1fs] 进入游戏" % (time.time() - t0))
                time.sleep(1.2)
            end = time.time() + args.duration
            last_msg, same = "", 0
            for i in range(args.auto):
                if time.time() > end:
                    print("到达时长上限", flush=True)
                    break
                try:
                    msg, alive = auto_step(allow_card=not args.passive)
                except Exception as e:  # noqa: BLE001
                    print("step err:", e, flush=True)
                    break
                if msg == last_msg:
                    same += 1
                else:
                    same, last_msg = 0, msg
                print("[+%.1fs] #%02d %s%s" % (time.time() - t0, i, msg,
                                               "  (重复%d)" % same if same else ""), flush=True)
                if same >= 2:
                    print("---- 动作重复，尝试取消并回看局面 ----")
                    print(get("/state")[:1400])
                    try:
                        post("/act", {"target": "cancel"})
                    except Exception:  # noqa: BLE001
                        pass
                    same = 0
                if not alive:
                    print("---- 卡住时的局面 ----")
                    print(get("/state")[:1800])
                    break
                time.sleep(args.step_gap)
        else:
            for op in [x.strip() for x in args.ops.split(";") if x.strip()]:
                time.sleep(args.interval)
                stamp = "+%.1fs" % (time.time() - t0)
                try:
                    if op == "state":
                        print("---- state %s ----" % stamp)
                        print(get("/state")[:2200])
                    elif op.startswith("new:"):
                        rep = post("/new", {"class": op[4:], "seed": ""})
                        print("[%s] new %s ok=%s" % (stamp, op[4:], rep.get("ok")))
                    elif op.startswith("act:"):
                        rep = post("/act", {"target": op[4:]})
                        print("[%s] act %s ok=%s %s" % (stamp, op[4:], rep.get("ok"),
                                                        (rep.get("msg") or "").splitlines()[0][:60]))
                    elif op.startswith("pick:"):
                        t = find_target(get("/state"), op[5:])
                        if not t:
                            print("[%s] pick '%s' 无目标" % (stamp, op[5:]))
                            break
                        rep = post("/act", {"target": t})
                        print("[%s] pick '%s' -> %s ok=%s" % (stamp, op[5:], t, rep.get("ok")))
                except Exception as e:  # noqa: BLE001
                    print("[%s] %s FAILED %s" % (stamp, op, e), flush=True)
                    break

        print("done (+%.1fs)" % (time.time() - t0), flush=True)
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except Exception:
                proc.kill()
        print("out=%s size=%s" % (out.exists(), out.stat().st_size if out.exists() else 0))
        return 0
    finally:
        if proc.poll() is None:
            proc.terminate()
        log.close()


if __name__ == "__main__":
    sys.exit(main())
