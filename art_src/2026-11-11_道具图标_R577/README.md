# R577b · 道具小图标（60 件）

> ⚠️ **轮次让位**：本线原编号 R577，与已提交的「R577 Steam 成就 AppID 接入」（`a3d17b1`）撞号，按项目惯例让位为 **R577b**。
> 中途曾让位为 R579，但并行会话又抢先提交了 `4ff9355 R579 标题页去掉副标题`，故最终定为 **R577b**；
> 归档目录 `art_src/2026-11-11_道具图标_R577/` 是历史路径，脚本里硬编码，不再改名；
> `test_engine.gd` 里 34102 行往后那批 R577 AppID 断言属于另一条线，未改动。

用户口径（2026-11-11）：

> 目前，道具都是文字展示。需要换成小图标展示。右侧堆叠方式不变但是换成图标。
> 图标需要是无背景 png。奖励领取页面换用那个道具的图标，事件中链接到道具文本的文字也要带上图标。
> 委托 codex 批量生成图标。

## 一、出图契约

- **一律委托 codex**，复用 R562 管线（`art_src/2026-11-10_机械之心放量_R562/_run_batch.py`）：
  `codex exec --json --skip-git-repo-check -C <root>`，prompt 从 **stdin** 喂，产物从 JSONL 里
  的 `~/.codex/generated_images/<thread>/exec-*.png` 拷回。
- **纯文生图，不带 `-i`**（不挂任何参考图）。60 张 = `relics.json` 的 6001~6060。
  三样信物（6061 完美螺钉 / 6062 生命之种 / 6063 屠戮匕首）**不重出**：R543 已有
  `key_icon_{screw,seed,dagger}.png`，由 `UiAssets.relic_icon()` 自动回退。
- 代理 `http://127.0.0.1:7897`（Clash Verge 主程序 `D:\新建文件夹\clash-verge.exe`，只跑
  service 不会有监听）；可用 `CODEX_PROXY` 覆盖。`_run_codex.py` 会**先真连一次 HTTPS**
  再开工，`HTTPError 403` 算链路通（Cloudflare 挡 Python 默认 UA，curl 带 UA 是 200）。
- 画风：粗黑描边 / 平涂两级明暗 / 低饱和冷灰蓝 + 一处暖点 / 单个居中物体 /
  **纯白平底** / 禁止文字数字水印场景地面投影边框。
- 逐张写 `_progress.txt`，增量验收页只按「当前已存在的 raw」拼，不等整批。

## 二、后期（无背景 PNG）

`codex` 固定输出 1536×1024 的 **RGB 宽图、不带 alpha**，所以「无背景」由
`tools/_finish.py` 落地：

1. 四边采样取中位数当背景色；从**四边出发 flood-fill**（容差 38）只吃掉与背景色相近
   且连通到边缘的区域 —— 不用全局阈值，避免把物体内部的白（鸭绒 / 牛奶 / 绷带）抠掉。
2. 抗锯齿边缘按距离给半透明 alpha，避免白毛边。
3. 取非透明 bbox 裁出物体 → 加 6% 内边距补成正方形 → LANCZOS 缩到 **128×128 RGBA**。
4. `--write` 才把 `processed/relic_icon_<id>.png` 复制到 `assets/ui/`；`.import` 由
   Godot `--headless --import` 生成，不手写。
5. `coverage > 62%` 会打 WARN（疑似背景没去净），`_finish.py` 会列出来；
   `COVERAGE_OK_IDS = {6013}` 例外（满幅方形木箱，占比高属正常构图）。
6. ⚠️ `TOL_BY_ID = {6018: 10}`：白蛋蛋壳与纯白底只差约 17，默认容差 38 会穿透
   抗锯齿描边把蛋壳 flood 成透明（只剩黑轮廓，中心不透明率 2.4%）。
   实测 TOL=6/10 都保住完整白蛋且背景干净，取 10 留噪点余量；修后中心不透明率 100%。

验收：`tools/_sheet.py` 出棋盘格联系表、`_review/r577_icons.html` 是 base64 内嵌的增量页。

## 三、代码落点（唯一取图口 `UiAssets.relic_icon(id)`）

| 位置 | 改动 |
|---|---|
| `scripts/ui_assets.gd` | 新增 `relic_icon_path(id)` / `relic_icon(id)`；缺图返回 null；信物回退 R543 |
| `scripts/map_scene.gd` `_draw_relics()` | 右侧两列 98×26 槽位几何 / 滚动 / 悬停浮窗**全不变**，槽里改放 22px 图标；缺图回退原文字 |
| `scripts/battle_scene.gd` `_draw_relic_bar()` | 右栏 3×4 槽位 / 呼吸高亮 / +N 摘要全不变，槽里改放图标；缺图回退 R309 那套文字 |
| `scripts/reward_panel.gd` | 列表条目图标（64px）、领取详情标题右侧图标（56px）、大宝箱二选一左格改用该道具图标（旧写法传 `-relic_id` 恒返回 null，左格一直空着） |
| `scripts/relic_pick_scene.gd` | 起点三选一卡片顶部 56px 图标，名字基线 78→112、描述 116→150 |
| `scripts/event_scene.gd` `_on_tip_draw()` | 「」提到道具的名字右侧紧跟小图标；**只画在浮层上，不动 Label 排版**（R122 契约） |

