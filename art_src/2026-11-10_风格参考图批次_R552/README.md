# 风格参考图批次 R552 归档

> 2026-11-10 · 目标：14 个视觉题材桶，每桶 1 张「放大验证过的干净赛璐璐」参考图，
> 覆盖全卡池 306 张。之后所有卡走 ImageGen 图生图（带对应桶参考图）。

## 缺口桶 9 张（codex 最优先生成）

| 序 | 参考图 | 桶 | prompt 文件 | 状态 |
|---|---|---|---|---|
| 1 | 老虎 9038 | 森林陆兽 | （上一轮已出） | ✅ 已出 pending |
| 2 | 乌鸦 9039 | 鸟类 | 9039_crow.txt | ⏳ |
| 3 | 树人 8003 | 树人/植物 | 8003_treant.txt | ⏳ |
| 4 | 素体 8025 | 机械构装体 | 8025_blank_mech.txt | ⏳ |
| 5 | 赏金猎人 9204 | 暗影人形 | 9204_bounty_hunter.txt | ⏳ |
| 6 | 影子猫 8006 | 暗影生物 | 8006_shadow_cat.txt | ⏳ |
| 7 | 骷髅兵 1053 | 亡灵/骷髅 | 1053_skeleton.txt | ⏳ |
| 8 | 灰烬龙 1013 | 龙 | 1013_ash_dragon.txt | ⏳ |
| 9 | 箭塔 9019 | 建筑/塔 | 9019_arrow_tower.txt | ⏳ |

## 已有标杆 6 张（直接复用，不重出）

| 参考图 | 桶 | 位置 |
|---|---|---|
| 火元素 9236 | 元素/魔像 | assets/pics/9236.png |
| 水元素 9068 | 元素/魔像 | assets/pics/9068.png |
| 俄倪厄 9132 | 人形角色 | assets/pics/9132.png |
| 击退 9004 | 技能特效 | assets/pics/9004.png |
| 鸭子骑士 9001 | 鸭子 | assets/pics/9001.png |
| 惊奇盒子 9179 | 道具/物品 | assets/pics/9179.png |

## 出图方式

- `codex exec --json -C /e/work/card_rogue --skip-git-repo-check < <prompt文件>`
- 统一赛璐璐模板：cel-shaded / thin black line art / hard-edged 2-3 step shading /
  dark blurred background + bright subject；反面 NO photorealistic / NO 3D render / NO photographic texture。
- 出图后从 `thread_history_1.sqlite` 取 savedPath，`cardart_prep.py <图> <id>` 裁 448×403 进 pending。

## 图生图纪律（店长定，2026-11-10）

> 这批参考图**只用来参考「风格」**，角色、背景、姿势等等**全都不要照抄**。
> 参考图负责「画成什么风格」（赛璐璐/描边/平涂/暗底亮主体），不负责「画什么内容」。

- 图生图固定 `input_fidelity=low`（绝不用 high/medium）。
- 首句固定：`Use the reference image ONLY AS AN ART-STYLE REFERENCE: copy its drawing technique
  (cel shading, clean black line art, 2-3 flat tone steps, dark blurred background + bright subject).
  Do NOT copy its character, its scene, its pose, its composition, its props, its colour scheme.
  Paint a COMPLETELY DIFFERENT subject.`
- 每张卡的 prompt 仍要**完整写自己的设定**（角色/背景/姿势/道具/配色），不能只写「参考图风格 + 一个名词」。
- 验收：新图是赛璐璐、且内容是目标卡自己的设定；**放大到 ≥500px 再确认**（小屏会误判厚涂为合格）。
- 完整版见 `E:/work/.workbuddy/memory/ART.md` 末尾「风格参考图批次（R552）图生图纪律」。

## 教训

- ⚠️ 审查必须放大复确认：3×3 小屏把骷髅兵/灰烬龙/影子猫/集束炮台误判成合格，放大全是厚涂。
- 机械桶标杆从「集束炮台 9166」改成「素体 8025」（集束炮台是金属写实渲染）。
