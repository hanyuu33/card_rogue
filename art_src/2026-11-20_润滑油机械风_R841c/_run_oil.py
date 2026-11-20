# -*- coding: utf-8 -*-
"""R841c 润滑油 7019 机械风格重出：codex exec 出图驱动（纯文生图，无参考图）。

单物件图标不喂参考图 —— ART.md 记的 R339 / R407：画风不对时优先摘参照图纯文生图，
喂旧图只会把旧图的问题一起锁死（这里正是要扔掉上一版的「玻璃瓶」造型）。

用法：python _run_oil.py 7019_油壶机械 7019_oil_mech
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
D = os.path.join(ROOT, "art_src", "2026-11-20_润滑油机械风_R841c")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = "http://127.0.0.1:7897"

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
    tag = sys.argv[1] if len(sys.argv) > 1 else "7019_油壶机械"
    stem = sys.argv[2] if len(sys.argv) > 2 else "7019_oil_mech"
    prompt_path = os.path.join(D, "prompts", stem + ".txt")
    dst = os.path.join(RAW, tag + ".png")
    os.makedirs(RAW, exist_ok=True)

    if not os.path.exists(prompt_path):
        log("FAIL prompt 不存在：%s" % prompt_path)
        return 2

    before = set()
    if os.path.isdir(GEN):
        for root_, _dirs, files in os.walk(GEN):
            for f in files:
                if f.endswith(".png"):
                    before.add(os.path.join(root_, f))

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    t0 = time.time()
    log("RUN  %s  prompt=%s（纯文生图，无参考图）" % (tag, stem))
    with open(prompt_path, "rb") as pin:
        proc = subprocess.run(
            [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
            stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, timeout=1800, cwd=ROOT,
            creationflags=0x08000000,
        )
    text = proc.stdout.decode("utf-8", "replace")
    with open(os.path.join(D, "_log_%s.jsonl" % tag), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

    src = pick_output(text)
    if not src:
        after = []
        if os.path.isdir(GEN):
            for root_, _dirs, files in os.walk(GEN):
                for f in files:
                    p = os.path.join(root_, f)
                    if f.endswith(".png") and p not in before:
                        after.append(p)
        if after:
            src = max(after, key=os.path.getmtime)
    if not src:
        log("FAIL %s 没有拿到图（%.0fs）" % (tag, time.time() - t0))
        print(text[-2000:])
        return 2

    shutil.copyfile(src, dst)
    from PIL import Image
    im = Image.open(dst)
    log("OK   %s <- %s (%.0fs, %s, %d KB)" % (tag, os.path.basename(src), time.time() - t0,
                                              im.size, os.path.getsize(dst) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
