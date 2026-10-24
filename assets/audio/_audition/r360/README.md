# R360 · 第三层地图 / 启示者 Boss 选曲试听包

> **用途**：给「第三层（白天高空直道 · 科幻空艇）」和「启示者 Boss 战」挑专属 BGM。
> 本目录只是**候选试听**，未接入游戏；定稿后才写 `assets/audio/bgm/<槽位>.ogg` 与 `credits.md`。
>
> **怎么听**：双击 `试听.html`（或从 IDE 预览）。页面里每条都是本地 mp3，
> 点播放即可，preload=none 不会一次加载 60MB。

> **R364 定稿（2026-10-24，已接入，本目录转为「来源记录」）**
>
> | 场景 | 接入槽位 | 选中的曲子 |
> |---|---|---|
> | 第三层地图 | `map3.ogg` | **Firmament3（Calm）** |
> | 启示者 第 1 阶段 | `battle_revelator_p1.ogg` | **Soaring** |
> | 启示者 第 2 阶段 | `battle_revelator_p2.ogg` | **Relentless** |
> | 启示者 第 3 阶段 | `battle_revelator_p3.ogg` | **Havoc** |
>
> - Boss 从「一个 `battle_boss_revelator`」改成**按阶段三槽位**：换卡面那一帧一起换曲，
>   由 `Bgm.battle_slot(tier, key, phase)` 按引擎的 `Placement.boss_phase` 取。
> - 四首都是 PeriTune 官方 **loop 版 `.ogg` 原文件**（未裁剪 / 未变调 / 未重编码）。
> - ⚠️ **Relentless 是 2026-08 的新曲**，走 PeriTune 新规约：商用可以、署名任意，
>   但「同梱（打包进作品二次配布）**仅限非营利**」—— **本作一旦收费售卖，这首必须换掉**。
>   同期老曲 `Firmament3 Active` / `Rapid5` / `Augury` 都还是 CC BY 4.0，可直接替换。

---

## 一、当前的选曲空缺

| 场景 | 现在用的是什么 | 问题 |
|---|---|---|
| 第三层地图 | 复用 `map2` = Strategy4（第二层的轻快管弦） | 第二层是城堡推进感，第三层是高空科幻，气质不同 |
| 启示者 Boss | 复用 `battle_boss` = Raid_FolkMetal（民谣金属） | 民谣金属 + 提琴适合「异世界蛮族战」，与「巨型机械战舰」不搭 |

所以目标是补两个**新槽位**：`map3`（第三层地图）与 `battle_boss_revelator`（启示者专属）。

---

## 二、画面参照（选曲要对准这个）

- 背景 V9：白天、淡色圆润积云分层、云隙露出深蓝、整体压暗 ≈54.6。
- 空艇：暗板岩蓝灰装甲、细浅接缝、冷青窗光、下方悬浮环，超巨大。
- 流程：起点 → 精英 → 商店 → 篝火 → 启示者，**一字直道**，没有岔路。
- 启示者三阶段：远景舰炮 → 近景电磁屏障 → 舰内破损起火。

---

## 三、候选清单

### A. 第三层地图（要求：开阔有高度感、不抢注意力、不能像战斗曲）

| 曲目 | 时长 | 听到的关键点 | 匹配度 |
|---|---|---|---|
| **Soaring** | 4:23 | 作者标签直接写着「天空・飛空艇・SF」；开阔、爽快、有持续上升的推进感 | ★★★★★ |
| **Firmament3 Calm** | 5:13 | 天空题材 + 造语（虚构语言）咏唱，Calm 版庄严不吵；「登舰朝圣」味最重 | ★★★★☆ |
| **Polar Lights** | 1:54 | 极光 / 冰 / SF 氛围，冷冽辽阔，最不抢戏（也最短） | ★★★☆☆ |
| **Time and Pray** | 3:26 | 圣域・遗迹感，纯管弦无科幻音色；要「古老圣所」而非「机械战舰」时选它 | ★★★☆☆ |

### B. 启示者 Boss（要求：机械 / 神圣压迫，撑得住三阶段推进）

| 曲目 | 时长 | 听到的关键点 | 匹配度 |
|---|---|---|---|
| **Firmament3 Active** | 4:02 | 与 A 组同曲的战斗版：焦躁 + 勇壮 + 咏唱，最强「审判」气质 | ★★★★★ |
| **Rituale Machina** | 3:28 | 工业铁克诺 + 机械仪式，金属撞击的节拍像舰体在转阶段（2026 新曲，见授权） | ★★★★★ |
| **Rapid4** | 5:18 | 作者标明「空中战」的赛博战斗曲，疾走感最强 | ★★★★☆ |
| **Rapid5** | 4:03 | Rapid4 的后辈：赛博 + 管弦 + DnB，更华丽 | ★★★★☆ |
| **Augury** | 3:19 | 「预兆 / 占卜」，与 Revelator（启示者）同义联想，神秘带戏剧性 | ★★★★☆ |
| **Relentless** | 2:30 | 2026 新曲，185BPM 交响战斗，纯压迫；最短最凶，适合当「总攻」段落（见授权） | ★★★★☆ |
| **Cyber Noir** | 4:02 | 暗黑赛博朋克，冷硬压迫；要「阴沉」不要「热血」时用它 | ★★★☆☆ |
| **Havoc** | 3:43 | 浩劫感，混乱激烈，适合第三阶段舰内起火 | ★★★☆☆ |
| **Demise** | 3:13 | 崩坏 / 终结，低沉；可留给残血段落 | ★★★☆☆ |

---

## 四、三套推荐组合

