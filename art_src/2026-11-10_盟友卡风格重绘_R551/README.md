# 盟友卡风格重绘 R551（codex 出图）

> 2026-11-10 · 目标：把写实/厚涂的盟友卡统一到 R545 赛璐璐风格（击退 9004 + 四元素）。

## 本轮 4 张

| id | 名字 | 阵营 | 旧图问题 | 新版 |
|---|---|---|---|---|
| 9038 | 老虎 | 森林精魄 | 照片级写实 | raw/9038_老虎_赛璐璐v1.png ✅ |
| 8025 | 素体 | 机械之心 | 写实 3D 渲染 | raw/8025_素体_赛璐璐v1.png ⚠️ 主体偏白，可微调钢灰 |
| 9016 | 犀牛 | 森林精魄 | 照片级写实 | raw/9016_犀牛_赛璐璐v1.png ✅ |
| 8047 | 嵌合暴君 | 机械之心 | 主体融入背景看不清 | raw/8047_嵌合暴君_赛璐璐v2.png ✅（v1 构图过满裁腿作废） |

## 出图方式

- codex CLI（gpt-6-astra + visualize 插件），纯文生图，`codex exec --json < prompt.txt`。
- prompt 文件同目录（`.txt`），统一赛璐璐模板：cel-shaded / thin line art / hard-edged 2-3 step shading /
  dark blurred background + bright subject；反面 NO photorealistic / NO 3D render / NO photographic texture。
- 机械之心两张补「钢灰 + 冷青发光缝线 + 极小琥珀点缀」，头=闭合传感器罩（NO 人脸/骷髅）。

## 入库流程

待用户过目点头后：`python tools/cardart.py approve <id>` 把 `assets/pics/_pending/<id>.png` 移入主目录。
