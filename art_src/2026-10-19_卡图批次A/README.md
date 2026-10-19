# 2026-10-19 · 卡图批次 A（森林精魄 · 野兽盟友 ×9）

## 口径（用户定的）

- 大部分**按动物原本的样子**画，风格走**日本动漫**（赛璐璐上色、线条干净）。
- 斑鸠必须是**珠颈斑鸠**（颈部黑底白点的那块斑）。
- 特例：**乌鸦**要**血红色天空背景 + 血红色眼睛**；**巨鼠**要**站立的姿势**。

## 通用提示词后缀（9 张共用）

```
Japanese anime cel-shaded illustration, clean crisp lineart, flat colors with sharp
highlights, fantasy forest setting, warm golden sunlight through leaves, softly
blurred desaturated background, single subject centered occupying about 70% of the
frame, generous empty margin around the subject, no humans, no text, no watermark,
no frame, no border, trading card illustration, square composition
```

## 逐张主体描述

| id | 卡名 | 主体描述 |
|---|---|---|
| 9046 | 巨鼠 | A giant rat **standing upright on its hind legs like a person**, grey-brown ragged fur, long whiskers, small sharp claws, alert beady eyes, front paws raised slightly |
| 9039 | 乌鸦 | A large black crow perched on a twisted dead branch, glossy jet-black feathers, **glowing BLOOD RED eyes**, **dramatic blood-red sky filling the entire background** |
| 9052 | 斑鸠 | A **spotted dove (Streptopelia chinensis)**, warm grey-brown plumage, the distinctive **black neck patch covered with small white spots**, delicate pinkish feet, perched on a mossy branch |
| 9032 | 野兔 | A wild hare crouching low in tall ferns, tawny brown fur, very long upright ears, large alert eyes, powerful hind legs |
| 9033 | 山猫 | A lynx bobcat crouching low on a mossy rock in a dense autumn forest, tufted black-tipped ears, spotted tawny fur, thick powerful paws, intense sharp gaze |
| 9034 | 赤狐 | A red fox sitting upright in three-quarter profile, vivid orange-red fur, white chest and white tail tip, thick bushy tail, amber eyes |
| 9040 | 猎犬 | A muscular brown hunting hound standing alert with legs braced, short coarse fur, floppy ears, powerful chest, mouth slightly open showing fangs |
| 9031 | 白狼 | A magnificent white wolf standing on a mossy rock, thick silver-white fur, pale glowing ice-blue eyes, wind blowing through the fur |
| 9038 | 狮子 | A massive male lion with a huge golden mane, low angle view, mouth slightly open showing fangs, standing on cracked rocky ground |

> 山猫第一版背景**渐隐到白**（vignette），铺到卡面上会露白边 → 重出一次，并在提示词里加了
> `FULL-BLEED background … no white background, no vignette, no fade to white`。
> 以后凡是有「主体 + 留白」倾向的图，都要把这一句写进去。

## 处理流程（`raw/` → `assets/pics/`）

1. 白底图先按非白像素 bbox 裁掉边框，再**内缩 6px** 杀掉抗锯齿白边。
2. **切掉底部 11%**：右下角有「AI生成 WORKBUDDY」水印，先切最省事。
3. 按卡图窗比例 **1.1117（448×403）** 做 cover 裁剪，再 LANCZOS 缩到 448×403。
4. 落到 `assets/pics/<id>.png`，跑 `--headless --import` 生成 `.import`。

## 验收

- `python _art_index.py --batch` → 批次 A **9/9 已完成**；`--check` 通过。
- 拼图 `_r249_batchA_check.png`（3×3，原始 448×403）逐张看过：无白边、无数字、无水印、主体完整。
- 回归：engine 2875 / reward 26 / bgm 31 / smoke 36 全绿（只加素材，不动逻辑）。
