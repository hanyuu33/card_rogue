"""Reproducible crops: material boundaries map to board columns and back rows."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
src=root/'art_src/2026-11-04_battle_ui'
dst=root/'assets/ui/adventure_shared'
im=Image.open(src/'forest_source.png')
out=Image.new('RGB',(900,1350))
for xa,xb,ox in [(0,430,0),(430,595,300),(595,1024,600)]:
    for ya,yb,oy,h in [(0,270,0,225),(270,1280,225,900),(1280,1536,1125,225)]:
        out.paste(im.crop((xa,ya,xb,yb)).resize((300,h),Image.Resampling.LANCZOS),(ox,oy))
out.save(dst/'battlefield_1.png')
im=Image.open(src/'sky_source.png')
out=Image.new('RGB',(900,1350))
for ya,yb,oy,h in [(0,280,0,225),(280,1220,225,900),(1220,1536,1125,225)]:
    out.paste(im.crop((0,ya,1024,yb)).resize((900,h),Image.Resampling.LANCZOS),(0,oy))
out.save(dst/'battlefield_3.png')
im=Image.open(src/'mech_source.png')
out=Image.new('RGB',(900,1350))
for xa,xb,ox in [(0,340,0),(340,685,300),(685,1024,600)]:
    for ya,yb,oy,h in [(0,267,0,225),(267,1240,225,900),(1240,1536,1125,225)]:
        out.paste(im.crop((xa,ya,xb,yb)).resize((300,h),Image.Resampling.LANCZOS),(ox,oy))
out.save(dst/'battlefield_2.png')
