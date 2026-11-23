from pathlib import Path
from PIL import Image
import shutil,zipfile,json
R=Path('E:/work/card_rogue');D=R/'release/trailer/forest_part1_v2_20261124';D.mkdir(parents=True,exist_ok=True);G=Path('C:/Users/Administrator/.codex/generated_images/01a20930-1140-70a2-ab94-b0c71fb94010')
scenes=[('01_faltering_music','exec-6f0fe5e2-858d-437e-9be0-ba9ced8d5f06.png','The young bear-eared bard begins playing a wooden violin in a woodland clearing. Her bow slows, her expression becomes troubled, and she lowers the instrument. The cat-eared forest spirit notices and leans forward with concern. Keep the deer and rabbits calm.'),('02_conversation','exec-74734a4a-b402-4284-81e6-58e2836e9bbd.png','The forest spirit approaches the seated bard and crouches to her eye level. She asks gently what is wrong. The bard sighs and explains, then relaxes as her friend listens. Subtle facial acting, natural eye contact and restrained hand gestures.'),('03_departure','exec-6db70a31-7021-4be0-a2f2-e293ea983ffc.png','The forest spirit rises with quiet determination and gestures toward the woodland path. Cut to the bard ready with her violin case. They take each other by the hand and walk together into the forest. Gentle cloth, hair and tail movement. No extra characters.')]
manifest=[]
for name,src,prompt in scenes:
 p=D/name;p.mkdir(exist_ok=True);shutil.copy2(G/src,p/'sheet_original.png');im=Image.open(G/src);w,h=im.size
 for i in range(4):
  x=i%2;y=i//2;f=im.crop((round(x*w/2)+2,round(y*h/2)+2,round((x+1)*w/2)-2,round((y+1)*h/2)-2));f.save(p/f'keyframe_{i+1:02}.png');manifest.append({'scene':name,'frame':i+1,'width':f.width,'height':f.height})
 (p/'video_prompt_en.txt').write_text(prompt+'\nUse consecutive keyframes as start/end references, 2-4 seconds per action. Preserve orange bob, rounded bear ears, daisies and blue costume of bard; pale blonde long hair, pointed cat ears, dark-tipped fluffy tail and green leaf dress of forest spirit. Keep children age-appropriate. No ducks, no machines, no city, no added combat. No morphing, no extra fingers, no text. Use cuts for camera changes rather than forcing spatial interpolation.\n',encoding='utf8')
(D/'使用说明.md').write_text('''# 第一部分重制 · 森林中的音准

本目录替代旧版含鸭子的第一部分。共3组、12张独立关键帧、3张原始四格表及英文视频提示词。全部发生在森林中，没有鸭子出镜；CG仅用于角色身份参考。

## 故事与镜头顺序
1. 演奏中断：森林伙伴等待演奏；诗人神情不安，琴弓迟疑，放下琴。建议5–7秒。
2. 关切交谈：森林精魄走近、蹲下询问；诗人叹气，解释烦恼；精魄认真倾听。建议6–8秒。
3. 决定出发：精魄起身示意森林小径；诗人收好乐器，两人牵手离开。建议5–7秒。

叙事依据 stories.json 第一章「游移的音准」。诗人的烦恼与两人的交谈来自正文；牵手同行为宣传片视觉改编，不冒充原作对白。原文提及鸭子但本版不让其参与或出镜。若使用对白，可在第二组后期加入原句「看上去你有些烦恼」「最近鸭子们不太安分」，第三组加入「那就让我去跟他们聊聊吧」；本素材图片不含字幕。

## 导入视频工具
- 只导入独立 keyframe_01.png 等作为首尾参考，不要把四格总图当作一个镜头。
- 每组按左上→右上→左下→右下拆分。原生每帧约832×467，没有放大冒充高清；适合作构图和动作参考，最终由视频工具重绘至目标分辨率。
- 每个动作2–4秒；组间采用正常剪接，不跨组强补间。每组附 video_prompt_en.txt。
- 第一组末帧诗人站立，第二组改为坐在倒木上，二者需要切镜并留自然落座时间。
- 第三组01→02涉及收琴和机位变化，建议切镜，别强迫模型让琴瞬间变成琴盒。03→04是牵手转身离开，可做连续动作。
- 剧情写「琴弓」，本版使用小提琴而非CG里的里拉琴；具体乐器形制是制作选择。注意补间时弓与琴弦接触及手指稳定。
- 这12张是关键姿势，不是等间隔动画帧。尾巴、包带、琴弓等仍需视频生成阶段保持一致。

旧素材保留在原目录供追溯，不作为本版镜头依据。未改动游戏正式素材，未开展第二部分实机录制。
''',encoding='utf8')
json.dump(manifest,open(D/'manifest.json','w'),indent=2)
z=D.parent/'quackill_forest_part1_v2_20261124.zip'
with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as a:
 for p in D.rglob('*'):
  if p.is_file():a.write(p,p.relative_to(D))
print(z);print('frames:',len(manifest),'zip_bytes:',z.stat().st_size)
