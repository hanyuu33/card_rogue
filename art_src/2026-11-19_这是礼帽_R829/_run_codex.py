# -*- coding: utf-8 -*-
"""R829 这是礼帽图标：委托 codex 出 1024 方图（店长 2026-11-19 指定）。

复用 R824 管线（代理 7897 / prompt 走 stdin / JSONL 取图 / 重试 2 次 / 已存在跳过）。
1 个 job 纯文生图（不喂参考图）。

用法：
    python _run_codex.py            # 跑全部 8 张
    python _run_codex.py icon       # 只跑图标（探针）
    python _run_codex.py do re mi fa sol la si
"""
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-19_这是礼帽_R829")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")

JOBS = [
    ("icon", "6087_这是礼帽.txt", "icon_6087.png"),
]

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def proxy_ok():
    # 用 curl 检测（TLS 栈比 Python ssl 稳，避免节点抖动时 urllib 握手误判）
    curl = shutil.which("curl")
    for i in (1, 2, 3):
        if curl:
            try:
                r = subprocess.run(
                    [curl, "-sS", "-m", "25", "-x", PROXY, "-o", os.devnull,
                     "-w", "%{http_code}", "https://chatgpt.com"],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=35,
                    creationflags=0x08000000,
                )
                code = r.stdout.decode("utf-8", "replace").strip()
                log("代理预检(curl) 第%d次 HTTP %s" % (i, code or "000"))
                if code.isdigit() and int(code) < 500:
                    return True
            except Exception as e:  # noqa: BLE001
                log("代理预检(curl) 第%d次失败 %r" % (i, e))
        else:
            try:
                opener = urllib.request.build_opener(
                    urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
                req = urllib.request.Request("https://api.openai.com/v1/models",
                                             headers={"User-Agent": "Mozilla/5.0"})
                with opener.open(req, timeout=20) as r:
                    log("代理预检 HTTP %d（链路通）" % r.status)
                    return r.status < 500
            except urllib.error.HTTPError as e:
                log("代理预检 HTTP %d（链路通，目标站拒绝）" % e.code)
                return e.code < 500
            except Exception as e:  # noqa: BLE001
                log("代理预检失败 %s：%r" % (PROXY, e))
        time.sleep(5)
    log("代理预检 3 次均未通过")
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


def run_one(key, pname, oname):
    dst = os.path.join(RAW, oname)
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s（已有 %d KB）" % (oname, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(D, "prompts", pname)
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % pname)
        return False
    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN %s 纯文生图 第%d次" % (oname, attempt))
        text = ""
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=1800, cwd=ROOT,
                    creationflags=0x08000000,
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT %s（%.0fs）" % (oname, time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %s %r" % (oname, e))
        with open(os.path.join(D, "_log_%s_%d.jsonl" % (key, attempt)),
                  "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        src = pick_output(text)
        if src:
            os.makedirs(RAW, exist_ok=True)
            shutil.copyfile(src, dst)
            log("OK %s %.0fs %d KB" % (oname, time.time() - t0, os.path.getsize(dst) // 1024))
            return True
        log("FAIL %s 第%d次没拿到图" % (oname, attempt))
        time.sleep(3)
    return False


def main():
    keys = [a.strip().lower() for a in sys.argv[1:]]
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("=== 预检未通过，仍继续尝试 codex（预检可能误判，codex 自带超时与重试）")
    done, fail = [], []
    for key, pname, oname in JOBS:
        if keys and key not in keys:
            continue
        (done if run_one(key, pname, oname) else fail).append(key)
    log("=== 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
