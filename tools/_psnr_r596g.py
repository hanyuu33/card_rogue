import math
import sys

from PIL import Image, ImageChops, ImageStat

PAD = 24
CARD_W = 448
CARD_H = 403
ROW = 423

path = sys.argv[1] if len(sys.argv) > 1 else '_review/r596g_after.png'
img = Image.open(path).convert('RGB')

worst = 99.0
for i, cid in enumerate([9192, 9193, 1013]):
    y = PAD + ROW * i
    left = img.crop((PAD, y, PAD + CARD_W, y + CARD_H))
    right = img.crop((PAD + CARD_W + PAD, y, PAD + CARD_W + PAD + CARD_W, y + CARD_H))
    d = ImageChops.difference(left, right)
    mae255 = sum(ImageStat.Stat(d).mean) / 3.0
    mx = max(b.getextrema()[1] for b in d.split())
    mae = mae255 / 255.0
    psnr = 99.0 if mae <= 1e-6 else 20.0 * math.log10(1.0 / mae)
    worst = min(worst, psnr)
    print('%d  平均误差 %.3f/255  最大单通道差 %d  PSNR %.2f dB' % (cid, mae255, mx, psnr))
print('PSNR_RESULT worst=%.2f dB -> %s' % (worst, '可接受（>40dB）' if worst > 40 else '需复核'))
