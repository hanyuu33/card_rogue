# -*- coding: utf-8 -*-
"""R843e: delegate integrated class art+rarity frames to Codex image generation."""
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
D = os.path.join(ROOT, "art_src", "2026-11-20_card_face_redesign", "codex_frames")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = "http://127.0.0.1:7897"
PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def pick_output(text):
    hits = PAT.findall(text.replace("\\\\", "\\"))
    for path in reversed(hits):
        path = path.replace("/", "\\")
        if os.path.exists(path):
            return path
    match = re.search(r'"thread_id"\s*:\s*"([0-9a-f-]+)"', text)
    if match:
        folder = os.path.join(GEN, match.group(1))
        if os.path.isdir(folder):
            pngs = [os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def main():
    kind = sys.argv[1] if len(sys.argv) > 1 else "forest"
    prompt_path = os.path.join(D, "prompts", kind + ".txt")
    dst = os.path.join(RAW, kind + ".png")
    if not os.path.exists(prompt_path):
        log("FAIL prompt missing: " + prompt_path)
        return 2
    before = set()
    if os.path.isdir(GEN):
        for base, _dirs, files in os.walk(GEN):
            for name in files:
                if name.endswith(".png"):
                    before.add(os.path.join(base, name))
    env = dict(os.environ)
    for key in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(key, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = PROXY
    env["https_proxy"] = env["http_proxy"] = PROXY
    started = time.time()
    log("RUN " + kind)
    with open(prompt_path, "rb") as source:
        proc = subprocess.run(
            [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
            stdin=source, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            env=env, timeout=1800, cwd=ROOT, creationflags=0x08000000)
    text = proc.stdout.decode("utf-8", "replace")
    with open(os.path.join(D, "_log_" + kind + ".jsonl"), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    src = pick_output(text)
    if not src:
        after = []
        if os.path.isdir(GEN):
            for base, _dirs, files in os.walk(GEN):
                for name in files:
                    path = os.path.join(base, name)
                    if name.endswith(".png") and path not in before:
                        after.append(path)
        if after:
            src = max(after, key=os.path.getmtime)
    if not src:
        log("FAIL %s no image (%.0fs)" % (kind, time.time() - started))
        print(text[-3000:])
        return 2
    shutil.copyfile(src, dst)
    from PIL import Image
    im = Image.open(dst)
    log("OK %s <- %s (%.0fs, %s, %d KB)" % (
        kind, os.path.basename(src), time.time() - started, im.size,
        os.path.getsize(dst) // 1024))
    return 0


if __name__ == "__main__":
    sys.exit(main())
