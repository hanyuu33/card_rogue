# -*- coding: utf-8 -*-
"""R842 素材出图驱动（纯文生图）：事件插图 / 道具图标 6090 共用。

与 R839b 大蒜图标同一套骨架：prompt 走 stdin，图落 `~/.codex/generated_images/<thread>/`，
**必须由本脚本抄到 raw/**（不抄就随 thread 目录被清掉）。

用法：python _run_slab.py [tag]
"""
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
D = os.path.join(ROOT, "art_src", "2026-11-20_龙石板_R842")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = "http://127.0.0.1:7897"
TAG = sys.argv[1] if len(sys.argv) > 1 else "event_dragon_slab"

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


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
        d = os.path.join(GEN, m.group(1))
        if os.path.isdir(d):
            pngs = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def main():
    prompt_path = os.path.join(D, "prompts", TAG + ".txt")
    dst = os.path.join(RAW, TAG + ".png")
    if not os.path.exists(prompt_path):
        log("FAIL prompt 不存在：%s" % prompt_path)
        return 2
    os.makedirs(RAW, exist_ok=True)

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
    log("RUN  %s（纯文生图，无参考图）" % TAG)
    with open(prompt_path, "rb") as pin:
        proc = subprocess.run(
            [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
            stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, timeout=900)
    text = proc.stdout.decode("utf-8", "replace")
    with open(os.path.join(D, "_log_%s.jsonl" % TAG), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    log("EXIT %d  用时 %.0fs" % (proc.returncode, time.time() - t0))

    src = pick_output(text)
    if src is None:
        after = []
        if os.path.isdir(GEN):
            for root_, _dirs, files in os.walk(GEN):
                for f in files:
                    p = os.path.join(root_, f)
                    if f.endswith(".png") and p not in before:
                        after.append(p)
        after.sort(key=os.path.getmtime)
        src = after[-1] if after else None
    if src is None:
        log("FAIL 没找到产出图")
        return 3
    shutil.copy2(src, dst)
    log("OK   %s -> %s" % (src, dst))
    return 0


if __name__ == "__main__":
    sys.exit(main())
