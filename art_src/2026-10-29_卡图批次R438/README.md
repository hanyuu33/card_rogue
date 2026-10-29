# 2026-10-29 卡图批次 R438（8 张 · 盟友与工事优先）

批次登记在 `art_plan.json` 的 `batches`（`R438 · 盟友与工事收口 ×8（形象优先）`，active）。
台账对账唯一口：`python _art_index.py`。

## 选卡口径

R418 之后剩下的待做里，**技能 / 效果类（"疾风""潜伏""坚韧"）都是抽象概念**，一张图讲不清，
排后面；先收**有实体形象、每局都可能见到**的盟友与工事。

| 卡 | 职业 | 为什么是它 |
|---|---|---|
| 9026 陶瓷鸭 | 敌人 | 敌人侧最后一个待做；鸭子窑召唤链（9022 鸭蛋 / 9177 宠物鸭）的成品 |
| 8007 影魔 | 暗影刺客 | 4 费核心，技能牌减费体系的地基 |
| 8009 潜影者 | 暗影刺客 | 2 费起点单位，每局必见 |
| 8024 契约签订者 | 暗影刺客 | 3 费费用引擎（登场回 4 费） |
| 8015 机关工坊 | 暗影刺客 | 唯一待做工事，场地卡抽卡 + 被拆反伤 |
| 8050 旧式机兵 | 机械之心 | 超负荷的招牌（负血不倒），新手最先认识的那台 |
| 8060 代达罗斯 | 机械之心 | 4 费嘲讽，聚能炮击体系；图可被 8074 量产型复用 |
| 8072 谟涅摩叙涅 | 机械之心 | 4 费改造体系核心；图可被 8075 量产型复用 |

同批口径调整（已写入 `art_plan.json` 的 `skip`）：
- **9201 舰炮 / 9202 电磁屏障 / 9203 紧急呼叫** —— 启示者三阶段被动，引擎按 `enemy_effects`
  常驻，战斗界面只画**特效**（激光 / 护盾 / 召唤）不画卡面 → 与 9013/9015/9024 同口径，不出图。
- **9178 永夜** —— 敌方被动效果卡，规则载体，不占格子。
- **8074 / 8075** —— 量产型，与本体 8060 / 8072 共用形象。

## 出图记录

统一前缀：`Japanese anime cel-shaded illustration…` + 每张末尾
`NO text / NO logo / NO watermark / NO black frame / NO vignette / NO letterbox / NO matte border`
（R437 教训：模型会自己套黑色画框，必须点名否定）。

| 时间 | 卡 | 提示词要点 | 结果 |
|---|---|---|---|
| 12:53 | 9026 陶瓷鸭 | 青釉冰裂瓷鸭 + 裂纹漏橙光 + 窑内砖拱 + 两侧未烧泥鸭 | v1 采用 |
| 12:54 | 8007 影魔 | 纯黑影 + 四臂钩爪 + 只有两点紫眼 + 三块紫色卡形光片被丝线牵着 | v1 采用 |
| 12:54 | 8009 潜影者 | 贴地低伏、半身沉入地面墨影、紫边轮廓 + 反手短刃拖紫光 | v1 采用 |
| 12:54 | 8024 契约签订者 | 兜帽掮客 + 展开的长卷轴 + 浮空羽笔 + 琥珀色费用光点 | v1 采用（点名卷轴**空白**，出来是符文环，无文字） |
| 12:55 | 8015 机关工坊 | 木构工坊 + 弹簧尖刺陷阱 + 齿轮组 + 紫油灯 + 三块成品陷阱板；**点名画面无人物** | v1 采用 |
| 12:56 | 8050 旧式机兵 | 锈蚀铁甲 + 掉板露铜线 + 胸口暗红炉栅 + 单臂焊补铁拳 + 膝部裂开接线；**要求站着不塌** | v1 采用 |
| 12:56 | 8060 代达罗斯 | 青灰重钢 + 胸心青色单眼 + 双臂变形塔盾交叠挡前 + 方形肩炮 + 背部能量导管 | v1 采用 |
| 12:56 | 8072 谟涅摩叙涅 | 瓷白装甲 + 半张无面罩板（单眼）+ 头顶齿轮圣物光环 + 折页状臂甲 + 抬手空掌 | v1 采用（点名"clearly a construct, not a human girl"） |

**处理链**：`_preview448.py` 出 448 预览（`art_src/_review/<id>_卡面预览448.png`）
→ 用户点头 → `process.py` 写 `assets/pics/<id>.png`（切底 11% 去水印 → 1.1117 cover → LANCZOS 448×403）。

`art_src/_review/R438_sheet.png` = 8 张 4×2 拼图（自检 + 交稿用）。

raw 全部保留。

## 复用的提示词骨架

```
Japanese anime cel-shaded illustration for a dark fantasy card game.
Thick clean ink linework, flat cel shading with crisp rim light,
rich dark desaturated background, single subject centered and filling
most of the frame, high contrast so it reads clearly when shrunk to a
110-pixel card thumbnail. Subject: <主体逐条形状特征>. Background: <场景+光位>.
NO text, NO letters, NO logo, NO watermark, NO black frame,
NO vignette, NO letterbox, NO matte border.
```

三处可复用的压话：
1. 「**110-pixel card thumbnail**」—— 明确告诉模型最终观看尺寸，它才会把主体做满、对比拉高。
2. 工事 / 道具类加「**Absolutely NO people, NO characters, NO hands**」，否则必塞人。
3. 人形构装体加「**clearly a construct, not a human girl**」，否则会给一张人脸。
