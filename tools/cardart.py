# -*- coding: utf-8 -*-
"""R478 未确认卡图管理：list / approve / reject。

约定：
  assets/pics/_pending/<id>.png   未确认的卡图（游戏内会回退读取，卡面左上角带黄色三角标记）
  assets/pics/<id>.png            已确认的卡图（主目录，优先命中）
  assets/pics/_pending/manifest.json  清单：prompt / 参考来源 / 生成时间 / 状态

用法（在仓库根跑）：
  python tools/cardart.py list           列出待确认
  python tools/cardart.py approve 9014   确认：移入 assets/pics/ 并从清单摘掉
  python tools/cardart.py approve all    全部确认
  python tools/cardart.py reject 9014    否决：删掉这张图
"""
import json
import os
import shutil
import sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PICS = os.path.join(ROOT, "assets", "pics")
PEND = os.path.join(PICS, "_pending")
MANIFEST = os.path.join(PEND, "manifest.json")


def _load():
    if not os.path.exists(MANIFEST):
        return {"note": "", "updated": "", "items": {}}
    return json.load(open(MANIFEST, encoding="utf-8"))


def _save(m):
    # 固定 LF：manifest.json 在仓库里是 LF，Windows 文本模式默认会写 CRLF
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, ensure_ascii=False, indent=1)


def cmd_list():
    m = _load()
    files = sorted(f for f in os.listdir(PEND) if f.endswith(".png"))
    if not files:
        print("没有待确认的卡图。")
        return
    print("待确认 %d 张：" % len(files))
    for f in files:
        cid = os.path.splitext(f)[0]
        it = m["items"].get(cid, {})
        print("  %-6s %-12s 分级=%s  生成=%s" % (
            cid, it.get("name", "?"), it.get("tier", "?"), it.get("created", "?")))
    print("\n确认：python tools/cardart.py approve <id>   否决：reject <id>")


def _move(cid):
    src = os.path.join(PEND, "%s.png" % cid)
    dst = os.path.join(PICS, "%s.png" % cid)
    if not os.path.exists(src):
        print("  跳过 %s：没有这张待确认图" % cid)
        return False
    if os.path.exists(dst):
        print("  跳过 %s：主目录已有同名图（先手动比对再删）" % cid)
        return False
    shutil.move(src, dst)
    return True


def cmd_approve(arg):
    m = _load()
    ids = [os.path.splitext(f)[0] for f in os.listdir(PEND) if f.endswith(".png")] \
        if arg == "all" else [arg]
    ok = 0
    for cid in ids:
        if _move(cid):
            # 条目**不删**：prompt / ref 是这张图的出生档案，确认后仍要能追溯。
            it = m["items"].setdefault(cid, {})
            it["status"] = "approved"
            it["approved"] = date.today().isoformat()
            ok += 1
            print("  ✓ %s 已确认 → assets/pics/" % cid)
    _save(m)
    print("确认 %d 张。" % ok)


def cmd_reject(arg):
    m = _load()
    p = os.path.join(PEND, "%s.png" % arg)
    if os.path.exists(p):
        os.remove(p)
        print("  ✗ %s 已否决并删除" % arg)
    else:
        print("  没有 %s" % arg)
    m["items"].pop(arg, None)
    _save(m)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        cmd_list()
    elif sys.argv[1] == "list":
        cmd_list()
    elif sys.argv[1] == "approve":
        cmd_approve(sys.argv[2] if len(sys.argv) > 2 else "all")
    elif sys.argv[1] == "reject":
        cmd_reject(sys.argv[2])
    else:
        print(__doc__)
