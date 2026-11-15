# -*- coding: utf-8 -*-
"""Steam 成就图标流水线（R740）。

输入：`release/achievement_icons/src/` 下 AI 出的 1024×1024 方图（按 API name 命名）。
输出：
  * `release/achievement_icons/64/<API>.png`          已达成（彩色，64×64，后台直接传）
  * `release/achievement_icons/64/<API>_locked.png`   未达成（灰阶压暗，64×64）
  * `release/achievement_icons/512/<API>.png`         512 版（商店页 / 攻略站配图用）
  * `release/achievement_icons/preview.html`          一页看全 9×2，验收用

为什么裁 880 而不是直接缩：
  AI 出图右下角带「AI生成 WORKBUDDY」水印，居中裁掉四周各 72px 正好把它切干净；
  另外 Steam 成就图标是 64px，四周留白多了主体就糊，裁紧一点反而更清楚。

用法：python tools/make_achievement_icons.py
"""
import io
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "release", "achievement_icons")
SRC = os.path.join(BASE, "src")

# API name → 显示名（后台填的就是这个中文名；改这里要同步 release/steam_achievements.md）
ACHIEVEMENTS = [
    ("FIRST_STEP",   "初次启程"),
    ("FIRST_BOSS",   "直面恐惧"),
    ("LAYER2_CLEAR", "深入腹地"),
    ("FULL_CLEAR",   "完整通关"),
    ("CLEAR_FOREST", "森林的加冕"),
    ("CLEAR_ROGUE",  "影中的圆满"),
    ("CLEAR_MECH",   "机械的觉醒"),
    ("CLEAR_HARD",   "越难越勇"),
    ("CLEAR_APEX",   "巅峰之上"),
]

CROP = 72          # 四边各裁掉多少像素（1024 → 880）
ICON = 64
MID = 512
LOCK_DIM = 0.70    # 未达成版压暗比例


def _load(api: str) -> Image.Image:
    p = os.path.join(SRC, api + ".png")
    if not os.path.exists(p):
        raise SystemExit("缺源图：%s（把 AI 出的方图按 <API>.png 放进 src/）" % p)
    im = Image.open(p).convert("RGB")
    w, h = im.size
    side = min(w, h) - CROP * 2
    left = (w - side) // 2
    top = (h - side) // 2
    return im.crop((left, top, left + side, top + side))


def _resize(im: Image.Image, n: int) -> Image.Image:
    return im.resize((n, n), Image.LANCZOS)


def _locked(im: Image.Image) -> Image.Image:
    """未达成版：去色 + 压暗 + 略降对比 —— 一眼看出「还没拿到」，但仍能认出是什么。"""
    g = im.convert("L")
    g = g.point(lambda v: int(v * LOCK_DIM))
    return g.convert("RGB")


def main() -> None:
    out64 = os.path.join(BASE, "64")
    out512 = os.path.join(BASE, "512")
    os.makedirs(out64, exist_ok=True)
    os.makedirs(out512, exist_ok=True)

    rows = []
    for api, label in ACHIEVEMENTS:
        im = _load(api)
        big = _resize(im, MID)
        big.save(os.path.join(out512, api + ".png"))
        icon = _resize(im, ICON)
        icon.save(os.path.join(out64, api + ".png"), optimize=True)
        lk_big = _locked(im)
        lk_icon = _resize(_locked(im), ICON)
        lk_icon.save(os.path.join(out64, api + "_locked.png"), optimize=True)
        rows.append((api, label, icon, lk_icon))
        print("  %-13s %s  (64 + 512 + locked)" % (api, label))

    _preview(rows, out64)
    print("\n输出目录：%s" % BASE)


def _preview(rows, out64: str) -> None:
    """两种验收物：一张对比表 PNG（好发给人看）+ 一个 HTML（好逐条核对）。"""
    cell = 128
    pad = 18
    label_h = 26
    cols = 2
    w = pad + cols * (cell + pad * 6)
    h = pad + len(rows) * (cell + label_h + pad)

    try:
        # 预览图里有中文显示名，默认位图字体只有 ASCII，会全变方框 —— 优先找系统中文字体。
        for cand in ("C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/simhei.ttf"):
            if os.path.exists(cand):
                font = ImageFont.truetype(cand, 16)
                break
        else:
            font = ImageFont.truetype("arial.ttf", 16)
    except Exception:
        font = ImageFont.load_default()

    sheet = Image.new("RGB", (w, h), (22, 24, 28))
    d = ImageDraw.Draw(sheet)
    y = pad
    for api, label, icon, lk in rows:
        d.text((pad, y), api, fill=(226, 226, 226), font=font)
        d.text((pad, y + label_h - 4), label, fill=(150, 150, 150), font=font)
        x = pad + 210
        sheet.paste(icon.resize((cell, cell), Image.NEAREST), (x, y - 6))
        sheet.paste(lk.resize((cell, cell), Image.NEAREST), (x + cell + 30, y - 6))
        d.text((x, y + cell - 2), "achieved", fill=(120, 200, 140), font=font)
        d.text((x + cell + 30, y + cell - 2), "locked", fill=(170, 140, 120), font=font)
        y += cell + label_h + pad
    sheet.save(os.path.join(BASE, "preview.png"))
    print("  preview.png  %dx%d" % (w, h))

    html = [
        "<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>",
        "<title>Quackill · Steam 成就图标</title><style>",
        "body{background:#16181c;color:#e6e6e6;font:14px/1.7 system-ui,'Segoe UI',sans-serif;margin:0;padding:28px}",
        "h1{font-size:18px;color:#f0d9a8;margin:0 0 4px}p.note{color:#9aa0a6;margin:0 0 22px}",
        "table{border-collapse:collapse}td,th{padding:8px 14px;border-bottom:1px solid #2b2f36;text-align:left;vertical-align:middle}",
        "th{color:#9aa0a6;font-weight:500;font-size:12px}code{color:#8fd6a8}",
        "img.px{image-rendering:pixelated;width:64px;height:64px;border-radius:6px;border:1px solid #2b2f36;background:#0e0f12}",
        "img.big{width:96px;height:96px;border-radius:8px;border:1px solid #2b2f36}",
        "</style></head><body>",
        "<h1>Quackill · Steam 成就图标（9 条）</h1>",
        "<p class='note'>后台传 <code>64/&lt;API&gt;.png</code>（已达成）与 <code>64/&lt;API&gt;_locked.png</code>（未达成），"
        "两张都是 64×64。右侧大图只是方便看清，别传。</p>",
        "<table><tr><th>API / 显示名</th><th>已达成</th><th>未达成</th><th>预览</th></tr>",
    ]
    for api, label, icon, lk in rows:
        html.append(
            "<tr><td><code>%s</code><br>%s</td>"
            "<td><img class='px' src='64/%s.png'></td>"
            "<td><img class='px' src='64/%s_locked.png'></td>"
            "<td><img class='big' src='512/%s.png'></td></tr>"
            % (api, label, api, api, api)
        )
    html.append("</table></body></html>")
    with io.open(os.path.join(BASE, "preview.html"), "w", encoding="utf-8") as f:
        f.write("\n".join(html))
    print("  preview.html")


if __name__ == "__main__":
    main()
