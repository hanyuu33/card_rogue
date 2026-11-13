# -*- coding: utf-8 -*-
"""R660 首次语言选择：委托 codex 纯文生图（1 张 16:9 氛围背景）。

复用 R645 / R562 管线：代理 7897 / prompt 走 stdin / 从 JSONL 取图 / 重试 2 次。
用法：
    python _run_codex.py
    CODEX_PROXY=http://127.0.0.1:7897 python _run_codex.py
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-13_语言选择_R660")
RAW = os.path.join(D, "raw")
PROMPTS = os.path.join(D, "prompts")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

PROXY = os.environ.get("CODEX_PROXY", m.PROXY)
m.PROXY = PROXY


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def proxy_ok() -> bool:
    import urllib.error
    import urllib.request
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    req = urllib.request.Request("https://chatgpt.com", headers={"User-Agent": "Mozilla/5.0"})
    try:
        with opener.open(req, timeout=15) as r:
            log("代理预检 HTTP %d" % r.status)
            return r.status < 500
    except urllib.error.HTTPError as e:
        log("代理预检 HTTP %d（链路通，目标站拒绝）" % e.code)
        return e.code < 500
    except Exception as e:  # noqa: BLE001
        log("代理预检失败 %s：%r" % (PROXY, e))
        return False


def run_one(key):
    dst = os.path.join(RAW, "%s_codex.png" % key)
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s（已有 %d KB）" % (key, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(PROMPTS, "%s.txt" % key)
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % key)
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s  纯文生图(无参考图)  第%d次" % (key, attempt))
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [m.CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=900, cwd=ROOT,
                    creationflags=0x08000000,
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT %s（%.0fs）" % (key, time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %s %r" % (key, e))
            text = ""
        with open(os.path.join(D, "_log_%s.jsonl" % key), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

        src = m.pick_output(text)
        if src:
            shutil.copyfile(src, dst)
            log("OK   %s  <- %s  (%.0fs, %d KB)" % (
                key, os.path.basename(src), time.time() - t0, os.path.getsize(dst) // 1024))
            return True
        log("FAIL %s 第%d次没有图（代理 %s 不通？）" % (key, attempt, PROXY))
        time.sleep(3)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("代理 %s 不可用：先启动 Clash Verge（7897），或用 CODEX_PROXY 指定。" % PROXY)
        print("PROXY_DOWN", flush=True)
        return 1
    ok = run_one("lang_bg")
    log("=== R660 语言选择背景结束：%s" % ("OK" if ok else "FAIL"))
    print("OK" if ok else "FAIL", flush=True)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
