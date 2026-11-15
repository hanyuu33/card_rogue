# -*- coding: utf-8 -*-
"""R761：「诗」6069 的道具小图标，委托 codex 图生图（复用 R562 管线）。

参考图 = `assets/ui/relic_icon_6052.png`（竖琴，同为吟游风格的乐器类小图标），
只借它的画风（粗深色描边 / 平涂 / 透明底），主体换成「卷轴 + 音符」。

用法：python _run_codex_icon.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_吟游诗人CG_R761")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")

REF = os.path.join(ROOT, "assets", "ui", "relic_icon_6052.png")
PROMPT = os.path.join(D, "icon_relic_6069.txt")
OUT = os.path.join(RAW, "icon_relic_6069.png")

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch_icon.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def proxy_ok() -> bool:
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    req = urllib.request.Request("https://chatgpt.com", headers={"User-Agent": "Mozilla/5.0"})
    try:
        with opener.open(req, timeout=20) as r:
            log("代理预检 HTTP %d" % r.status)
            return r.status < 500
    except urllib.error.HTTPError as e:
        log("代理预检 HTTP %d（链路通，目标站拒绝）" % e.code)
        return e.code < 500
    except Exception as e:  # noqa: BLE001
        log("代理预检失败 %s：%r" % (PROXY, e))
        return False


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
    if os.path.exists(OUT) and os.path.getsize(OUT) > 20000:
        log("SKIP（已有 %d 字节）" % os.path.getsize(OUT))
        return 0
    for p in (REF, PROMPT, CODEX_EXE):
        if not os.path.exists(p):
            log("MISS %s" % p)
            return 1
    if not proxy_ok():
        log("=== 代理不可用，中止")
        return 1

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN icon_relic_6069  参考=%s  第%d次" % (os.path.basename(REF), attempt))
        text = ""
        try:
            with open(PROMPT, "rb") as pin:
                proc = subprocess.run(
                    [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT,
                     "-i", REF],
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=1200, cwd=ROOT,
                    creationflags=0x08000000,
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT（%.0fs）" % (time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %r" % (e,))
        with open(os.path.join(D, "_log_icon_%d.jsonl" % attempt),
                  "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        src = pick_output(text)
        if src:
            os.makedirs(RAW, exist_ok=True)
            shutil.copyfile(src, OUT)
            log("OK  %.0fs  %d 字节" % (time.time() - t0, os.path.getsize(OUT)))
            return 0
        log("FAIL 第%d次没拿到图（%.0fs）" % (attempt, time.time() - t0))
    return 1


if __name__ == "__main__":
    sys.exit(main())
