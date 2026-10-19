# 2026-10-19 · 卡图批次 B（初始卡组缺口 ×2）

## 这两张为什么要先做

8027 升级、9086 终结都**开局就在初始卡组里**，每局必见。数量少、曝光高，插队先做掉最划算。

## 口径（用户定的）

- **8027 升级**：机械之心的角色，正在**修理机器人**的样子。
- **9086 终结**：暗影刺客手持匕首**向前刺冲**，冲到机器人**背后**（双方**背对背**），
  刀光**一路划过**。

## 角色一致性（照现有锚点）

| 角色 | 锚点 | 外观要点 |
|---|---|---|
| 机械之心 | `8002_mech.png` | 黑长直 + 圆框眼镜 + 米色开衫 + 白 T，冷蓝色能量（浮游炮同色） |
| 暗影刺客 | `8002_shadow.png` | 紫黑兜帽斗篷 + 紫色饰边 + 黑色紧身衣裤/皮靴 + 紫光短刃 |
| 素体机械人（共同受术对象） | `8025 素体` | 深铁灰铆接装甲 + 外露关节 + **单只蓝色发光眼** + 齿轮与线缆 |

> 两张共用同一套机械人描述（`dark iron plates / riveted metal / exposed joints / single glowing blue eye`），
> 这样在卡册里能认出是同一台「素体」。

## 逐张主体描述

| id | 卡名 | 主体描述 |
|---|---|---|
| 8027 | 升级 | 机械之心少女**蹲在工作台边修一台人形机械素体**：素体胸腔打开露出齿轮与线缆，她一手扳手、一手小螺丝刀伸进胸腔，**蓝色能量丝从指尖流向机器**，肩甲正在被「长」出新的装甲板；工坊里散落工具与零件，暖黄台灯 + 冷蓝机器光 |
| 9086 | 终结 | **侧向动作镜头**：刺客向画面左侧**冲刺、压低身体前倾、右臂完全伸直刺出匕首**，脸朝奔跑方向、斗篷与头发向后飞；机械人就贴在她背后**背对背**，胸肩被切开、火花与碎齿轮迸射；一道**紫白色刀光沿她的行进路线斜贯整个画面** |

## 通用提示词后缀

```
FULL-BLEED background: … fills the entire frame edge to edge, no white background,
no white border, no vignette, no fade to white. Japanese anime cel-shaded
illustration, clean crisp lineart, flat colors with sharp highlights, no text,
no watermark, no frame, no border, trading card illustration, square composition
```

- 8027 主体占约 75%，9086 是双人动态构图，不给「居中单主体 + 留白」的写法。
- **`FULL-BLEED … no vignette, no fade to white` 必带**（山猫教训：背景渐隐到白铺到卡面就是白边）。

## 出图记录

- 8027：1 张过。
- 9086：**3 张候选**。
  - 候选 0（`An_anime_female_assassin_…`）：刺客大头回头、机器人背后被贯穿。小图辨识度高，
    但姿态是「站定回眸」，不是**前刺冲刺** → 弃用。
  - 候选 1（`Side_view_action_shot_…`）：侧视冲刺、匕首前伸 → 动作对，**但构图不合格**：
    机器人是**正面朝镜头**，刺客只是背贴着它的胸口，两人朝向没有相反，读不出「背对背」。
    **用户否掉的就是这张。**
  - 候选 2（`STRICT_BACK_TO_BACK_pose__clas_…`，**采用**）：刺客朝左、机器人朝右，
    肩胛骨在画面正中相贴，脊柱平行、朝向相反；机器人主要露**背部与后脑**，
    只从肩上露出一点蓝色眼；紫白刀光从匕首处斜贯穿过机器人 → 背对背一眼可读。
- **教训（写提示词的硬规矩）**：只写 `back to back` 模型会画成「背贴胸」。
  必须把几何写成可执行的话：`shoulder blades touching at the exact center`、
  `spines pressed together`、`one faces LEFT, the other faces RIGHT`、
  `the automaton seen mostly FROM BEHIND`、`neither figure faces the viewer`。
- 三张原始图都留在 `raw/`，要回退改处理映射里的文件名即可。

## 处理流程（同批次 A）

1. 非白像素 bbox 裁边（这两张是满屏背景，bbox = 全图，不裁）。
2. **切掉底部 11%** 去掉右下角「AI生成 WORKBUDDY」水印。
3. 按 1.1117（448×403）cover 裁剪 → LANCZOS 缩到 448×403。
4. 落 `assets/pics/<id>.png` → `--headless --import`。

## 验收

- `_art_index.py --batch` → 批次 B **2/2**；`--check` 通过；总进度 **27 有图 / 185 待做 / 20 暂不做**。
- 拼图 `_r250_batchB_check.png` 逐张看过：无白边、无水印、主体完整。
- 卡面实拍 `_r250_gallery_8027.png` / `_r250_gallery_9086.png`（图鉴里点开看，图已替换）。
- 回归：engine 2875 / reward 26 / bgm 31 / smoke 36 全绿（只加素材，不动逻辑）。
