# -*- coding: utf-8 -*-
"""用 Movie Maker 录制指定的元素连携实机镜头。

脚本只通过 AiBridge 调用既有场景点击；不直接改伤害、不关闭敌方 AI。
人工试玩与脚本录制的区别见 tools/_manual_trailer_loadout.gd。
"""
import argparse
import json
import os
import socket
import subprocess
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get(
    "CARD_ROGUE_GODOT",
    str(Path.home() / ".workbuddy/binaries/godot/Godot_v4.3-stable_win64.exe"),
))
PORT = int(os.environ.get("CARD_ROGUE_AI_PORT", "8772"))
OUT = ROOT / "release" / "trailer" / "raw" / "seg_element_combo.avi"
LOG = ROOT / "release" / "trailer" / "work_v6" / "element_combo_states.log"


def opener():
    return urllib.request.build_opener(urllib.request.ProxyHandler({}))


def get(path, timeout=8.0):
    with opener().open("http://127.0.0.1:%d%s" % (PORT, path), timeout=timeout) as r:
        return r.read().decode("utf-8")


def post(path, payload, timeout=15.0):
    req = urllib.request.Request(
        "http://127.0.0.1:%d%s" % (PORT, path),
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        method="POST", headers={"Content-Type": "application/json; charset=utf-8"})
    with opener().open(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def port_open():
    with socket.socket() as s:
        s.settimeout(0.25)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def find_target(txt, keyword, prefer=None):
    candidates = []
    for line in txt.splitlines():
        if keyword not in line or "[" not in line or "]" not in line:
            continue
        target = line.split("[", 1)[1].split("]", 1)[0]
        if prefer and prefer in line:
            return target
        candidates.append(target)
    return candidates[0] if candidates else None


def main():
    global OUT, LOG
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", choices=["zh", "en"], default="zh")
    # R764：`--clean` = 宣传录制模式（压掉战斗内仍是中文的说明文字，保留伤害数字）
    ap.add_argument("--clean", action="store_true")
    ap.add_argument("--out", default="")
    args = ap.parse_args()
    OUT = ROOT / "release" / "trailer" / "raw" / (
        "seg_element_combo_en.avi" if args.lang == "en" else "seg_element_combo.avi")
    # ⚠️ `--out` 必须在这段语言默认名**之后**覆盖，否则会被上面的默认名顶掉。
    if args.out:
        OUT = ROOT / "release" / "trailer" / "raw" / args.out
    LOG = ROOT / "release" / "trailer" / "work_v6" / (
        "element_combo_states_en.log" if args.lang == "en" else "element_combo_states.log")
    direct_ids = {
        "rabbit_1": "h1", "rabbit_1_cell": "r5c1",
        "rabbit_2": "h4", "rabbit_2_cell": "r5c0",
        "rabbit_3": "h4", "rabbit_3_cell": "r5c2",
        "treant": "h2", "treant_cell": "r4c1",
        "earth": "h0", "earth_cell": "r4c0",
        "fire_wall": "h0", "fire_row": "h0", "fire_target": "r2c1",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    LOG.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()
    states = []

    def state(tag):
        txt = get("/state")
        states.append("\n===== %s %.2fs =====\n%s\n" % (tag, time.time() - t0, txt))
        return txt

    def act(tag, keyword, prefer=None, wait=1.0):
        txt = state("before_" + tag)
        target = direct_ids[tag] if args.lang == "en" else find_target(txt, keyword, prefer)
        if not target:
            raise RuntimeError("找不到目标：%s / %s" % (tag, keyword))
        rep = post("/act", {"target": target})
        print("%-14s target=%-8s ok=%s" % (tag, target, rep.get("ok")), flush=True)
        time.sleep(wait)
        state("after_" + tag)

    game_log = open(ROOT / ".trailer_game.log", "w", encoding="utf-8")
    cmd = [str(GODOT), "--path", str(ROOT),
           "--write-movie", str(OUT), "--fixed-fps", "30",
           "--quit-after", "3000", "--script", "res://tools/_manual_trailer_loadout.gd",
           "--", "--directed-record", "--ai-bridge=%d" % PORT]
    if args.lang == "en":
        cmd += ["--lang", "en", "--lang=en"]
    if args.clean:
        cmd += ["--trailer-clean"]
    t0 = time.time()
    proc = subprocess.Popen(cmd, cwd=str(ROOT), stdout=game_log, stderr=subprocess.STDOUT)
    try:
        for _ in range(200):
            if port_open():
                break
            if proc.poll() is not None:
                raise RuntimeError("游戏提前退出，请看 .trailer_game.log")
            time.sleep(0.2)
        else:
            raise RuntimeError("控制接口未启动")
        # autoload 的控制桥会先于 SceneTree 脚本监听；必须等到自定义手牌真正发好，
        # 不能把 battle_scene 默认开局误当成试验局。
        for _ in range(80):
            boot = state("waiting_custom_loadout")
            if "手牌 5" in boot and "牌库 0" in boot:
                break
            if proc.poll() is not None:
                raise RuntimeError("自定义手牌就绪前游戏退出")
            time.sleep(0.5)
        else:
            raise RuntimeError("等待自定义手牌超时")
        print("custom loadout ready %.1fs" % (time.time() - t0), flush=True)

        # 咒缚让第一张野兔 0 费；三张野兔（含两次复制）+ 0 费宠物鸭
        # 给土元素减 8 费 → 0 费入场，剩余 3 费正好接火墙术。
        act("rabbit_1", "选中手牌「野兔」", wait=0.6)
        act("rabbit_1_cell", "放到这里", "r5c1", wait=1.5)
        act("rabbit_2", "选中手牌「野兔」", wait=0.6)
        act("rabbit_2_cell", "放到这里", "r5c0", wait=1.5)
        act("rabbit_3", "选中手牌「野兔」", wait=0.6)
        act("rabbit_3_cell", "放到这里", "r5c2", wait=1.5)
        act("treant", "选中手牌「宠物鸭」", wait=0.6)
        act("treant_cell", "放到这里", "r4c1", wait=1.5)
        act("earth", "选中手牌「土元素」", wait=0.8)
        act("earth_cell", "放到这里", "r4c0", wait=3.0)
        act("fire_wall", "选中手牌「火墙术」", wait=0.8)
        act("fire_row", "再点一次 = 使用「火墙术」", wait=0.8)
        act("fire_target", "「火墙术」的目标格", "r2c1", wait=4.0)
        final = state("final")
        if args.lang == "zh":
            if "[我]土元素" not in final:
                raise RuntimeError("土元素未真正入场，请检查状态日志")
            if "火墙术（技能）" in final:
                raise RuntimeError("火墙术未真正打出，请检查状态日志")
        elif "手牌 2" not in final or "费用 0/5" not in final:
            raise RuntimeError("英文连携未完成：终态应为 2 张手牌、0 费用")

        print("actions done %.1fs" % (time.time() - t0), flush=True)
        proc.wait(timeout=180)
        print("done rc=%s seconds=%.1f size=%d" %
              (proc.returncode, time.time() - t0, OUT.stat().st_size if OUT.exists() else 0), flush=True)
        return proc.returncode
    finally:
        LOG.write_text("".join(states), encoding="utf-8")
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except Exception:
                proc.kill()
        game_log.close()


if __name__ == "__main__":
    raise SystemExit(main())
