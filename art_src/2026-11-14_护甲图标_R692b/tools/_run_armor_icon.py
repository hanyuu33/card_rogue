# -*- coding: utf-8 -*-
"""R692b 护甲图标（卡面「生命值正上方」那颗）—— codex 图生图单张驱动。

为什么单独一张也要脚本：codex 单张 2~4 分钟，且沙箱内拷不出文件，
只回报 ~/.codex/generated_images/<thread>/exec-*.png，必须解析 JSONL 再由外部复制。

用法：python art_src/2026-11-14_护甲图标_R692b/tools/_run_armor_icon.py [v1 v2 ...]
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

D = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(D))
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = "http://127.0.0.1:7897"
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
REF = os.path.join(ROOT, "assets", "ui", "affix_shield.png")   # 同风格的蓝盾，只借画风
PAT = re.compile(r"[\w:/\\.\-]+?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def pick_output(text):
    hits = PAT.findall(text.replace("\\\\", "\\"))
    for p in reversed(hits):
        p = p.replace("/", "\\")
        if os.path.exists(p):
            return p
    m = re.search(r'"thread_id"\s*:\s*"([0-9a-f-]+)"', text)
    if m:
        dd = os.path.join(GEN, m.group(1))
        if os.path.isdir(dd):
            pngs = [os.path.join(dd, f) for f in os.listdir(dd) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def run(tag):
    dst = os.path.join(RAW, "affix_armor_%s.png" % tag)
    prompt_path = os.path.join(D, "prompts", "armor_%s.txt" % tag)
    if not os.path.exists(prompt_path):
        log("MISS %s（没有 prompt）" % tag)
        return False
    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY
    t0 = time.time()
    log("RUN  armor %s  参考=%s" % (tag, os.path.basename(REF)))
    with open(prompt_path, "rb") as pin:
        proc = subprocess.run(
            [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT, "-i", REF],
            stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, timeout=900, cwd=ROOT,
            creationflags=0x08000000,   # CREATE_NO_WINDOW
        )
    text = proc.stdout.decode("utf-8", "replace")
    with open(os.path.join(D, "_log_%s.jsonl" % tag), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    src = pick_output(text)
    if not src:
        log("FAIL %s（%.0fs）没有图" % (tag, time.time() - t0))
        return False
    shutil.copyfile(src, dst)
    log("OK   %s <- %s (%.0fs, %d KB)" % (tag, os.path.basename(src),
                                          time.time() - t0, os.path.getsize(dst) // 1024))
    return True


if __name__ == "__main__":
    os.makedirs(RAW, exist_ok=True)
    tags = sys.argv[1:] or ["v1"]
    ok = all(run(t) for t in tags)
    sys.exit(0 if ok else 1)
