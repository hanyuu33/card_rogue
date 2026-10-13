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

| 场景 | 文件名 | 曲名 | 作者 | 来源库 | 授权 | 需署名 | 已修改 | 下载日期 | 来源链接 |
|---|---|---|---|---|---|---|---|---|---|
| 标题 | `title.ogg` | Poema | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 角色选择 | `class_pick.ogg` | Positive_Happy | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 地图 | `map.ogg` | Sketch Forest | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 卡组编辑/图鉴 | `deck.ogg` | Teatime | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 战斗 | `battle.ogg` | Fight | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 精英战斗 | `battle_elite.ogg` | Battlefield 5 | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| Boss | `battle_boss.ogg` | Dramatic | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 暗影 Boss | `battle_boss_dark.ogg` | 霜蝶の夢 | まんぼう二等兵 | OpenTracks | 站点自有许可 | 否 | 待填 | 待填 | 待填 |
| 事件 | `event.ogg` | Augury | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 奖励 | `reward.ogg` | Wish4 | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 胜利 | `victory.ogg` | Soaring | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |
| 失败 | `defeat.ogg` | Grief 2 | PeriTune | PeriTune | CC BY 4.0 | 是 | 待填 | 待填 | 待填 |

> 备选曲目若启用，另起一行登记，并在「场景」列注明「（备选）」。

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
