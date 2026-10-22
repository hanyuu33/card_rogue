# 2026-10-22 卷卷（起点事件）UI 素材

配套 CG 见 `../2026-10-22_豚鼠吟游诗人CG/`（卷卷本体，玩家日式动漫那一版）。

## 成品（已落 `assets/ui/`）
| 文件 | 源图 | 说明 |
|---|---|---|
| `bg_curtain.png` | `../2026-10-22_豚鼠吟游诗人CG/CG_guinea_pig_bard_anime_2560x1440.png` | 整屏背景，1920×1080 → 压到 1600×900 |
| `curtain_box.png` | `FULL_BLEED_horizontal_dialogue_…07-47-57.png` | 羊皮纸对话框 1300×603，中心留白写字，左右藤蔓/雏菊/音符角饰 |
| `curtain_plate.png` | `FULL_BLEED_small_horizontal_na_…07-48-30.png` | 名称牌 520×124，左端常春藤 + 音符、四角铜钉 |
| `curtain_hero_forest.png` | `EXACT_SAME_CHARACTER_…07-54-13.png` | 立绘 467×760（森林精魄） |
| `curtain_hero_rogue.png` | `EXACT_SAME_CHARACTER_…07-54-39.png` | 立绘 516×760（暗影刺客） |
| `curtain_hero_mech.png` | `EXACT_SAME_CHARACTER_…07-55-07.png` | 立绘 276×760（机械之心） |

> ⚠️ **R310 修订（用户口径）**：三张立绘**不再接入游戏**（`assets/ui/curtain_hero_*.png` 已删除），
> 二层回答改成只换名称牌 + 台词。源图仍留在本目录（`EXACT_SAME_CHARACTER_…png`），要恢复直接
> 重新拷回 `assets/ui/` 并跑 `--headless --import`。背景图改为**等比完整显示**（不拉伸、不裁切）。

## 处理链（`_make_curtain.py` → `_recut.py`）
1. 洋红底出图（**直接要透明底会被画成棋盘格**，`assets/ui/图片命名说明.txt` R154 的老结论）。
2. 四角洪水填充标洋红 → 4px 采样 + 只保留最大连通块（顺手干掉水印小岛）。
3. **去洋红溢色**：`d = min(r,b) - g`，`d>=62` 直接透明、`3<d<62` 把绿抬到 `min(r,b)-6`
   （残留的粉边变成纸灰，不留下品红圈）。
4. **裁投影**：素材底边与左右两端那条「洋红上画的投影」会被抠成暗紫红，洗不掉 →
   沿底边裁 5.5%（对话框）/ 10%（名称牌）、左右各裁 1.2%。
5. 立绘额外 `kill_rect` 抹掉右下角「AI生成 / WORKBUDDY」水印（它在洋红区里，颜色是灰白，
   既抠不净也留不得），再按高 760 缩放。

## 出图提示词
### 对话框
```
FULL-BLEED horizontal dialogue box panel for a fantasy visual novel UI, wide banner shape,
isolated on a PURE MAGENTA background (hex FF00FF), no text / letters / watermark.
Light cream parchment with soft paper fibre texture, thin antique gold double border with
delicate corner flourishes, ivy vines + tiny golden musical notes + pale daisies tucked into
the four corners and the far left / right ends, edges slightly uneven and hand-painted,
faint five-line musical staff along the very bottom edge. The MIDDLE 80 percent must be
completely clean empty parchment (text is drawn on it). Painted Japanese fantasy anime game
asset style, warm cream and gold palette, soft cel shading, clean lineart.
```

### 名称牌
```
FULL-BLEED small horizontal name plate banner for a fantasy visual novel UI, roughly 3:1,
isolated on a PURE MAGENTA background (hex FF00FF), no text / letters / watermark.
Aged cream parchment label, thin antique gold frame line, one carved ivy leaf and a tiny
golden musical note on the LEFT end only, brass rivet in each corner, bottom edge slightly
hand-torn, very soft shadow. CENTRE must be clean empty parchment (a name is printed on it).
Painted Japanese fantasy anime game UI asset style, warm cream and antique gold palette.
```

### 立绘（以 `assets/ui/class_cg_<key>.png` 作 image1，`input_fidelity=high`）
```
EXACT SAME CHARACTER as the reference image - keep her hair colour, face, outfit and
proportions identical: <该职业的外形描述>.
Full-body standing portrait, three-quarter view, <动作 / 表情>, clean silhouette fully
inside the frame with generous margin.
Isolated on a PURE MAGENTA background (hex FF00FF). Absolutely no text, no watermark,
no background shadow, and no magenta colour spill or pink reflection on the character.
Japanese anime illustration, soft pastel watercolour cel shading, delicate lineart.
```

## 踩坑
- 立绘**不能**从 class_cg 硬抠：原图角色与背景连成一片（森林 / 石板街 / 书架），
  裁剪 + 羽化会带一块背景进来。改成「参照重绘 + 洋红底」，角色保真且边缘干净。
- 洋红底上画的「投影」会变成暗紫红，`d` 判据抓不到（`b` 低、`g` 也低）→ 只能裁掉。
- 只清 `d>=40` 会留下一圈浅粉边；必须把 `3<d<62` 的像素也去溢色。
