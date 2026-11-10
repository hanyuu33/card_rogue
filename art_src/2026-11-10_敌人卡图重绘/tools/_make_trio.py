# -*- coding: utf-8 -*-
"""生成巴兰关三单位（α/β/γ）新旧对比拼图 + base64 验收画廊."""
import base64
import io
import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = 'E:/work/card_rogue'
ids = [
    ('9237', '巴兰-α'),
    ('9238', '安西-β'),
    ('9239', '塔基尼-γ'),
]
OLD = os.path.join(ROOT, 'art_src', '2026-11-10_敌人卡图重绘', 'replaced')
NEW = os.path.join(ROOT, 'assets', 'pics')


def make_compare():
    label_w = 150
    cell_w = 448
    cell_h = 403
    pad = 16
    row_h = cell_h + 30
    W = label_w + cell_w * 2 + pad * 4
    H = len(ids) * row_h + pad * 2
    canvas = Image.new('RGB', (W, H), (26, 27, 31))
    d = ImageDraw.Draw(canvas)
    f = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 22)
    fb = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttc', 34)
    bar_h = 44
    for i, (cid, name) in enumerate(ids):
        y = pad + i * row_h
        d.text((pad + 6, y + 8), '%s\n%s' % (cid, name), fill=(240, 230, 200), font=f)
        old = Image.open(os.path.join(OLD, cid + '.png')).convert('RGB')
        ox = label_w + pad
        canvas.paste(old, (ox, y))
        d.rectangle([ox, y, ox + cell_w - 1, y + bar_h - 1], fill=(190, 80, 30))
        d.text((ox + 12, y + 3), '旧', fill=(255, 255, 255), font=fb)
        new = Image.open(os.path.join(NEW, cid + '.png')).convert('RGB')
        nx = ox + cell_w + pad
        canvas.paste(new, (nx, y))
        d.rectangle([nx, y, nx + cell_w - 1, y + bar_h - 1], fill=(30, 150, 70))
        d.text((nx + 12, y + 3), '新', fill=(255, 255, 255), font=fb)
    out = os.path.join(ROOT, '_preview', 'balan_trio_compare.png')
    canvas.save(out)
    return out


def to_jpeg64(path, q=92):
    im = Image.open(path).convert('RGB')
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=q)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


def make_gallery():
    cards = []
    for cid, name in ids:
        old64 = to_jpeg64(os.path.join(OLD, cid + '.png'))
        new64 = to_jpeg64(os.path.join(NEW, cid + '.png'))
        cards.append('''
    <div class="card">
      <div class="chead"><span class="cid">{cid}</span> {name}</div>
      <div class="pair">
        <figure><img src="{old}"><figcaption class="old">旧 · 写实厚涂</figcaption></figure>
        <figure><img src="{new}"><figcaption class="new">新 · 赛璐璐</figcaption></figure>
      </div>
    </div>'''.format(cid=cid, name=name, old=old64, new=new64))
    html = '''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>巴兰关三单位重绘验收</title>
<style>
  body {{ margin:0; padding:28px 18px; background:#1b1c20; color:#e8e6df;
         font-family:"Microsoft YaHei","PingFang SC",sans-serif; }}
  h1 {{ font-size:20px; margin:0 0 4px; }}
  .sub {{ color:#9a9a90; font-size:13px; margin-bottom:22px; }}
  .card {{ background:#24262c; border:1px solid #34373f; border-radius:10px;
           padding:14px; margin-bottom:18px; }}
  .chead {{ font-size:16px; font-weight:600; margin-bottom:10px; }}
  .cid {{ color:#f0b64a; }}
  .pair {{ display:flex; gap:14px; flex-wrap:wrap; }}
  figure {{ margin:0; }}
  img {{ width:320px; border-radius:6px; display:block; }}
  figcaption {{ font-size:13px; margin-top:6px; text-align:center; }}
  figcaption.old {{ color:#ffb27a; }}
  figcaption.new {{ color:#7ee08a; }}
</style></head><body>
<h1>巴兰关三单位重绘验收（写实厚涂 → 赛璐璐）</h1>
<div class="sub">左 = 旧图（写实厚涂） · 右 = 新图（日式动漫赛璐璐）。9237 codex 出图，9238/9239 纯文字重出（姿势各自恢复）。</div>
{cards}
</body></html>'''.replace('{cards}', ''.join(cards))
    out = os.path.join(ROOT, '_preview', 'balan_trio_gallery.html')
    with open(out, 'w', encoding='utf-8') as fp:
        fp.write(html)
    srcs = re.findall(r'src="([^"]+)"', html)
    external = [s for s in srcs if not s.startswith('data:')]
    print('gallery saved', out, '| img src:', len(srcs), '| external:', external)


if __name__ == '__main__':
    print('compare ->', make_compare())
    make_gallery()
