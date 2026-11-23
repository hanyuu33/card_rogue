# -*- coding: utf-8 -*-
"""R836 缺陷时钟「时针转动」动画素材：委托 codex 出**表盘**（无指针）。

为什么不要指针：指针要在动画里连续旋转（约一整圈 + 卡顿抖动），
贴图旋转会有像素偏移与描边锯齿 —— 指针用代码画（锥形金针 + 深褐描边 + 中心轴帽），
角度可以精确控制，和表盘刻度对得上。

复用 R761 管线（代理 7897 / prompt 走 stdin / JSONL 取图 / 重试 2 次 / 已存在即跳过）。
⚠️ 这次**不带参考图**：参考 `relic_icon_6084.png` 会把模型拽回「小怀表 + 提环」的构图，
而这里要的是正面正圆、无指针的空表盘。

用法：
    python _run_codex.py
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
D = os.path.join(ROOT, "art_src", "2026-11-20_缺陷时钟时针_R836")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
PROXY = os.environ.get("CODEX_PROXY", "http://127.0.0.1:7897")

JOBS = [
    ("face", ("clock_face.txt", "clock_face_v1.png")),
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


def run_one(prompt_name, out_name):
    dst = os.path.join(RAW, out_name)
    if os.path.exists(dst) and os.path.getsize(dst) > 30000:
        log("SKIP %s（已有 %d 字节）" % (out_name, os.path.getsize(dst)))
        return True
    prompt = os.path.join(D, "prompts", prompt_name)
    if not os.path.exists(prompt):
        log("MISS %s（没有 prompt）" % prompt_name)
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s  第%d次" % (out_name, attempt))
        text = ""
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT],
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=1200, cwd=ROOT,
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
    os.makedirs(RAW, exist_ok=True)
    if not proxy_ok():
        log("=== 代理不可用，中止（不开工，不留半成品）")
        return 1
    done, fail = [], []
    for k, (pname, oname) in JOBS:
        (done if run_one(pname, oname) else fail).append(k)
    log("=== R836 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))
    return 0 if not fail else 1


if __name__ == "__main__":
    sys.exit(main())
