# -*- coding: utf-8 -*-
"""R823：一枚返回按钮底，codex 图生图；prompt 走 stdin，成图由本脚本抄出。"""
import os
import re
import shutil
import subprocess
import time

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-19_存档返回按钮_R823")
RAW = os.path.join(D, "raw")
DST = os.path.join(RAW, "return_button_v1.png")
PROMPT = os.path.join(D, "return_button.txt")
REF = os.path.join(ROOT, "assets", "ui", "adventure_shared", "button_paper.png")
GEN = os.path.expanduser(r"~\.codex\generated_images")
CODEX = os.path.expanduser(r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor\x86_64-pc-windows-msvc\bin\codex.exe")
PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(text):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), text)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def pick_output(text):
    hits = PAT.findall(text.replace("\\\\", "\\"))
    for path in reversed(hits):
        path = path.replace("/", "\\")
        if os.path.exists(path):
            return path
    m = re.search(r'"thread_id"\s*:\s*"([0-9a-f-]+)"', text)
    if m:
        folder = os.path.join(GEN, m.group(1))
        if os.path.isdir(folder):
            pngs = [os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def main():
    os.makedirs(RAW, exist_ok=True)
    if os.path.exists(DST) and os.path.getsize(DST) > 10000:
        log("SKIP 已有成图 %d 字节" % os.path.getsize(DST))
        return 0
    env = dict(os.environ)
    proxy = "http://127.0.0.1:7897"
    for key in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(key, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = proxy
    env["https_proxy"] = env["http_proxy"] = proxy
    started = time.time()
    log("RUN return_button_v1")
    with open(PROMPT, "rb") as pin:
        proc = subprocess.run(
            [CODEX, "exec", "--json", "--skip-git-repo-check", "-C", ROOT, "-i", REF],
            stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, timeout=1200, cwd=ROOT, creationflags=0x08000000)
    text = proc.stdout.decode("utf-8", "replace")
    with open(os.path.join(D, "_log_return_button_v1.jsonl"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    src = pick_output(text)
    if not src:
        log("FAIL 没拿到图，耗时 %.0fs" % (time.time() - started))
        return 1
    shutil.copyfile(src, DST)
    log("OK %s %.0fs %d 字节" % (DST, time.time() - started, os.path.getsize(DST)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
