# -*- coding: utf-8 -*-
"""录制由玩家亲自操作的指定手牌试验局。

    python -u tools/trailer_record_manual.py

与 trailer_record_loadout.py 不同：这里不启动控制桥、不替玩家点击，也没有
--quit-after。Movie Maker 从进程启动就持续写入；玩家关闭窗口后才封装并验收。
"""
import argparse
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = Path(os.environ.get(
    "CARD_ROGUE_GODOT",
    str(Path.home() / ".workbuddy/binaries/godot/Godot_v4.3-stable_win64.exe"),
))
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
FFPROBE = os.environ.get("FFPROBE", "ffprobe")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", choices=["zh", "en"], default="zh")
    ap.add_argument("--out", default="")
    # R764：`--clean` = 宣传录制模式，压掉战斗内仍是中文的说明文字
    # （状态栏提示 / 说明类飘字 / 左栏卡牌详情），只保留卡面、血量与伤害数字。
    ap.add_argument("--clean", action="store_true")
    args = ap.parse_args()
    name = args.out or ("seg_manual_loadout_%s.avi" % args.lang)
    out = ROOT / "release" / "trailer" / "raw" / name
    work = ROOT / "release" / "trailer" / "work_v6"
    out.parent.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    if out.exists():
        raise SystemExit("拒绝覆盖已有素材：%s（请用 --out 换新文件名）" % out)
    log_path = work / ("manual_loadout_%s.log" % args.lang)
    cmd = [str(GODOT), "--path", str(ROOT),
           "--write-movie", str(out), "--fixed-fps", "30",
           "--script", "res://tools/_manual_trailer_loadout.gd"]
    # `--lang=<x>` 必须走等号形式：GameSettings 在 autoload 初始化时就读它，
    # 早于 battle_scene._ready 给顶栏按钮（记录 / 完整卡组 / 回合结束）赋值。
    # 只传分开形式时那些按钮会留在上次语言 —— 英文素材上挂一排中文。
    cmd += ["--", "--lang", args.lang, "--lang=%s" % args.lang]
    if args.clean:
        cmd += ["--trailer-clean"]
    print("RECORDING=%s" % out, flush=True)
    print("CONTROL=human; AI_BRIDGE=off; close the game window to finish", flush=True)
    with open(log_path, "w", encoding="utf-8") as log:
        proc = subprocess.Popen(cmd, cwd=str(ROOT), stdout=log, stderr=subprocess.STDOUT)
        rc = proc.wait()
    print("WINDOW_CLOSED rc=%d" % rc, flush=True)
    if rc != 0:
        print("RECORD_FAIL log=%s" % log_path, flush=True)
        return rc
    if not out.exists() or out.stat().st_size < 1024 * 1024:
        print("RECORD_FAIL missing_or_tiny=%s log=%s" % (out, log_path), flush=True)
        return 2
    subprocess.run([FFPROBE, "-v", "error", "-show_entries",
                    "format=duration,size:stream=codec_type,codec_name,width,height,r_frame_rate",
                    "-of", "json", str(out)], check=True)
    subprocess.run([FFMPEG, "-v", "error", "-i", str(out), "-f", "null", "-"], check=True)
    print("RECORD_OK path=%s bytes=%d" % (out, out.stat().st_size), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
