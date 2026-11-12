# -*- coding: utf-8 -*-
"""R577b 道具图标：委托 codex 批量纯文生图（店长 2026-11-11 指定）。

复用 R562 管线（代理 7897 / prompt 走 stdin / 从 JSONL 取图 / 重试 2 次），
沿用 R573 的代理预检、进度逐张落盘、可重跑跳过。

用法：
    python _run_codex.py                 # 跑全部 63 张（已有成品自动跳过）
    python _run_codex.py 6001 6027      # 只跑指定 id（探针用）
    CODEX_PROXY=http://127.0.0.1:7897 python _run_codex.py
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-11_道具图标_R577")
RAW = os.path.join(D, "raw")
PROMPTS = os.path.join(D, "prompts")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

# 60 件 relics.json 道具；6061~6063 三样信物已有 key_icon_*.png（R543），不重出。
JOBS = list(range(6001, 6061)) + [6064, 6065]  # R586 正义背刺 / R593 机械臂
PROXY = os.environ.get("CODEX_PROXY", m.PROXY)
m.PROXY = PROXY


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def progress(cid, ok):
    """增量交付：每完成一张写一行，验收脚本按「已存在的 raw」动态拼页。"""
    with open(os.path.join(D, "_progress.txt"), "a", encoding="utf-8", newline="\n") as f:
        f.write("%s\t%d\t%s\n" % (time.strftime("%H:%M:%S"), cid, "OK" if ok else "FAIL"))


def proxy_ok() -> bool:
    """真连 HTTPS；HTTPError(403) 也算链路通（Cloudflare 挡 Python 默认 UA）。"""
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


def run_one(cid):
    dst = os.path.join(RAW, "%d_codex.png" % cid)
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %d（已有 %d KB）" % (cid, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(PROMPTS, "%d.txt" % cid)
    if not os.path.exists(prompt):
        log("MISS %d（没有 prompt）" % cid)
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %d  纯文生图(无参考图)  第%d次" % (cid, attempt))
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
            log("TIMEOUT %d（%.0fs）" % (cid, time.time() - t0))
        except Exception as e:  # noqa: BLE001
            log("ERROR %d %r" % (cid, e))
            text = ""
        with open(os.path.join(D, "_log_%d.jsonl" % cid), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

        src = m.pick_output(text)
        if src:
            shutil.copyfile(src, dst)
            log("OK   %d  <- %s  (%.0fs, %d KB)" % (
                cid, os.path.basename(src), time.time() - t0, os.path.getsize(dst) // 1024))
            progress(cid, True)
            return True
        log("FAIL %d 第%d次没有图（代理 %s 不通？）" % (cid, attempt, PROXY))
        time.sleep(3)
    progress(cid, False)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("代理 %s 不可用：先启动 Clash Verge（7897），或用 CODEX_PROXY 指定。本次不出图。" % PROXY)
        print("PROXY_DOWN", flush=True)
        return 1
    log("代理预检 OK：%s" % PROXY)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid in JOBS:
        if only and cid not in only:
            continue
        (done if run_one(cid) else fail).append(cid)
    log("=== R577b 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", len(done), " FAIL:", fail, flush=True)
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
