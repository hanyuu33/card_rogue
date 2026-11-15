# -*- coding: utf-8 -*-
"""R759 代偿 9252 卡图：委托 codex 纯文生图，两个方案（v1 重压 / v2 加价）。

复用 R562 管线（代理 7897 / prompt 走 stdin / JSONL 取图 / 重试 2 次 / 已存在即跳过）。
每完成一张立刻跑 _preview.py 重拼对比页（增量交付，店长 2026-11-11 口径）。

用法：
    python _run_codex.py            # 两个方案都跑
    python _run_codex.py v1         # 只跑 v1
"""
import importlib.util
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-15_代偿卡图_R759")
RAW = os.path.join(D, "raw")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
m.D = D
m.RAW = RAW

PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")
m.PROXY = PROXY

TAGS = ["_v1", "_v2"]


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


def preview():
    """增量交付：每出一张就按 448x404 口径重拼验收页（不再用 403 的旧脚本）。"""
    try:
        out = subprocess.run([sys.executable, os.path.join(D, "_finish.py")],
                             cwd=D, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log((out.stdout or b"").decode("utf-8", "replace").strip()[-400:])
    except Exception as e:  # noqa: BLE001
        log("PREVIEW ERROR %r" % e)


def main():
    only = [t if t.startswith("_") else "_" + t for t in sys.argv[1:]] or TAGS
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("=== 代理不可用，中止（不开工，不留半成品）")
        return
    done, fail = [], []
    for tag in only:
        ok = m.run_one(9252, "代偿", None, tag)
        (done if ok else fail).append(tag)
        preview()
    log("=== R759 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))


if __name__ == "__main__":
    main()