⚠️ 保留文字绘制作为「缺图兜底」还有一层工程理由：`test_engine.gd` 的 R309 / R344 源码锁
按字符串守卫 `_draw_relic_panel()` 与 `outline = -1` 的绘制口，直接删掉文字会假红。

## 四、测试（`test_engine.gd` R577b 块）

按「数据层判据 + 界面分发 + 源码锁」三层一起加：

1. 数据层：遍历 `RelicRepo.all_relics()`，逐件 `ResourceLoader.exists(relic_icon_path(id))`
   （导出包里 png 会被 `.ctex` 取代，不能用 `FileAccess.file_exists`）。
2. **保真锁**：回到 `relics.json` 源文本核对 60 个 id，别让派生列表漂走（R565 口径）。
3. 取图口：首末两件都是 128×128；信物 6062 回退到 `key_icon_seed`。
4. 源码锁：四处界面都调 `UiAssets.relic_icon(`；地图 / 战斗两处保留 `if tex == null:` 兜底。

## 五、验收图

`_review/ingame_{map_relics,battle_relics,reward_relic,relic_pick,event_mention}.png`
——由 `tools/shoot_r577.py` 一次跑完**六处**实机截图（**必须带窗口**，`--headless` 下
`get_image()` 返回 null）。演示参数：`--relicrework` / `--relicmany` / `--relics` /
`--r119relic` / `relic_pick.tscn --screenshot` / `--apple`。
`shoot_r577.py` 支持只跑指定产物名（如 `python shoot_r577.py ingame_rework4.png`），
便于按增量节奏先交一张。

### 实机截图（2026-11-11 重拍，60 张全部落地后）

| 产物 | 场景 / 演示口 | 验什么 |
|---|---|---|
| `ingame_rework4.png` | `map.tscn -- --screenshot --relicrework --shotwait 0.8` | 四张返工同屏：6013 / 6018 / 6036 / 6045 |
| `ingame_map_relics.png` | `--relicmany` | 20 件堆叠，不挤固定 UI |
| `ingame_battle_relics.png` | `--relics --shotframe 600` | 战斗右栏 3 件 |
| `ingame_reward_relic.png` | `--r119relic --shotframe 600` | 领取详情标题右侧大图标 |
| `ingame_relic_pick.png` | `relic_pick.tscn --screenshot` | 起点三选一卡片顶部图标 |
| `ingame_event_mention.png` | `--apple` | 事件「苹果」提及文字内联图标 |

⚠️ `--relicrework` 是 R577b 追加的**纯演示口**（`map_scene.gd`，只写 `RunState.relics`），
正常玩法不会触发；四张返工原来分散在 6001~6060 里，现有演示参数没有一屏能同验到它们。
汇总页 `_review/ingame_all.html`、增量页 `_review/ingame_rework4.html`（base64 内嵌）。

## 六、目录

```
prompts/<id>.txt       63→60 份纯文生图英文指令（由 _gen_prompts.py 生成）
ICON_INDEX.md          id / 中文名 / 英文主体对照
raw/<id>_codex.png     codex 原始 1536x1024 RGB
processed/relic_icon_<id>.png   128x128 RGBA 无背景
_review/               增量验收 HTML / 联系表 / 五张实机截图
tools/                 _gen_prompts / _finish / _sheet / shoot / _patch / _run_regression
_run_codex.py          批量出图驱动（后台）
```

## 七、四张返工（店长 2026-11-11 口径）

| id | 名称 | 店长口径 | 落地 |
|---|---|---|---|
| 6013 | 叠加态的鸭 | 一个箱子，箱子上画着鸭 | 闭合木箱 + 正面**扁平**鸭头图案（印刷在箱板上，不是第二只 3D 鸭） |
| 6018 | 生蛋鸭 | 白蛋 | 完整白色实心蛋 + 右下淡蓝阴影，无斑点 / 裂纹 / 小鸭嘴 |
| 6036 | 思想钢印 | 目前构图有点不逻辑 | 原图把漩涡画在圆肚上、顶着紫色瓶塞，像香水瓶。改成**直立手持钢印**：蘑菇握柄在上、柱身嵌脑纹徽记、**宽平印面朝下** |
| 6045 | lucky 7 | 老虎机那种「7」的文字图标，只需要一个 7 | 红面金边老虎机 7，全图只有这一个数字 |

- 6045 是全套 60 张里**唯一放行数字**的一张：通用 `HEAD` 明令禁文字/数字，
  照抄会让模型收到互斥指令（要么不画 7，要么凑 777）。`_gen_prompts.py` 里单独做了
  `HEAD_LUCKY7`（`OVERRIDE_HEAD = {6045: ...}`），只放行「有且仅有一个 7」，其余禁词原样保留。
