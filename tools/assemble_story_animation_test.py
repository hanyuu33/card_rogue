from PIL import Image,ImageOps
from pathlib import Path
import subprocess,shutil,sys
r=Path('E:/work/card_rogue');w=r/'release/trailer/story_animation_20261124';w.mkdir(parents=True,exist_ok=True)
src=Path(sys.argv[1]);shutil.copy2(src,w/'source_sheet.png');im=Image.open(src).convert('RGB')
for i in range(12):
 x=i%4;y=i//4;p=im.crop((round(x*im.width/4),round(y*im.height/3),round((x+1)*im.width/4),round((y+1)*im.height/3)))
 canvas=Image.new('RGB',(1920,1080),'#182b23');p=ImageOps.contain(p,(1920,1080),Image.Resampling.LANCZOS);canvas.paste(p,((1920-p.width)//2,(1080-p.height)//2));canvas.save(w/f'frame_{i:02}.png')
ff=shutil.which('ffmpeg');out=r/'release/trailer/out/quackill_story_animation_test_20261124.mp4'
subprocess.run([ff,'-y','-v','error','-framerate','2','-i',str(w/'frame_%02d.png'),'-i',str(r/'assets/audio/bgm/title.ogg'),'-vf','fps=30','-t','6','-c:v','libx264','-crf','18','-pix_fmt','yuv420p','-af','afade=t=out:st=5:d=1','-c:a','aac','-movflags','+faststart',str(out)],check=True)
print(out)
