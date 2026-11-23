from pathlib import Path
from PIL import Image
import shutil,json,zipfile
R=Path('E:/work/card_rogue');D=R/'release/trailer/keyframes_20261124';D.mkdir(parents=True,exist_ok=True)
G=Path('C:/Users/Administrator/.codex/generated_images/01a20930-1140-70a2-ab94-b0c71fb94010')
scenes=[('01_duck_request','exec-0e77fc26-a6de-4555-8b18-f508d643e987.png','鸭子的请托','Stop the lyre music as the duck runs onto the bridge. The duck catches its breath and points toward distant smoke. The forest spirit listens, then takes its hand. The bard rises to join them. Preserve bear ears, daisy ornaments and golden lyre; preserve cat ears and fluffy tail.'),('02_forest_intervention','exec-7e1abcc0-c4db-42c8-ad47-703369cf73e5.png','拦下追击','The white duck runs right, frightened. The silver-bob-haired rogue follows. The cat-eared forest spirit steps between them with an open palm. The rogue brakes and lowers her dagger. The child kneels to reassure the duck. No attack or injury.'),('03_mechanical_aid','exec-1d352599-3cf5-4b38-a41c-c8957d8d9e17.png','机械之心援护','The bespectacled mechanic sets a brass launcher on the wall. The forest spirit and duck remain behind cover. A single golden pulse hits the automaton shield. Sparks settle; the mechanic gestures for her companions to follow. Keep launcher grounded and preserve round glasses, low ponytail and ochre scarf.'),('04_factory_infiltration','exec-685a8f39-b89e-47c3-92b3-bb1329ad0c70.png','潜入工坊','The two women crouch behind the wall as a searchlight sweeps the factory entrance. The rogue moves through shadow to the control box, works the lever and beckons the mechanic through. Keep short silver hair and purple cloak; preserve glasses and low ponytail. The patrol looks away, no combat.')]
manifest=[]
for name,src,title,prompt in scenes:
 p=D/name;p.mkdir(exist_ok=True);shutil.copy2(G/src,p/'sheet_original.png');im=Image.open(G/src);w,h=im.size
 for n in range(4):
  x=n%2;y=n//2
  # Trim 2px inside each boundary to exclude thin contact-sheet dividers; keep native pixels.
  box=(round(x*w/2)+2,round(y*h/2)+2,round((x+1)*w/2)-2,round((y+1)*h/2)-2)
  f=im.crop(box);f.save(p/f'keyframe_{n+1:02}.png');manifest.append({'scene':name,'frame':n+1,'size':f.size})
 (p/'video_prompt_en.txt').write_text(prompt+'\n\nUse consecutive keyframes as start and end frames. Animate one action per clip, 2-4 seconds per transition. Preserve reference character designs, body scale and anatomy. Natural weight transfer, feet planted, coherent hands and props, subtle hair and cloth motion. Keep camera nearly locked, no cuts, no morphing, no additional characters, no text or watermark.\n',encoding='utf8')
json.dump(manifest,open(D/'manifest.json','w',encoding='utf8'),ensure_ascii=False,indent=2)
(D/'使用说明.md').write_text('''# 动画关键帧素材 · 2026-11-24

共4组场景、16张独立PNG、4张原始分镜表，每组附英文视频提示词。顺序按目录编号；每组由左上→右上→左下→右下拆分。独立图片保留原生像素，去除接缝2px，没有放大冒充高清。

## 使用
- 向视频工具导入独立 keyframe_01.png 等，不要把四格总图当作单张首帧。
- 优先按01→02、02→03、03→04逐段生成，每段2–4秒，再剪接。跨场景用硬切或短淡转，别跨场景强制补间。
- 同时提供对应游戏原始角色CG作身份参考。每组video_prompt_en.txt可直接复制。
- 这些是关键姿势，不是等时间隔的逐帧动画；手势、相机和场景细节存在生成误差，视频工具仍需锁定角色和道具。

## 场景
1. 鸭子的请托：吟游诗人停下演奏，鸭子指向冒烟的王国，森林精魄答应同行。参考第一、二章；用于开场。
2. 拦下追击：鸭子逃跑，森林精魄挡在刺客面前，刺客停手。参考第三章；也可独立使用，和第一组并非严格连续时刻。
3. 机械之心援护：架设黄铜装置、掩护伙伴、解除门前威胁。改编第四章；具体武器演出为宣传演绎。
4. 潜入工坊：观察探照灯、潜行到控制箱、开门示意同行。改编第五章。

## 已检查与仍需注意
- 森林精魄：猫耳与蓬松尾巴、浅金长发及叶裙；不沿用旧稿误生成的鹿耳。
- 刺客：银色短发、红眼与紫色兜帽斗篷；机械之心：圆眼镜、深色低马尾、白外衣与黄围巾；吟游诗人：圆熊耳、雏菊发饰、橘色短发、蓝裙和金色里拉琴。
- 03末帧机械之心转到画面右侧，建议在发射后切镜，避免要求视频工具完成长距离瞬移。
- 04控制箱与门的开合结构在后两帧有变化：建议01→02→03作为一个潜行镜头；04作为独立出门镜头，不强行让第三帧的升降栅门变形成第四帧的铰链门。
- 01部分帧脚部接近画面边缘；用原图作宽景参考，视频生成时不要额外放大裁切。

原始角色参考位于 E:/work/card_rogue/assets/ui/class_cg_*.png，鸭子弓手 assets/pics/9017.png。未修改任何游戏正式素材，也未开展实机录屏。
''',encoding='utf8')
zip_path=D.parent/'quackill_keyframes_20261124.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
 for p in D.rglob('*'):
  if p.is_file():z.write(p,p.relative_to(D))
print(str(zip_path));print('frames',len(manifest));print('sizes',sorted({tuple(v['size']) for v in manifest}));print('zip bytes',zip_path.stat().st_size)
