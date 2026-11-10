# -*- coding: utf-8 -*-
"""R573 事件背景：委托 codex 出图（店长 2026-11-11 指定）。

复用 R562 的 codex 管线（代理 7897 / prompt 必须走 stdin / 从 JSONL 取图 / 重试 2 次），
但本轮 **不带 -i**：三张全部纯文生图，不参与图生图（用户口径「尽可能不要用这张参与图生图」）。

用法：
    python _run_codex.py              # 跑三张（已完成的自动跳过，可重跑）
    python _run_codex.py hero pear    # 只跑指定 kind
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_事件背景R573")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

JOBS = ["hero", "pear", "flyer"]

# R562 管线写死 7897；本机 Clash 端口可能变，允许环境变量覆盖。
PROXY = os.environ.get("CODEX_PROXY", m.PROXY)
m.PROXY = PROXY


def proxy_ok() -> bool:
    """真连一次 HTTPS 再开工：只测 CONNECT 会被「回 200 但不转发」的假代理骗过。
    只要拿到 HTTP 响应（含 401/403/404）就说明 CONNECT + TLS 全程打通；
    Cloudflare 会因默认 UA 回 403，所以补正常 UA，且 HTTPError 不算网络故障。"""
    import urllib.error
    import urllib.request
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    req = urllib.request.Request(
        "https://chatgpt.com", headers={"User-Agent": "Mozilla/5.0"})
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


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def progress(kind, ok):
    # 增量交付：每完成一张写一行，验收脚本按「已存在的 raw」动态拼页
    with open(os.path.join(D, "_progress.txt"), "a", encoding="utf-8", newline="\n") as f:
        f.write("%s\t%s\t%s\n" % (time.strftime("%H:%M:%S"), kind, "OK" if ok else "FAIL"))


def run_one(kind):
    dst = os.path.join(RAW, kind + "_codex.png")
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s（已有 %d KB）" % (kind, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(D, kind + ".txt")
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % kind)
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s  纯文生图(无参考图)  第%d次" % (kind, attempt))
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [m.CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=600, cwd=ROOT,
                    creationflags=0x08000000,
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT %s（%.0fs）" % (kind, time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %s %r" % (kind, e))
            text = ""
        with open(os.path.join(D, "_log_%s.jsonl" % kind), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

        src = m.pick_output(text)
        if src:
            shutil.copyfile(src, dst)
            log("OK   %s  <- %s  (%.0fs, %d KB)" % (
                kind, os.path.basename(src), time.time() - t0, os.path.getsize(dst) // 1024))
            progress(kind, True)
            return True
        log("FAIL %s 第%d次没有图（代理 %s 不通？）" % (kind, attempt, PROXY))
        time.sleep(3)
    progress(kind, False)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("代理 %s 不可用：先启动 Clash Verge（7897），或用 CODEX_PROXY=<host:port> 指定可用代理。本次不出图。" % PROXY)
        print("PROXY_DOWN", flush=True)
        return 1
    log("代理预检 OK：%s" % PROXY)
    only = set(sys.argv[1:]) or set(JOBS)
    done, fail = [], []
    for kind in JOBS:
        if kind not in only:
            continue
        (done if run_one(kind) else fail).append(kind)
    log("=== R573 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", done, " FAIL:", fail, flush=True)
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
