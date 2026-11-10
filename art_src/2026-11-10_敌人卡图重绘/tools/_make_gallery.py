# -*- coding: utf-8 -*-
"""生成敌人卡重绘验收画廊（base64 内嵌 HTML，供 present_files 预览）."""
import base64
import io
import os

from PIL import Image

ROOT = 'E:/work/card_rogue'
ids = [
    ('1013', '灰烬龙'),
    ('1061', '爆裂机甲'),
    ('9014', '远古虚骨龙'),
    ('9132', '俄倪厄'),
    ('9135', '赫菲斯托斯'),
    ('9200', '启示者'),
    ('9237', '巴兰-α'),
]
OLD = os.path.join(ROOT, 'assets', 'pics')
NEW = os.path.join(ROOT, 'assets', 'pics', '_pending')


def to_jpeg64(path, q=92):
    im = Image.open(path).convert('RGB')
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=q)
    return 'data:image/jpeg;base64,' + base64.b64encode(buf.getvalue()).decode('ascii')


cards_html = []
for cid, name in ids:
    old64 = to_jpeg64(os.path.join(OLD, cid + '.png'))
    new64 = to_jpeg64(os.path.join(NEW, cid + '.png'))
    cards_html.append('''
    <div class="card">
      <div class="chead"><span class="cid">{cid}</span> {name}</div>
      <div class="pair">
        <figure><img src="{old}" alt="旧"><figcaption class="old">旧 · 写实厚涂</figcaption></figure>
        <figure><img src="{new}" alt="新"><figcaption class="new">新 · 赛璐璐</figcaption></figure>
      </div>
    </div>'''.format(cid=cid, name=name, old=old64, new=new64))

html = '''<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>敌人卡重绘验收（写实厚涂 → 赛璐璐）</title>
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
<h1>敌人卡重绘验收（7 张 · 写实厚涂 → 赛璐璐）</h1>
<div class="sub">左 = 旧图（写实厚涂） · 右 = 新图（日式动漫赛璐璐）。主体保持原设计，只换画法。</div>
{cards}
</body></html>'''.replace('{cards}', ''.join(cards_html))

out = os.path.join(ROOT, '_preview', 'enemy_rework_gallery.html')
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, 'w', encoding='utf-8') as f:
    f.write(html)

# 自检：无外部 src
import re
srcs = re.findall(r'src="([^"]+)"', html)
external = [s for s in srcs if not s.startswith('data:')]
print('saved', out)
print('img src 总数:', len(srcs), '| 外部 src:', external)
print('HTML bytes:', len(html.encode('utf-8')))
