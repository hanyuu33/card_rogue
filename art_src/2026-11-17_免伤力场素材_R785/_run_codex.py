# -*- coding: utf-8 -*-
"""R785 免伤力场：委托 codex 纯文生图，出「环绕卡牌的金色结界光环」素材。

管线复用 R628 独行特效（`art_src/2026-11-12_独行特效_R628/_run_codex.py`）
→ 再复用 R562 机械之心批量出图（`_run_batch.py`）：代理 7897 / prompt 走 stdin /
从 JSONL 取图 / 重试 2 次 / 逐张落盘、可重跑跳过。

⚠️ 两个坑（R785 首跑踩过，都已在这里处理）：
  1. **必须清掉 WorkBuddy 注入的 http_proxy(127.0.0.1:59266)** —— 那是白名单代理，
     走它访问 chatgpt.com 一律超时，表现为「codex 静默卡十几分钟一个字不吐」。
     只保留 Clash 的 7897，并先做代理预检。
  2. **prompt 走 stdin，别用参数**、且 stdin 必须能被关闭；用 `-c model_reasoning_effort=low`
     让模型别在规划上磨时间（出图本身才是耗时大头）。

用法：
    python _run_codex.py                  # 跑全部 3 张（已有成品自动跳过）
    python _run_codex.py cap_aura_02      # 只跑指定 key
    CODEX_PROXY=http://127.0.0.1:7897 python _run_codex.py
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-17_免伤力场素材_R785")
RAW = os.path.join(D, "raw")
PROMPTS = os.path.join(D, "prompts")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

JOBS = ["cap_aura_01", "cap_aura_02", "cap_aura_03"]
PROXY = os.environ.get("CODEX_PROXY", m.PROXY)
m.PROXY = PROXY


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def progress(key, ok):
    """增量交付：每完成一张写一行，验收页按「已存在的 raw」动态拼。"""
    with open(os.path.join(D, "_progress.txt"), "a", encoding="utf-8", newline="\n") as f:
        f.write("%s\t%s\t%s\n" % (time.strftime("%H:%M:%S"), key, "OK" if ok else "FAIL"))


def proxy_ok() -> bool:
    import urllib.error
    import urllib.request
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


def run_one(key):
    dst = os.path.join(RAW, "%s.png" % key)
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s（已有 %d KB）" % (key, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(PROMPTS, "%s.txt" % key)
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % key)
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY",
              "ALL_PROXY", "all_proxy", "NO_PROXY", "no_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s  纯文生图(无参考图, 黑底)  第%d次" % (key, attempt))
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [m.CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT,
                     "-c", "model_reasoning_effort=low"],
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
            progress(key, True)
            return True
        log("FAIL %s 第%d次没有图（代理 %s 不通？）" % (key, attempt, PROXY))
        time.sleep(3)
    progress(key, False)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    todo = [k for k in JOBS if not only or k in only]
    need = [k for k in todo
            if not (os.path.exists(os.path.join(RAW, "%s.png" % k))
                    and os.path.getsize(os.path.join(RAW, "%s.png" % k)) > 50000)]
    if need and not proxy_ok():
        log("代理 %s 不可用：先启动 Clash Verge（7897），或用 CODEX_PROXY 指定。本次不出图。" % PROXY)
        print("PROXY_DOWN", flush=True)
        return 1
    done, fail = [], []
    for key in todo:
        (done if run_one(key) else fail).append(key)
    log("=== R785 免伤力场素材结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", len(done), " FAIL:", fail, flush=True)
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
