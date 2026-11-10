# -*- coding: utf-8 -*-
"""R573 后处理：codex raw → 居中裁 16:9 → 1280×720 → assets/ui/bg_<kind>.png。

增量交付：按「已存在的 raw/*_codex.png」动态拼验收页，不要求三张齐全。
用法：
    python tools/_finish.py            # 只出 processed/ + 验收页（干跑）
    python tools/_finish.py --write    # 额外落地 assets/ui/bg_<kind>.png
"""
import base64
import sys
from pathlib import Path
from PIL import Image, ImageDraw

D = Path(__file__).resolve().parents[1]
ROOT = D.parents[1]
RAW = D / "raw"
PROC = D / "processed"
REVIEW = D / "_review"
UI = ROOT / "assets" / "ui"
KINDS = ["hero", "pear", "flyer"]
CN = {"hero": "绝赞五换一", "pear": "鸭梨山大", "flyer": "飞行器"}
NOTE = {
    "hero": "五张换一张；本游戏羊皮纸／墨蓝金框卡面；不借游戏王卡框",
    "pear": "巨大的梨 + 小人／小车／小树参照物",
    "flyer": "喷气式背包；无桨叶、无机翼、无座舱",
}

for d in (PROC, REVIEW):
    d.mkdir(exist_ok=True)


def crop_16_9(im: Image.Image) -> Image.Image:
    w, h = im.size
    target = 16.0 / 9.0
    if w / h > target:              # 太宽 → 裁左右
        nw, nh = int(round(h * target)), h
    else:                           # 太高（含方图）→ 裁上下
        nw, nh = w, int(round(w / target))
    x, y = (w - nw) // 2, (h - nh) // 2
    return im.crop((x, y, x + nw, y + nh))


def main() -> int:
    write = "--write" in sys.argv
    done = []
    for kind in KINDS:
        src = RAW / (kind + "_codex.png")
        if not src.exists():
            print("PENDING", kind, "（raw 还没出）")
            continue
        im = Image.open(src).convert("RGB")
        raw_size = im.size
        out = crop_16_9(im).resize((1280, 720), Image.LANCZOS)
        dst = PROC / ("bg_" + kind + ".png")
        out.save(dst)
        if write:
            (UI / ("bg_" + kind + ".png")).write_bytes(dst.read_bytes())
        done.append((kind, raw_size, dst))
        print("OK", kind, raw_size, "->", (1280, 720), dst.name,
              "UI" if write else "(dry-run)")

    # 联系表（横向拼，缩到 640×360 一张，便于一眼看画风是否同一套）
    if done:
        sheet = Image.new("RGB", (640 * len(done), 360 + 28), (24, 26, 32))
        dr = ImageDraw.Draw(sheet)
        for i, (kind, _, dst) in enumerate(done):
            tile = Image.open(dst).resize((640, 360), Image.LANCZOS)
            sheet.paste(tile, (i * 640, 28))
            dr.text((i * 640 + 8, 8), "%s  %s" % (kind, CN[kind]), fill=(235, 230, 215))
        sheet.save(REVIEW / "r573_sheet.png")
        print("SHEET", REVIEW / "r573_sheet.png")

        # 交付页：base64 内嵌，绝不写相对 src（会满页破图）
        cards = []
        for kind, _, dst in done:
            b64 = base64.b64encode(dst.read_bytes()).decode("ascii")
            cards.append(
                '<figure><img src="data:image/png;base64,' + b64 + '"/>'
                '<figcaption><b>' + kind + ' · ' + CN[kind] + '</b> —— ' + NOTE[kind]
                + '</figcaption></figure>')
        pending = [k for k in KINDS if k not in [d[0] for d in done]]
        pend = ("<p class='warn'>待出：" + "、".join(pending) + "</p>") if pending else ""
        html = HTML.replace("__CARDS__", "\n".join(cards)).replace("__PENDING__", pend)
        (REVIEW / "r573_sheet.html").write_text(html, encoding="utf-8", newline="\n")
        print("HTML", REVIEW / "r573_sheet.html")

    if write:
        print("⚠️ 换图后必须重导入：godot --headless --path . --import（否则截图还是旧 .ctex）")
    return 0


HTML = """<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"/>
<title>R573 事件背景 · codex 出图验收</title>
<style>
body{margin:0;padding:28px;background:#f5f2ea;color:#2b2b33;font-family:'Segoe UI','Microsoft YaHei',sans-serif}
h1{font-size:22px;margin:0 0 6px}p.sub{color:#6b6458;margin:0 0 22px;font-size:13px}
figure{margin:0 0 26px;background:#fff;padding:12px;border:1px solid #ded7c7;border-radius:8px}
img{width:100%;max-width:1280px;display:block;border-radius:4px}
figcaption{font-size:13px;color:#514a3e;padding-top:9px;line-height:1.6}
.warn{color:#a33;background:#fff3f0;border:1px solid #e6c5bd;padding:10px;border-radius:6px;font-size:13px}
</style></head><body>
<h1>R573 事件背景 · 委托 codex 纯文生图</h1>
<p class="sub">口径：卡通赛璐璐（粗黑描边 / 平涂两级明暗 / 低饱和冷灰蓝 + 一处暖点）；1280×720；主体避开中央正文卡片 x 26%–74% / y 47% 以下；画面铺满整幅、下半不刷纯色块。全部不参与图生图。</p>
__PENDING__
__CARDS__
</body></html>"""


if __name__ == "__main__":
    raise SystemExit(main())
