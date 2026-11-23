# -*- coding: utf-8 -*-
"""R824 鸭子闹钟（6085）道具图标：委托 codex 出 1024 方图，再抠成 128×128。

复用 R761 / R819 管线（代理 7897 / prompt 走 stdin / JSONL 取图 / 重试 2 次 / 已存在即跳过）。
参考图只喂一张 `assets/ui/relic_icon_6018.png`（生蛋鸭）—— 目的是让「鸭子的脸、橙扁嘴、
大圆眼 + 白高光」这套画法与既有道具图标一致；钟的形状靠文字写死，不让参考图传染。

用法：
    python _run_codex.py            # 全部 jobs
    python _run_codex.py v1         # 只跑某一版
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
D = os.path.join(ROOT, "art_src", "2026-11-19_鸭子闹钟图标_R824")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")

# key -> (prompt 文件, 输出文件名, 参考图列表)
JOBS = [
    ("v1", ("6085_鸭子闹钟.txt", "icon_duck_alarm_v1.png", ["assets/ui/relic_icon_6018.png"])),
]

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
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


def run_one(prompt_name, out_name, refs=()):
    dst = os.path.join(RAW, out_name)
    if os.path.exists(dst) and os.path.getsize(dst) > 30000:
        log("SKIP %s（已有 %d 字节）" % (out_name, os.path.getsize(dst)))
        return True
    prompt = os.path.join(D, "prompts", prompt_name)
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % prompt_name)
        return False
    ref_args = []
    for r in refs:
        p = os.path.join(ROOT, r)
        if not os.path.exists(p):
            log("MISS 参考图 %s" % p)
            return False
        ref_args += ["-i", p]

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s  %s  第%d次" % (
            out_name, ("带参考图×%d" % len(refs)) if refs else "纯文生图", attempt))
        text = ""
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT] + ref_args,
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=1800, cwd=ROOT,
                    creationflags=0x08000000,   # CREATE_NO_WINDOW
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT %s（%.0fs）" % (out_name, time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %s %r" % (out_name, e))
        with open(os.path.join(D, "_log_%s_%d.jsonl" % (os.path.splitext(out_name)[0], attempt)),
                  "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        src = pick_output(text)
        if src:
            os.makedirs(RAW, exist_ok=True)
            shutil.copyfile(src, dst)
            log("OK   %s  %.0fs  %d 字节" % (out_name, time.time() - t0, os.path.getsize(dst)))
            return True
        log("FAIL %s  第%d次没拿到图（%.0fs）" % (out_name, attempt, time.time() - t0))
    return False


def main():
    keys = [a.strip().lower() for a in sys.argv[1:]] or [k for k, _ in JOBS]
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("=== 代理不可用，中止（不开工，不留半成品）")
        return 1
    done, fail = [], []
    for k, (pname, oname, refs) in JOBS:
        if k not in keys:
            continue
        (done if run_one(pname, oname, refs) else fail).append(k)
    log("=== R824 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
