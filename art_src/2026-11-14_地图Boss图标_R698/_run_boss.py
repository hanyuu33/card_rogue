# -*- coding: utf-8 -*-
"""R698 地图 Boss 房图标 —— codex 出图单张驱动。

沿用 R562 实测过的调用约定：
  · 必须显式指定代理 http://127.0.0.1:7897（环境自带沙箱代理连不上 chatgpt.com）。
  · prompt 从 stdin 喂。
  · 图落 ~/.codex/generated_images/<thread>/exec-*.png，从 JSONL 里解析后复制出来。

产物：raw/boss_v1.png（1024x1024），之后由 _prep_mapicon.py 压成 256x256 RGBA。
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
D = os.path.join(ROOT, "art_src", "2026-11-14_地图Boss图标_R698")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = "http://127.0.0.1:7897"
REF = os.path.join(ROOT, "assets", "ui", "map_icons", "elite.png")

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def pick_output(jsonl_text):
    hits = PAT.findall(jsonl_text.replace("\\\\", "\\"))
    for p in reversed(hits):
        p = p.replace("/", "\\")
        if os.path.exists(p):
            return p
    m = re.search(r'"thread_id"\s*:\s*"([0-9a-f-]+)"', jsonl_text)
    if m:
        d = os.path.join(GEN, m.group(1))
        if os.path.isdir(d):
            pngs = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def main():
    tag = sys.argv[1] if len(sys.argv) > 1 else "boss_v1"
    pname = sys.argv[2] if len(sys.argv) > 2 else "boss"
    prompt_path = os.path.join(D, pname + ".txt")
    dst = os.path.join(RAW, tag + ".png")
    os.makedirs(RAW, exist_ok=True)

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    t0 = time.time()
    log("RUN  %s  参考=%s" % (tag, os.path.basename(REF)))
    with open(prompt_path, "rb") as pin:
        proc = subprocess.run(
            [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT, "-i", REF],
            stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, timeout=900, cwd=ROOT,
            creationflags=0x08000000,
        )
    text = proc.stdout.decode("utf-8", "replace")
    with open(os.path.join(D, "_log_%s.jsonl" % tag), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

    src = pick_output(text)
    if not src:
        log("FAIL %s 没有拿到图（%.0fs）" % (tag, time.time() - t0))
        print(text[-2000:])
        return 2
    shutil.copyfile(src, dst)
    log("OK   %s <- %s (%.0fs, %d KB)" % (tag, os.path.basename(src), time.time() - t0,
                                          os.path.getsize(dst) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
