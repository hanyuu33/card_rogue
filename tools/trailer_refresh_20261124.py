from PIL import Image,ImageDraw,ImageFont,ImageFilter
from pathlib import Path
import subprocess,shutil,json
R=Path(__file__).resolve().parents[1]; W=R/'release/trailer/work_refresh_20261124';W.mkdir(parents=True,exist_ok=True); O=R/'release/trailer/out';O.mkdir(exist_ok=True)
ff=shutil.which('ffmpeg'); font='C:/Windows/Fonts/msyh.ttc'
shots=[('assets/ui/class_cg_forest.png','每一次出发，都是新的冒险',3),('assets/ui/class_cg_rogue.png','暗影刺客',2.5),('assets/ui/class_cg_mech.png','机械之心',2.5),('assets/ui/class_cg_bard.png','吟游诗人',2.5),('assets/pics/9017.png','小小弓手，也能改变战局',3),('assets/pics/9068.png','水 · 风 · 土 · 火',1.6),('assets/pics/9082.png','水 · 风 · 土 · 火',1.6),('assets/pics/9235.png','水 · 风 · 土 · 火',1.6),('assets/pics/9236.png','水 · 风 · 土 · 火',1.6),('assets/pics/9135.png','迎战赫菲斯托斯',3.6),('assets/ui/class_cg_forest.png','嘎嘎乱杀  QUACKILL\n加入 Steam 愿望单',4)]
clips=[]
for i,(src,caption,dur) in enumerate(shots):
 im=Image.open(R/src).convert('RGB'); ratio=max(1920/im.width,1080/im.height);bg=im.resize((round(im.width*ratio),round(im.height*ratio)));x=(bg.width-1920)//2;y=(bg.height-1080)//2;bg=bg.crop((x,y,x+1920,y+1080))
 if '/pics/' in src:
  bg=bg.filter(ImageFilter.GaussianBlur(36));bg=Image.blend(bg,Image.new('RGB',bg.size,'#142d25'),.55);s=min(1150/im.width,940/im.height);im=im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS);bg.paste(im,((1920-im.width)//2,(1020-im.height)//2))
 dr=ImageDraw.Draw(bg,'RGBA');dr.rectangle((0,905,1920,1080),fill=(15,30,23,225));f=ImageFont.truetype(font,42 if i<10 else 44)
 dr.multiline_text((960,970),caption,font=f,fill='#f6ecd2',anchor='mm',align='center',spacing=12)
 p=W/f'{i:02}.png';bg.save(p);c=W/f'{i:02}.mp4'
 subprocess.run([ff,'-y','-loglevel','error','-loop','1','-i',str(p),'-vf',f"zoompan=z='1+0.00018*on':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1920x1080:fps=30,fade=t=in:d=0.22,fade=t=out:st={dur-.22}:d=0.22",'-t',str(dur),'-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p',str(c)],check=True);clips.append(c);print(i,flush=True)
ls=W/'concat.txt';ls.write_text(''.join("file '"+p.as_posix()+"'\n" for p in clips));total=sum(s[2] for s in shots)
out=O/'quackill_refresh_20261124_zh.mp4'
subprocess.run([ff,'-y','-loglevel','error','-f','concat','-safe','0','-i',str(ls),'-stream_loop','-1','-i',str(R/'assets/audio/bgm/battle_elite.ogg'),'-map','0:v','-map','1:a','-c:v','copy','-af',f'afade=t=in:d=1,afade=t=out:st={total-2}:d=2,loudnorm=I=-16:TP=-1.5:LRA=11','-c:a','aac','-b:a','192k','-t',str(total),'-movflags','+faststart',str(out)],check=True)
json.dump(shots,open(W/'timeline.json','w',encoding='utf8'),ensure_ascii=False,indent=2)
print(out)

