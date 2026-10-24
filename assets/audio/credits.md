# 音频素材署名登记表

> **合规文件，必须维护。**
> 每引入一首曲子，立即在此登记一行。
>
> 三重作用：
> 1. **法律**——满足 OpenTracks / 魔王魂 / PeriTune 的署名与条款要求
> 2. **可追溯**——曲库条款会变，记录下载日期即可回溯当时版本
> 3. **复用**——本表即游戏内「音乐来源」页面的数据源，不用来回抄

---

## 一、填写规范

| 字段 | 填写说明 |
|---|---|
| 场景 | 挂载位置（标题 / 角色选择 / 地图 / 战斗 / 精英 / Boss / 事件 / 奖励 / 胜利 / 失败） |
| 文件名 | `assets/audio/bgm/` 下的实际文件名（统一 `.ogg`） |
| 曲名 | 原曲标题（保留原文，便于检索与核对） |
| 作者 | 原作者名 |
| 来源库 | OpenTracks / 魔王魂 / PeriTune / 其他（写明） |
| 授权 | CC0 / CC BY 4.0 / 站点自有许可 |
| 需署名 | 是 / 否 |
| 已修改 | 是 / 否 —— **CC BY 4.0 要求：改过就必须声明** |
| 下载日期 | 记录，便于回溯条款版本 |
| 来源链接 | 单曲页 URL |

---

## 二、BGM 登记表

> **全部 7 首均为 PeriTune 官方「loop 版」整包里的 `.ogg` 原文件** ——
> 我们只做了「从 zip 里取出 ogg」这一步，**未裁剪、未变调、未重编码**，
> 因此「已修改」一律填 **否**（这不免除署名义务：PeriTune 是 CC BY 4.0）。

### 2.1 已接入（2026-10-16 起实装，`scripts/bgm.gd`；R364 起 11 首）

| 场景 | 文件名 | 曲名 | 作者 | 来源库 | 授权 | 需署名 | 已修改 | 下载日期 | 来源链接 |
|---|---|---|---|---|---|---|---|---|---|
| 标题页 | `title.ogg` | Holy_Place | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2019/04/05/holy_place/ |
| 角色选择 | `class_pick.ogg` | Piano_Refreshing | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2016/07/13/piano_refreshing/ |
| 第一层地图 | `map.ogg` | Poema | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2020/01/04/poema/ |
| 第二层地图 | `map2.ogg` | Strategy4 | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2017/01/08/strategy4/ |
| 一般战斗 | `battle.ogg` | Dramatic | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2015/05/21/dramatic1/ |
| 精英战斗 | `battle_elite.ogg` | EpicBattle | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2020/08/28/epicbattle/ |
| Boss 战斗 | `battle_boss.ogg` | Raid_FolkMetal | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-16 | https://peritune.com/blog/2019/08/26/raid_folkmetal/ |
| 第三层地图 | `map3.ogg` | Firmament3（Calm） | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-24 | https://peritune.com/blog/2020/07/01/firmament3/ |
| 启示者 第 1 阶段 | `battle_revelator_p1.ogg` | Soaring | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-24 | https://peritune.com/blog/2021/01/01/soaring/ |
| 启示者 第 2 阶段 | `battle_revelator_p2.ogg` | Relentless | PeriTune | PeriTune | **独自规约（2026-03 起）** | 否 | 否 | 2026-10-24 | https://peritune.com/blog/2026/08/10/relentless/ |
| 启示者 第 3 阶段 | `battle_revelator_p3.ogg` | Havoc | PeriTune | PeriTune | CC BY 4.0 | 是 | 否 | 2026-10-24 | https://peritune.com/blog/2018/08/01/havoc/ |

