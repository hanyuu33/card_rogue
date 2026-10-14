# -*- coding: utf-8 -*-
# 职业资产处理：3 张 16:9 CG 去水印；2 张头像抠透明；森林头像复用已有 head。
from PIL import Image, ImageDraw
import os
BASE = r"D:\work\gen_raw"
CG = {
    "forest": "Japanese_anime_style_illustrat_2026-10-14T03-04-24.png",
    "rogue":  "Japanese_anime_style_illustrat_2026-10-14T03-05-54.png",
    "mech":   "Japanese_anime_style_illustrat_2026-10-14T03-06-22.png",
}
AV = {
    "rogue": "head_only_icon_of_the_same_ani_2026-10-14T03-06-55.png",
    "mech":  "head_only_icon_of_the_same_ani_2026-10-14T03-07-35.png",
}

def largest_label(fg, sw, sh):
    lab=[[0]*sw for _ in range(sh)]; cur=0; sizes={}
    for y in range(sh):
        for x in range(sw):
            if fg[y][x] and lab[y][x]==0:
                cur+=1; cnt=0; st=[(x,y)]; lab[y][x]=cur
                while st:
                    cx,cy=st.pop(); cnt+=1
                    for nx,ny in ((cx+1,cy),(cx-1,cy),(cx,cy+1),(cx,cy-1)):
                        if 0<=nx<sw and 0<=ny<sh and fg[ny][nx] and lab[ny][nx]==0:
                            lab[ny][nx]=cur; st.append((nx,ny))
                sizes[cur]=cnt
    return lab, (max(sizes, key=sizes.get) if sizes else 0)

def mat(src, dst, thresh=40):
    im=Image.open(src).convert("RGB"); w,h=im.size
    work=im.copy(); MARK=(255,0,255)
    for seed in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)]:
        if work.getpixel(seed)!=MARK:
            ImageDraw.floodfill(work, seed, MARK, thresh=thresh)
    px=work.load(); ds=4; sw,sh=max(1,w//ds),max(1,h//ds)
    fg=[[False]*sw for _ in range(sh)]
    for y in range(sh):
        for x in range(sw):
            f=False
            for yy in range(y*ds,min((y+1)*ds,h)):
                for xx in range(x*ds,min((x+1)*ds,w)):
                    if px[xx,yy]!=MARK: f=True; break
                if f: break
            fg[y][x]=f
    lab,big=largest_label(fg,sw,sh)
    srcpx=im.load(); out=Image.new("RGBA",(w,h),(0,0,0,0)); opx=out.load()
    for y in range(h):
        ly=min(y//ds,sh-1)
        for x in range(w):
            if px[x,y]!=MARK and lab[ly][min(x//ds,sw-1)]==big:
                opx[x,y]=srcpx[x,y]+(255,)
    bbox=out.getbbox()
    if bbox: out=out.crop(bbox)
    out.save(dst); return out.size

# CG 去水印（裁掉底部 6%）
for k,f in CG.items():
    im=Image.open(os.path.join(BASE,f)).convert("RGB"); w,h=im.size
    im=im.crop((0,0,w,int(h*0.94)))
    im.save(os.path.join(BASE,"class_cg_%s.png"%k)); print("class_cg_%s"%k, im.size)

# 头像抠透明
for k,f in AV.items():
    print("class_avatar_%s"%k, mat(os.path.join(BASE,f), os.path.join(BASE,"class_avatar_%s.png"%k)))

# 森林头像复用已有 head（重命名/复制）
Image.open(os.path.join(BASE,"forest_head_t.png")).convert("RGBA").save(os.path.join(BASE,"class_avatar_forest.png"))
print("class_avatar_forest copied")
print("ALL DONE")
