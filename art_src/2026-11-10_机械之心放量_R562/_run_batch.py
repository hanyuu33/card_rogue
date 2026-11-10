# -*- coding: utf-8 -*-
"""R562 机械之心 21 张 —— codex 图生图批量驱动。

为什么写成脚本：codex 单张约 2~4 分钟，21 张要 1 小时以上。
把循环关进脚本里只调一次执行工具，既省调用也避开「同工具连击」的循环判定。

约定（2026-11-10 实测）：
  · 必须显式指定代理 http://127.0.0.1:7897，环境自带的 63248 沙箱代理连不上 chatgpt.com（HTTP 502）。
  · prompt 必须从 stdin 喂（`< prompt.txt`）；用位置参数 + stdin 重定向会报 "No prompt provided via stdin"。
  · codex 沙箱内无法把图拷出，只回报 ~/.codex/generated_images/<thread>/exec-*.png，由本脚本复制。
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = r"E:\work\card_rogue"
# Python 的 CreateProcess 不认 bash shim，必须直指 exe（codex.cmd 也行，但 exe 最稳）
CODEX_EXE = os.path.expanduser(
    r"~\.local\codex-cli\node_modules\@openai\codex-win32-x64\vendor"
    r"\x86_64-pc-windows-msvc\bin\codex.exe")
D = os.path.join(ROOT, "art_src", "2026-11-10_机械之心放量_R562")
RAW = os.path.join(D, "raw")
GEN = os.path.expanduser(r"~\.codex\generated_images")
PROXY = "http://127.0.0.1:7897"

STYLE_MECH = os.path.join(ROOT, "assets", "pics", "8025.png")
STYLE_ALLY = os.path.join(ROOT, "assets", "pics", "_pending", "8073.png")
CHAR_MECH = os.path.join(ROOT, "assets", "ui", "class_cg_mech.png")

# id -> (参考图, 说明)
JOBS = [
    (8031, "集体改造", STYLE_MECH),
    (8032, "侦察塔", STYLE_MECH),
    (8034, "堡垒", STYLE_MECH),
    (8037, "改造工厂", STYLE_MECH),
    (8044, "加厚装甲", STYLE_MECH),
    (8045, "自主升级", STYLE_MECH),
    (8048, "生产订单", STYLE_MECH),
    (8051, "重组", STYLE_MECH),
    (8068, "轻量化", STYLE_MECH),
    (8083, "拼装原型", STYLE_ALLY),
    (8086, "重构", STYLE_MECH),
    (9143, "发明专家", CHAR_MECH),
    (9162, "集中突破", STYLE_MECH),
    (9164, "辅助刃", STYLE_MECH),
    (9167, "合体", STYLE_MECH),
    (9219, "压感地雷", STYLE_MECH),
    (9220, "阵地保卫者", STYLE_ALLY),
    (9221, "结合者", STYLE_ALLY),
    (9222, "忒修斯奇械", STYLE_ALLY),
]

PAT = re.compile(r"[A-Za-z]:[\\/][^\"\r\n]*?generated_images[\\/][^\"\r\n]*?\.png")


def log(msg):
    line = "[%s] %s" % (time.strftime("%H:%M:%S"), msg)
    print(line, flush=True)
    with open(os.path.join(D, "_batch.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write(line + "\n")


def pick_output(jsonl_text):
    """从 codex JSONL 里找最后一张生成图的绝对路径。"""
    hits = PAT.findall(jsonl_text.replace("\\\\", "\\"))
    for p in reversed(hits):
        p = p.replace("/", "\\")
        if os.path.exists(p):
            return p
    # 兜底：扫描该 thread 的 generated_images 目录里最新的 png
    m = re.search(r'"thread_id"\s*:\s*"([0-9a-f-]+)"', jsonl_text)
    if m:
        d = os.path.join(GEN, m.group(1))
        if os.path.isdir(d):
            pngs = [os.path.join(d, f) for f in os.listdir(d) if f.endswith(".png")]
            if pngs:
                return max(pngs, key=os.path.getmtime)
    return None


def run_one(cid, name, ref, suffix="_v1"):
    dst = os.path.join(RAW, "%d_%s%s.png" % (cid, name, suffix))
    if os.path.exists(dst) and os.path.getsize(dst) > 50000:
        log("SKIP %s %s（已有 %s）" % (cid, name, os.path.basename(dst)))
        return True
    prompt = os.path.join(D, "%d_%s%s.txt" % (cid, name, "" if suffix == "_v1" else suffix))
    if not os.path.exists(prompt):
        log("MISS %s %s（没有 prompt）" % (cid, name))
        return False
    if ref and not os.path.exists(ref):
        log("MISS %s 参考图不存在：%s" % (cid, ref))
        return False

    env = dict(os.environ)
    for k in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "all_proxy"):
        env.pop(k, None)
    env["HTTPS_PROXY"] = env["HTTP_PROXY"] = env["https_proxy"] = env["http_proxy"] = PROXY

    for attempt in (1, 2):
        t0 = time.time()
        log("RUN  %s %s  参考=%s  第%d次" % (cid, name, os.path.basename(ref) if ref else "纯文字(无参考图)", attempt))
        try:
            with open(prompt, "rb") as pin:
                proc = subprocess.run(
                    [CODEX_EXE, "exec", "--json", "--skip-git-repo-check", "-C", ROOT]
                    + (["-i", ref] if ref else []),
                    stdin=pin, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env=env, timeout=900, cwd=ROOT,
                    creationflags=0x08000000,   # CREATE_NO_WINDOW：别弹出黑框
                )
            text = proc.stdout.decode("utf-8", "replace")
        except subprocess.TimeoutExpired as e:
            text = (e.stdout or b"").decode("utf-8", "replace")
            log("TIMEOUT %s（%.0fs）" % (cid, time.time() - t0))
        except Exception as e:                                    # noqa: BLE001
            log("ERROR %s %r" % (cid, e))
            text = ""
        with open(os.path.join(D, "_log_%d%s.jsonl" % (cid, suffix)), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

        src = pick_output(text)
        if src:
            shutil.copyfile(src, dst)
            log("OK   %s %s  <- %s  (%.0fs, %d KB)" % (
                cid, name, os.path.basename(src), time.time() - t0,
                os.path.getsize(dst) // 1024))
            return True
        log("FAIL %s %s 第%d次没有图" % (cid, name, attempt))
        time.sleep(5)
    return False


def main():
    os.makedirs(RAW, exist_ok=True)
    only = set(int(x) for x in sys.argv[1:]) if len(sys.argv) > 1 else None
    done, fail = [], []
    for cid, name, ref in JOBS:
        if only and cid not in only:
            continue
        if run_one(cid, name, ref):
            done.append(cid)
        else:
            fail.append(cid)
    log("=== 结束 成功%d / 失败%d %s" % (len(done), len(fail), fail))


if __name__ == "__main__":
    main()