> **R364（2026-10-24）新增四首的授权要点**
>
> - `map3` / `battle_revelator_p1` / `battle_revelator_p3` 发布于 2020、2021、2018 年 ——
>   仍适用 **CC BY 4.0**：商用、加密、打包都可以，**必须署名 PeriTune**
>   （游戏内「音乐来源」页 + 商店页均需列出）。
> - ⚠️ `battle_revelator_p2`（Relentless）发布于 **2026-08**，走 PeriTune 2026-03-01 起的**独自规约**：
>   商用与署名都宽松（署名任意），但**「数据同梱（二次配布）仅限非营利」**。
>   也就是说：**本作一旦收费售卖，这一首必须换掉**（要换的话，同期的老曲
>   `Firmament3 Active` / `Rapid5` / `Augury` 都还是 CC BY 4.0）。
> - 四首全部为 PeriTune 官方 **loop 版 `.ogg` 原文件**（从官方 zip 里取出，未裁剪 / 未变调 / 未重编码），
>   因此「已修改」一律为 **否**。

### 2.2 未接入（拟定占位，尚未使用；曲名仅供参考）

| 场景 | 文件名 | 拟用曲名 | 来源库 | 状态 |
|---|---|---|---|---|
| 卡组编辑 / 图鉴 | `deck.ogg` | Teatime | PeriTune | 未选曲 |
| 暗影 Boss | `battle_boss_dark.ogg` | 霜蝶の夢 | OpenTracks | 未下载 |
| 事件 | `event.ogg` | Augury | PeriTune | 未选曲 |
| 奖励 | `reward.ogg` | Wish4 | PeriTune | 未选曲 |
| 胜利 | `victory.ogg` | ~~Soaring~~ | PeriTune | 未选曲（R364 起 Soaring 已用于启示者第 1 阶段） |
| 失败 | `defeat.ogg` | Grief 2 | PeriTune | 未选曲 |

> **当前状态（2026-10-16）**：上表 2.1 的 7 首**已实装** ——
> `assets/audio/bgm/*.ogg` 已入库、`.import` 全部 `loop=true`、
> autoload `Bgm`（`scripts/bgm.gd`）已在标题 / 选人 / 地图 / 战斗四处挂好。
> 选曲依据与备选清单见同目录 `选曲记录.md`；试听页 `_audition/试听_本地.html`。
>
> ⚠️ `assets/audio/_audition/`（含 485MB 候选曲 raw/）挂有 `.gdignore` ——
> **它是选曲工作区，不进导入表、不进发布包**，别把 `.gdignore` 删了。

---

## 三、SFX 登记表

> 当前音效为 `scripts/sfx.gd` **代码合成 PCM**（`AudioStreamWAV`），
> **不依赖外部素材**，因此下表暂空。
>
> 若后续引入外部音效文件，逐条登记。

| 用途 | 文件名 | 素材名 | 作者 | 来源库 | 授权 | 需署名 | 已修改 | 下载日期 | 来源链接 |
|---|---|---|---|---|---|---|---|---|---|
| _待填_ | | | | | | | | | |

---

## 四、署名文案模板

### 4.1 PeriTune（CC BY 4.0 — 必须署名）

**游戏内 credits 页面，每条一行**：
```
Poema by PeriTune | https://peritune.com/
License: Creative Commons CC BY 4.0
https://creativecommons.org/licenses/by/4.0
```

**若做过裁剪 / 循环 / 变调**（CC BY 4.0 强制要求声明）：
```
Poema by PeriTune | https://peritune.com/
License: Creative Commons CC BY 4.0
https://creativecommons.org/licenses/by/4.0
Modified: looped and trimmed for in-game use.
```

### 4.2 魔王魂（建议署名，非强制）

```
音乐：魔王魂
森田交一 / 魔王魂
```

### 4.3 OpenTracks（不需要署名，可选）

```
Free BGM OpenTracks (formerly DOVA-SYNDROME)
https://opentracks.com
```

---

## 五、合规红线

1. **仅限游戏内音频播放**——OpenTracks、魔王魂条款均明确**禁止用于 AI 训练**。
   本工程后续若接 AI 功能，音频**不得**进入任何训练 / 微调流程。
2. **不得作为主体内容**——禁止做成「原声带」单独发售或纯音乐视频。
3. **店内 / 活动播放**须下载文件后使用，勿直连在线主机（消耗对方流量）。
4. **引入新曲前核对当前条款**——条款可能已变更，以来源库当页为准。
5. **PeriTune 必须署名**，否则许可自动终止。
6. **署名 ≠ 背书**——不得暗示原作者为你的游戏背书或赞助。
