# -*- coding: utf-8 -*-
"""R768 懊悔（9265）卡图：委托 codex 纯文生图，交通标志风格火柴人（3 候选）。

复用 R766 / R765 / R690 / R562 管线：代理 7897 / prompt 走 stdin / 从 JSONL 取图 /
重试 2 次 / 已有成品自动跳过。

用法：
    python _run_codex.py
    python _run_codex.py regret_a           # 只跑指定 key
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = r"E:\work\card_rogue"
D = os.path.join(ROOT, "art_src", "2026-11-16_诅咒火柴人_R768")
RAW = os.path.join(D, "raw")
PROMPTS = os.path.join(D, "prompts")
R562 = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")

spec = importlib.util.spec_from_file_location("r562", os.path.join(R562, "_run_batch.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

# v1（regret_a/b/c）= 带交通标志牌面的版本，店长退回：「只是要交通标志风格的
#   火柴人，不是要交通标志！」—— 牌子本身多余，留作参照，不再使用。
# v2 = 只留象形火柴人，背景统一深紫 #1B1420，四张诅咒卡成一套。
JOBS = [
    ("regret_v2", "regret_v2"),           # 9265 懊悔：跪地抱头
    ("flaw", "flaw_v1"),                  # 9154 破绽：站立，身体被青色裂缝劈开
    ("paralysis", "paralysis_v1"),        # 9185 麻痹：僵直后仰 + 三道黄闪电
    ("compensation", "compensation_v1"),  # 9252 代偿：弯腰背石头
]
PROXY = os.environ.get("CODEX_PROXY", m.PROXY)
m.PROXY = PROXY


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def progress(key, ok):
    with open(os.path.join(D, "_progress.txt"), "a", encoding="utf-8", newline="\n") as f:
        f.write("%s\t%s\t%s\n" % (time.strftime("%H:%M:%S"), key, "OK" if ok else "FAIL"))


def proxy_ok() -> bool:
    """预检只看「代理链路能不能到外网」，不挑具体站点。

    R768 踩过：原先拿 https://chatgpt.com 当探针，节点对 chatgpt 走不通时
    （SSL EOF / 000）预检直接判红，但 api.openai.com 明明能回 401 —— 是探针选错，
    不是代理挂了。现在按顺序试几个目标，**任何一个拿到 HTTP 响应就算通**
    （401/403 也算通：说明 TLS 握手与请求已经出去了）。
    """
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    probes = ["https://api.openai.com/v1/models", "https://chatgpt.com", "https://www.google.com"]
    for url in probes:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with opener.open(req, timeout=15) as r:
                log("代理预检 OK %s HTTP %d" % (url, r.status))
                return r.status < 500
        except urllib.error.HTTPError as e:
            log("代理预检 OK %s HTTP %d（链路通，目标站拒绝）" % (url, e.code))
            return e.code < 500
        except Exception as e:  # noqa: BLE001
            log("代理预检 %s 失败：%r" % (url, e))
    log("代理预检全部失败 %s" % PROXY)
    return False


def run_one(key, prompt_name):
    dst = os.path.join(RAW, "%s_codex.png" % key)
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s（已有 %d KB）" % (key, os.path.getsize(dst) // 1024))
        return True
    prompt = os.path.join(PROMPTS, "%s.txt" % prompt_name)
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
            progress(key, True)
            return True
        log("FAIL %s 第%d次没有图（代理 %s 不通？）" % (key, attempt, PROXY))
        time.sleep(3)
    progress(key, False)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("代理 %s 不可用：先启动 Clash Verge（7897），或用 CODEX_PROXY 指定。本次不出图。" % PROXY)
        print("PROXY_DOWN", flush=True)
        return 1
    log("代理预检 OK：%s" % PROXY)
    only = set(sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for key, pname in JOBS:
        if only and key not in only:
            continue
        (done if run_one(key, pname) else fail).append(key)
    log("=== R768 懊悔卡图结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    print("OK:", len(done), " FAIL:", fail, flush=True)
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
