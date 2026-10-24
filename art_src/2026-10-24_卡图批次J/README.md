# 卡图批次 J · 月亮 + 硬币（R351 补图）

R351 新加的两张事件档效果卡，出图时用户只给了一句方向：**「月亮用满月，注意用动漫风格」**。

| id | 卡名 | 职业 | 类型 | 费·稀有 | 方向 | 结果 |
|---|---|---|---|---|---|---|
| 9180 | 月亮 | 通用 | 效果 | 3 费 事件 | 满月 + 动漫风格 | ✅ 2 稿 |
| 9181 | 硬币 | 通用 | 效果 | 1 费 事件 | 动漫风格 | ✅ 1 稿 |

## 主色 / 形状分工（两张都是圆的，靠构图拉开）

这是本批唯一的真实难点：**月亮和硬币形状都是圆形**，只换颜色不够（ART.md「同职业多张要
提前分配形状 + 主色」那条）。既然形状改不了，就在**画面层级**上分开：

| 卡 | 圆形占画面 | 构图类型 | 主色 | 背景 |
|---|---|---|---|---|
| 9180 月亮 | 宽约 55% | 风景 / 仰望 | 冷：淡象牙白 + 深靛蓝 | 有纵深（树枝剪影 + 山脊） |
| 9181 硬币 | 约 40% | 微距 / 静物 | 暖：金橙 + 深褐近黑 | 无纵深（纯暗底 + 台面倒影） |

一张是「抬头看天」，一张是「低头看手里的一枚东西」—— 缩到 77×92 也能一眼分开。

## 9180 月亮 —— 两稿

### v1（`raw/FULL_BLEED_anime_key_visual__s_2026-10-24T05-10-58.png`）
第一版整体成立（冷蓝夜空 / 满月 / 树枝剪影 / 云横穿月缘），但缩到 448 之后暴露两个问题：

1. **月面读成「被云覆盖的行星」**。月海写的是「两三块淡灰蓝斑」，模型给的是**大片灰白斑块**，
   形状像大陆板块 —— 配上顶部那条银河，第一眼是地球、不是月亮。
2. **银河（milky way）让画面花**，448 下变成一片噪点似的白雾，削弱了「唯一亮源」。

### v2（定稿，`raw/FULL_BLEED_anime_key_visual__s_2026-10-24T05-11-49.png`）
只改月面 + 天空，构图一点没动（v1 的构图本来就是对的）：

- 月面收成**接近单色**：`almost one flat pale ivory tone`，只留 `TWO very soft, very pale
  blue-grey smudges (thin and small, NOT big shapes)` + 四五个小环形山。
- **反面点名三次**：`NOT like a cloud-covered planet, NOT like Earth, NOT like a globe with
  continents` + `NO white cloud bands / NO continent shapes / NO landmass outlines /
  NO brown or grey mottled patches`。
- 天空 `NO milky way, NO galaxy band, NO nebula, NO dust clouds`，星星只留 `a FEW sparse`。
- 边缘光改成 `a narrow band of soft pale-blue light hugs the disc edge — just a thin anime
  rim light, NOT a big fuzzy halo`。

> 教训：**「月亮」和「魔力核心」要的东西正好相反。** 9076 那次的判据是
> `NO flat disc, NO lunar surface, NO craters, NO moon maria`（为了不像月亮）；
> 9180 反而**要**月海和环形山，但必须**小而淡** —— 「有斑」和「斑大到像大陆」是两回事，
> 缩到 448 才看得出来。

## 9181 硬币 —— 一稿过

- 主体写死 `EXACTLY ONE single thick gold coin — NOT a pile, NOT a stack, NOT a scatter`
  （不写这句必出一堆金币）。
- 立体感靠**币缘厚度 + 齿边可见**，币面浮雕是「细环里一圈三角光芒的太阳」，干净几何。
- **不刻字**：`NO letters, NO numbers, NO words, NO runes` —— 448 下刻字只会糊成噪点。
- 金属走**三阶硬边平涂**（奶白金高光 / 饱和金橙中间调 / 深暖褐阴影）+ 一道白色高光条 +
  一条细黑轮廓线；`NO ray-traced reflections / NO brushed-steel noise / NO chrome mirror`。
- 深暖褐近黑底 + 台面上一圈椭圆倒影，金币是画面唯一亮源。

## 处理链

切底部 11% 水印 → cover 1.1117 → LANCZOS **448×403** → `--headless --path . --import`。

出图用 1024×1024：切掉 11% 后是 1024×911 = 1.124，与目标 1.1117 几乎相同，
左右只裁 ~5px，构图不会被动。

成品：`assets/pics/9180.png`（195 KB）/ `assets/pics/9181.png`（168 KB）——
都比现有卡图的中位数（326 KB）小。

## 验收

- 卡框内出图：`art_src/_shots/_r351_card_9180_art.png` / `_r351_card_9181_art.png`
- 局部放大：`art_src/_shots/_r351_zoom_9180.png` / `_r351_zoom_9181.png`
- `_art_index.py --md` → 182 待做 / 22 暂不做 / **62 已完成**（+2）
- 五套回归全绿（图鉴总数与卡图数量无关，没有硬编码计数断言）

⚠️ **gallery 的 `--screenshot` 不能 `--headless`** —— 和 `deck_edit` 同一个坑：
dummy 渲染器下 `get_viewport().get_texture()` 返回 null，`save_png` 报 SCRIPT ERROR 且进程卡死。
要开窗口跑（这台机器有 GPU）。
