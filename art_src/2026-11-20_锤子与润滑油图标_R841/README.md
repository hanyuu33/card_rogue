# R841 · 锤子 7018 / 润滑油 7019 图标

两张都是**单物件工具图标**，与既有工具（炼金炸弹 / 爆炸蘑菇 / 大蒜）同一视觉家族：
单一物件、居中、厚描边、平涂赛璐璐、暖饱和色、纯白底。提示词写纯英文，
设计口径（为什么这么写）留在这份 README，两份分开存 —— prompt 里混中文注释会稀释权重。

## 出图提示词

### `prompts/7018_hammer.txt`（锤子）

```
A cute hand drawn cartoon game item icon of a single wooden mallet, viewed from the front and tilted slightly to the right.
A fat rounded wooden mallet head made of light oak wood, with two darker brown wood grain bands across it,
a flat circular striking face on each end of the head,
fitted on a short thick wooden handle, the grip wrapped with a thin dark leather strip and a small pommel at the bottom.
Thick dark brown outline, flat cel shading with two or three tone steps,
warm saturated honey and cream wood colors, ...
NOT a metal hammer, NOT a claw hammer, NOT a judge's gavel, NOT a club, NOT a mace,
no iron head, no spikes, no nails, no motion lines, no stars.
```

### `prompts/7019_oil.txt`（润滑油）

```
A cute hand drawn cartoon game item icon of a single small oil flask.
A squat rounded glass bottle filled with glowing golden amber oil,
a narrow neck with a small cork stopper on top,
one thick golden oil drop hanging from the tip of the cork,
two crisp white highlights on the rounded glass.
NOT a machine oil can with a long metal spout, NOT a wine bottle, NOT a potion with green liquid,
no paper label, no lettering on the bottle, no brush.
```

## 设计口径

- **锤子必须一眼是「木」的**：店长指定「图片为木锤」。木纹横带 + 平圆敲击面 + 皮缠握把，
  三条同时给，才不会滑到铁锤（金属灰）或法槌（细长柄）。负面点名 metal / claw / gavel 是必需的：
  单写 "mallet" 模型有相当概率给一把法官槌。
- **锤子不画「眩晕」符号**（星星 / 冲击线）。同批的爆炸蘑菇靠引信与火花区分「会炸」，
  但那只蘑菇本来会被读成食物；锤子本身就是武器，再加星星在 44px 下只会糊成一团，
  也偏离店长「图片为木锤」的原话。
- **润滑油必须是「油」不是「药」**：既有药瓶 7005（红）/ 7006（蓝）已经占了两岸，
  琥珀金 + 软木塞 + 塞口挂着的那一滴，是它和药水唯一的区分点。负面点名
  green liquid / wine bottle / machine oil can 三条，防止滑成机油壶或葡萄酒瓶。

## 处理与验收

- 抠图：`tools/_make_r841_icons.py`（照抄 R755 的 `_bg_mask` 边缘泛洪，不 import 那个会跑主流程的模块）。
  自检是断言：四角 alpha = 0、中心 alpha = 255。
- 落地：`assets/ui/trap_icon_7018.png` / `trap_icon_7019.png`（128×128，与 `processed/` 同字节）。
- `processed/_preview_44px.png`：44px 实尺寸四件并排（爆炸蘑菇 / 大蒜 / 木锤 / 油瓶），
  木锤的「柄 + 锤头」结构仍分得开，油瓶与红蓝两瓶药水靠色相区分。
- 生成图的固定毛病（棋盘格伪透明、右下角水印）这两张都没犯，只走了常规泛洪。

## 实机

`_shots/r841_hammer_oil.png`：工具栏两件新工具 + 一边被锤子砸晕的敌人 + 选卡页（润滑油）。
