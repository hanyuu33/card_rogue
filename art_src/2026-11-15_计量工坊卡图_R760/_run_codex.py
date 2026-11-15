# -*- coding: utf-8 -*-
"""R760 计量工坊三只单位卡图：委托 codex 图生图（参考 8073 画风，不抄内容）。

复用 R562 管线（代理 7897 / prompt 走 stdin / JSONL 取图 / 重试 2 次 / 已存在即跳过）。
每完成一张立刻跑 _finish.py 重拼验收页（增量交付，店长 2026-11-11 口径）。

用法：
    python _run_codex.py            # 三张都跑
    python _run_codex.py 9261       # 只跑 9261
    python _run_codex.py 9261 9262  # 跑指定几张
"""
import importlib.util
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_计量工坊卡图_R760")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")
m.PROXY = PROXY

# 画风参考：8073 聚能机兵（机械之心 · 本单位）。只借画法，不抄内容。
REF = os.path.join(ROOT, "assets", "pics", "_pending", "8073.png")

JOBS = [
    (9260, "常数测量员", REF),
    (9261, "精密计算者", REF),
    (9262, "负载增量员", REF),
]


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


def preview(ver="v1"):
    """增量交付：每出一张就按 448x404 口径重拼验收页。"""
    try:
        out = subprocess.run([sys.executable, os.path.join(D, "_finish.py")]
                             + (["--v2"] if ver == "v2" else []),
                             cwd=D, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log((out.stdout or b"").decode("utf-8", "replace").strip()[-600:])
    except Exception as e:  # noqa: BLE001
        log("PREVIEW ERROR %r" % e)


def main():
    ver = "v2" if "--v2" in sys.argv else "v1"
    want = [int(a) for a in sys.argv[1:] if a.startswith("9")]
    jobs = [j for j in JOBS if not want or j[0] in want]
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("=== 代理不可用，中止（不开工，不留半成品）")
        return
    done, fail = [], []
    for cid, name, ref in jobs:
        ok = m.run_one(cid, name, ref, "_" + ver)
        (done if ok else fail).append(cid)
        preview(ver)
    log("=== R760 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))


if __name__ == "__main__":
    main()