- 四张重出前把旧原图备份到 `raw_v1/<id>_codex_v1.png`（不删，供前后对比），
  旧成品在 `_review/before/`；对比页 `_review/rework4_compare.html`。
- 重出仍走 `python _run_codex.py 6013 6018 6036 6045`（纯文生图、无参考图、委托 codex）。

## 八、R577c 拆框放大（店长 2026-11-11 口径）

> 「不不不，不应该保留原本的框，直接用图标，并且大小也放大点。现在太不清晰了，
> 如果放大还是糊，从素材入手」

R577b 只是把 98×26 的**文字横条槽**里的字换成 22px 小图，底板 / 边框 / 来源色条都还在，
店长一眼看出这不是「直接用图标」。R577c 把槽位本身拆掉：

| 位置 | 拆框前 | 拆框后 |
|---|---|---|
| 地图右侧两列 | 98×26 横条 + `MapMaterial.draw` 底板 + 1.4px 边框 + 7px 来源色条，图标 22px | **46×46 正方形**，图标 `draw_texture_rect(tex, rect, ...)` 占满，步距 52 |
| 战斗右栏 3×4 | 98×26 横条 + 浅实色底 + 1.2px 边框 + 6px 来源色条，图标 22px | **44×44 正方形**，步距 x104 / y48；容量区域固定 232（12 格），绘制底板 `40 + rows*48` 按实际件数收拢 |

- **不再有常驻框**：地图悬停才画一圈柔和圆形浅底光晕（不是框）；稀有度信息移到悬停说明浮窗
  （浮窗本来就有名称 / 标签 / 彩色边框）。已耗尽仍画灰。
- **R314 呼吸高亮**从「矩形外框 + 提亮底 + 右端亮点」改成**图标外一圈青白圆环**
  （`draw_circle` 淡底 + `draw_arc` 描边），不再依赖矩形框。
- **缺图兜底**保留文字回退，但只在缺图时才画临时浅底；两条分支都不画常驻框。
- 战斗页保留的是**右栏整块区域底板**（HUD 分区），拆掉的是**每件道具自己的小横条框**；
  若连区域底板也要去掉，需先做深色图标在草地背景上的对比度验收。
- 奖励详情 56px / 起点三选一 56px 本来就够大，未改；事件内联图标跟随文字行高，
  放大就会盖住后面的「最大生命 +7」，保持原尺寸。

### 素材判定：不用重出

`.import` 是 `compress/mode=0`（lossless）、`mipmaps/generate=false`、`vram_texture=false`，
纹理本身无损；之前糊纯粹是被 22px 槽位缩没了。`size_22_vs_48.png` 把同一批图缩到
22px / 48px 再放大 6 倍，48px 下箱子鸭头、白蛋轮廓、钢印握柄、红金「7」倒角都读得出
→ **本轮没有动素材、没有委托 codex 重出**。放大后实机截图见 `_review/ingame_all.html`，
前后对比见 `_review/r577c_compare.html`（BEFORE 从 9428893 验收页的 base64 里还原）。

### 工程纪律

- 补丁 `tools/_patch_r577c.py` 可重跑（常量已落地即整体跳过）；从 `_bk_*_before_r577c.gd`
  重放后三个文件字节完全一致（`REPLAY_OK`）。
- ⚠️ 行尾：`map_scene.gd` = LF，`battle_scene.gd` / `test_engine.gd` = CRLF；
  往 CRLF 插 GDScript 一律显式 `
`，补丁后核对 `bareLF=0`。
- ⚠️ **容量契约不能跟着视觉改**：`test_smoke.gd::_check_overflow()` 锁的是
  「第 12 个徽章底部不越出 `_relic_zone_rect()` 下沿」。第一版把区域高度按件数收拢后
  空栏只有 88 高，smoke 立刻 1✗。最终改成**命中 / 契约用 z（固定 232）**、
  **绘制底板另算 `draw_z`（按实际行数）**，「鸭之低语」文字也改贴 `draw_z` 下沿 ——
  契约不动，空白也没了。
- ⚠️ 信物栏 `_draw_key_relics()` 有一模一样的 `hover_ok and rect.has_point(_mouse)` 判据，
  地图 hover 收口的锚点必须带上「图标占满 rect」那段绘制，否则会误改到信物栏。
- ⚠️ 源码锁断言里检查「绘制段内不再出现 `MapMaterial.draw(` / `draw_rect(chip` /
  `draw_rect(rect, scol, false`」，因此**这两段绘制的注释里也不能出现这些禁词**；
  两条缺图兜底分支只画浅底、不画边框，避免自我命中。
- `test_engine.gd` 新增 6 条：两段绘制边界可取 / 地图段无框且图标占满 / 地图常量 46×46+行距 52 /
  战斗段无框且图标占满 / 战斗动态高度与 44×44 / （与 R577b 的取图口断言共用源文本）。