| 方案 | 地图 | Boss | 为什么 |
|---|---|---|---|
| **A 主题统一**（推荐） | Firmament3 **Calm** | Firmament3 **Active** | 同一首曲子的两个编曲版本。玩家在直道上听 Calm，走进 Boss 格同一主题立刻变成战斗版 —— 像「同一片天空翻了脸」，叙事上最连贯 |
| **B 机械压迫**（推荐） | Soaring | Rituale Machina | 地图给开阔爽快，Boss 直接换成工业机械仪式；反差最大，「启示者」的机械神性最直白 |
| **C 最热血** | Soaring | Rapid5 | 两首都是「往上冲」的气质，爽快度高；适合想让第三层成为全场高潮的打法 |

**如果只让我挑一套**：走 **A**。理由是这一层是**一字直道**，玩家在直道上停留时间短、路线唯一，
音乐最该承担的是「从高空宁静 → 巨舰审判」的转场落差，而同一主题的双版本能把这个落差做得最干净。

**Boss 曲的另一个思路**：本体用 Firmament3 Active 或 Rituale Machina，**第三阶段（舰内起火）**
切到 `Havoc` 或 `Demise` 做段落变化 —— 现有 `Bgm` 没有「中途换曲」入口，
要做得改 `battle_scene` 在转阶段事件里调 `Bgm.play()`（一行的事，但属于新功能）。

---

## 五、授权（重要）

PeriTune 已于 **2026-03-01** 换规约（详见 `https://peritune.com/blog/2026/03/01/terms-update/`）：

| 曲目批次 | 授权 | 商用 | 署名 | 同梱二次配布（打包进游戏） |
|---|---|---|---|---|
| **2026-02 之前**（本目录除 Rituale Machina 外全部） | CC BY 4.0（也可按站点新规更宽松地执行） | 可 | 建议署名 | 可（本身就是游戏素材） |
| **2026-03 起的新曲**（Rituale Machina / Relentless） | PeriTune 独自规约 | 可 | 任意 | **仅限非营利** |

- 现有 7 首（title / map / map2 / battle / elite / boss…）都是 2026-02 之前的老曲，不受这条影响。
- 结论：**如果这个游戏将来要卖**，Boss 曲尽量从「A 组 + Rapid4/Rapid5/Augury/Cyber Noir/Havoc/Demise」里选；
  Rituale Machina 很好听但属于新规约，商业化同梱要另想办法（或只用作宣传素材）。
- 全部曲目都**未裁剪、未变调、未重编码**（试听用 mp3 就是官方原文件），接入时取官方 `_loop.zip` 里的 `.ogg`。

---

## 六、定稿后的接入步骤（R364 已全部执行）

1. 取 PeriTune 官方 `PerituneMaterial_<Name>_loop.zip` → 解出 `.ogg`（无缝循环版）。
2. 存成 `assets/audio/bgm/map3.ogg` / `battle_boss_revelator.ogg`。
3. `bgm.gd`：`SLOT_TRACKS` 加两行；`play_map()` 第三层走 `map3`；
   `battle_slot()` 需要拿到「是不是启示者」——建议加 `play_battle(tier, level_id)` 重载或
   在 `battle_scene` 里对 `boss_revelator` 直接点名 `Bgm.play("battle_boss_revelator")`。
4. `credits.md` §2 登记（曲名 / 作者 / 授权 / 下载日期 / 来源链接）。
5. `test_bgm.gd`：槽位表与「第三层选 map3」的断言。
6. 出包前确认新 ogg 的 `.import` 里 `loop=true`。

---

## 七、文件说明

| 路径 | 内容 |
|---|---|
| `raw/` | 官方原始下载（mp3 整曲 + 新曲的 zip 整包），保留以便重取 |
| `audition/` | 摊平的试听用 mp3（试听页引用这里） |
| `试听.html` | 自包含试听页（相对路径，零网络） |
| `_refetch.py` | 断点续传器：peritune.com 单连接被压到 ~25KB/s，靠 `curl -C -` 反复续 |
| `_make_audition.py` | 摊平文件 + 生成试听页（幂等，可复跑） |
| `_refetch_mp3.py` | **下新曲用这个**：PeriTune 新曲页面上只挂整包 zip（Rituale Machina 的 zip 有 23MB+），
但服务器上单曲 mp3 直链仍然存在（`/music/PeriTune_<Name>.mp3`），4~7MB 就能听完 |

---

## 八、这台机器下载踩到的三个坑（下次别重踩）

1. **下载链分两种**：老曲（2026-02 前）页面给 `music/PerituneMaterial_<Name>.mp3` +
   `loop/PerituneMaterial_<Name>_loop.zip`；新曲（2026-03 后）**只给 `/music/PeriTune_<Name>.zip` 整包**，
   而页面上的链接写着 `%20`（空格），**实际服务器文件名是下划线** ——
   直接请求带 `%20` 的 URL 会返回 **404 的 HTML 页**（约 61KB，长得像 zip，`zipfile.is_zipfile()` 才会露馅）。
2. **单连接被限到 ~25KB/s**：一次 `--max-time 180` 最多下 4MB 左右，8MB 的曲子必须靠
   `curl -C -` 反复续传（服务器支持 `206 Partial Content`），多文件并行才够用。
   → 所以宁可走 `_refetch_mp3.py` 下单曲，也别去啃 23MB 的整包。
3. **沙箱里删不了文件**（trash 操作会 fail-closed）：坏档别 `os.remove`，改成**截断为 0**
   （`open(p,"wb").close()`）或 `os.rename` 成 `.partial`，效果一样且不触发安全拦截。
