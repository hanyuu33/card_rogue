# R765 巧克力图标改版（锡纸包一半 + 咬一口）

> 2026-11-16 · 店长指令：「巧克力的图标依然不够明确能看出是巧克力。委托 codex 重新生成，
> 生成有锡纸包住一半、被咬一口的版本」
>
> ⚠️ **轮次号让号记录**：开工时扫号只看了 `git status` 的**路径**，没看文件内容 ——
> 并行线已把 R764 写进 `sfx.gd` / `settings_scene.gd` / `test_engine.gd`（「音效硬闸」那个功能），
> 所以本线**让号到 R765**，目录、脚本、文档已全量改齐（`tools/_patch_r765_rename.py`，残检 0）。

---

## 问题定位

`assets/ui/chocolate.png`（R128 出的，320×130）是一整块**规整的 6×2 格金黄板**：

| 症状 | 原因 |
|---|---|
| 缩到 52×24 后像金条 / 键盘 / 饼干 | 只有「矩形 + 网格」两个特征，且棕调偏黄偏亮 → 与金币、宝箱同一套色，缺食物专属特征 |
| 没有任何「被人吃过」的信息 | 满格状态 → 看不出是可消耗的行动力资源 |

判定：不是画得不好，是**特征不够**。多格板这个形状本身没有排他性，
必须加两个「只有巧克力才有」的符号 —— **锡纸** 与 **咬口**。

## 出图（委托 codex，纯文生图）

管线复用 R690 / R663 / R577b / R562：代理 7897 → `codex exec --json` → prompt 走 stdin →
从 JSONL 里取最后一张图 → 重试 2 次 → 增量落盘。

- prompt：`prompts/choco.txt`（一份，两个候选共用）
- 关键段：横向长轴、2 行分格、**左半锡纸（冷银灰 + 三角折面 + 锯齿撕口翻开）**、
  **右端一个大咬口（圆弧凹陷 + 断面浅色 + 碎屑）**、纯白底、禁文字 / 禁人手人嘴人牙
- 尺寸诉求：方图 1024，物体占宽 78% / 高 34%（≈ 2.3:1，贴近 HUD 的 52×24 = 2.17:1）
- 两个候选都在 90 秒内一次过、零重试（15:15:40 起跑，15:18:35 收工）

| 候选 | 构图 | 结论 |
|---|---|---|
| `choco_a` | 锡纸占左 ~38%，巧克力 4 列，咬口在右端中部 | **定稿** |
| `choco_b` | 锡纸占左 ~45%（更厚重），咬口在右上偏中、齿痕更明显 | 候选（锡纸占比大 → 棕色主体被压窄，小尺寸下弱一档） |

选型依据是**缩到 52×24 再放大 8 倍**比出来的，不是看原图（`_review/_hud_3way.png`）——
这一轮的问题本来就出在小尺寸可读性上。

## 后期

`_finish.py`：边缘 4-连通 flood-fill 去背（TOL 30）→ bbox 裁 → 等比装进 **320×148**
（= HUD 的 52×24，比例 2.1667:1）→ 居中留边。

⚠️ **判据不用亮度**：锡纸是银灰高光，按亮度抠会把锡纸一起吃掉。用「与边缘背景色的 RGB 距离」
且**只吃连通到四边的像素** —— 锡纸被黑描边围住，内部反光不会被误伤。
定稿实测半透明边缘环 2504 px、平均亮度 138.9（深描边为主，无白毛边）。

### 定稿还多做了一步调色（已内置进 `_finish.py`）

原样出图放在地图的深绿面板上偏灰（锡纸灰 + 巧克力暗棕，两头都不跳）。定稿加了
`TONE = (1.09, 1.07, 1.20)`（Brightness / Contrast / Color，**alpha 通道原样保留**），
产物 `processed/choco_a_warm.png`。

复现一致性已验证：脚本重跑后 `assets/ui/chocolate.png` 的 md5 与手调那版逐字节相同
（`5566c746ac5151240df68efb25c88974`）。**原样版 `processed/choco_a.png` 也留着，一句话就能换回**。

## 验收

| 项 | 结果 |
|---|---|
| 落地 | `assets/ui/chocolate.png` → **320×148 RGBA**（原 320×130） |
| 显示 | `map_scene._draw_choco_icon()` 走 `CardFace.fit_rect` **等比**，比例变化不拉伸，代码零改动 |
| 实机截图 | `scenes/map.tscn -- --screenshot --layer 1 --shotwait 0.8` → `_review/_map_hud_zoom_final.png` |
| 前后对比 | `_review/_before_after.png`（深绿底、52×24、8 倍放大，BEFORE/AFTER 并排） |
| 候选对比 | `_review/_hud_3way.png` / `_review/_hud_tone.png` / `_review/r765_choco.html` |

缩到 HUD 真实尺寸后：银纸皱褶成一个明确的高光块、棕色主体更宽更暖、右侧咬口留出可见缺口 ——
「包着的巧克力被咬过」这条信息在 45×22 px 内成立。

### 回归（2026-11-16 15:2x）

`_verify.py` 八套全绿：assemble 0 失败 / mana PASS / engine **6226✓ 0✗** / reward 26 / bgm 39 /
traps 183 / trapinput 70 / smoke 75。跑前备份 `_bk_r764_userdata`（含 `.gdignore`），
跑后还原 `profile.json` / `battle_records.json` / `run_records.json`。

本轮**零逻辑改动**（只换一张 png + 重导入），回归是照纪律走的，不是被改动逼出来的。

## 复现

```bash
P="C:/Users/Administrator/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
cd art_src/2026-11-16_巧克力图标_R765
"$P" -X utf8 _run_codex.py                    # 出图（已有成品自动跳过）
"$P" -X utf8 _finish.py                       # 干跑：切图 + 对比页
"$P" -X utf8 _finish.py --pick choco_a --write # 落地（然后跑一次 --import）
```

## 文件清单

- `prompts/choco.txt` · `_run_codex.py` · `_finish.py` · `_batch.log` · `_progress.txt`
- `raw/choco_a_codex.png` · `raw/choco_b_codex.png`（1024 方图原档）
- `processed/choco_a.png`（原样）· `choco_a_warm.png`（定稿）· `choco_b.png` · `_old_chocolate_R128.png`（旧版存档）
- `_review/`：`_hud_3way.png` `_hud_tone.png` `_before_after.png` `_map_full.png`
  `_map_hud_zoom.png` `_map_hud_zoom_final.png` `r765_choco.html`
