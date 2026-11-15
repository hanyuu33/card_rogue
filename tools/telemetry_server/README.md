# 匿名对局数据（R757）

一套「记录 → 分析 → 调平衡」的最小闭环。**只在发布版生效**：测试版不写事件流、
不弹询问框、设置页里也不出现那一项（`GameBuild.is_release()` 那一道闸）。

## 三层结构

| 层 | 在哪 | 做什么 | 谁看 |
|---|---|---|---|
| 采集 | `scripts/telemetry.gd` | 往 `user://telemetry.jsonl` 追加事件（一行一条 JSON） | 玩家自己的机器 |
| 上报 | `scripts/telemetry_uploader.gd` | 玩家同意后，把**新增部分**批量 POST 到端点 | 作者的服务器 |
| 分析 | `tools/analyze_balance.py` | 出选择率 / 分层胜率 / 掉血 / 死亡点 | 作者 |

采集与上报是**分开的两件事**：本机记录不需要同意（数据没出机器），弹窗管的是「要不要往外发」。
默认 `telemetry_opt_in = 0` 等于**不发**，只有玩家点过「同意发送」才上传。

## 一、先把本机链路跑起来

```bash
godot --path . -- --release --telemetry      # 编辑器里模拟发布版采集
# 正常玩一局，然后：
python tools/analyze_balance.py              # 默认去 Godot user:// 找事件流
```

`--release` 打开发布版闸门，`--telemetry` 让事件流真的落盘。两个都不加 = 什么都不记。

## 二、接上报（本地先验）

```bash
python tools/telemetry_server/receiver.py            # 监听 8788，落盘 tools/telemetry_server/data/
```

把 `scripts/telemetry.gd` 的

```gdscript
const UPLOAD_ENDPOINT := ""
```

改成 `"http://127.0.0.1:8788/ingest"`，以 `--release --telemetry` 启动，标题页点「同意发送」即可。
上传进度记在 `user://telemetry.sent`（已成功发送的字节偏移），失败不前进、下次启动重试。

## 三、正式部署（Cloudflare Worker + R2）

```bash
npm i -g wrangler && wrangler login
wrangler r2 bucket create quackill-telemetry
wrangler deploy tools/telemetry_server/worker.js --name quackill-telemetry
# 把 https://quackill-telemetry.<子域>.workers.dev/ingest 填进 UPLOAD_ENDPOINT
```

`worker.js` 顶部注释里写了完整的绑定配置要求（`BUCKET` 绑到那个 R2 桶）。

## 四、机器人先验（卡池 320 张时唯一有统计功效的来源）

```bash
python tools/ai_play/launch.py --headless --sim --telemetry
python tools/ai_play/balance_sim.py --runs 20
python tools/analyze_balance.py --sim
```

`--sim` 会把这一局标成机器人局；分析脚本用 `--sim` / `--real` 分开算，
避免把 bot 的选卡偏好当成玩家偏好。两者**对不上**的地方才是要改的卡：

* AI 觉得强、玩家不用 → 太贵 / 太慢 / 需要配合，或说明看不懂；
* AI 不选、玩家抢着要 → 体感爽但数值弱，微调数值，别砍设计。

## 五、事件字典

| `ev` | 关键字段 | 回答什么问题 |
|---|---|---|
| `run_start` | `seed` `cls` `diff` `runs` `max_diff` `deepest` `sim` | 谁在打、什么难度、**熟练度**（开局前总局数 / 历史最高难） |
| `offer` | `oid` `k` `src` `cand[]` `layer` `hp` `mhp` `gold` `deck` | 这张卡被**提议**过几次（选择率的分母） |
| `pick` | `oid` `id` `cand[]` `ms` `skip` | 从哪几个里选了谁、犹豫多久、整组跳过 |
| `battle` | `key` `name` `tier` `layer` `win` `out` `turns` `hp0` `hp1` `dmg_in` `units[]` | 各敌人胜率与**掉血**（普通战看掉血，不看胜率） |
| `deck` | `op` `old` `new` | 删 / 变形了哪张（被删最多 = 玩家投的负票） |
| `shop_shelf` | `items[]` | 商店上了什么货（成交率的分母） |
| `shop` | `k` `id` `cost` `bought` | 买没买 |
| `run_end` | `win` `out` `secs` `layer` `battles` `bwins` `deaths` `played[]` `relics[]` | 这局结果、死在哪、**本局实际打出过哪些卡** |

`out` 取值：`win` / `lose` / `flee` / `interrupted`。`interrupted` 来自
`RunRecord.finish("interrupted")` —— 关窗口、崩溃、开新局顶掉上一局都会补这一条，
否则「玩家在哪一层不玩了」永远统计不出来。

## 六、口径上的几个坑（都踩过）

1. **选择率的分母**必须是「被提议次数」。只数「被选择次数」得到的是稀有度分布，
   不是强度分布。跳过整组也要留在分母里。
2. **不要把 raw 胜率当强度。** 强玩家爱选上限卡、弱玩家爱选保命卡，直接平均会把
   回血卡算成神卡。分析脚本用的是「同难度 lift」（减去该难度的基线通关率）。
3. **「选了却一次没打出去」比「没人选」更值得改** —— 那是占着卡位的死卡。
   这个数不需要逐张埋点，用 `card_play:*` 的局内差集就能算（`run_end.played`）。
4. **文件追加不能用 `FileAccess.WRITE_READ`。** 实测 Godot 4.3 里它配 `seek_end()`
   会在打开时从头覆盖 —— 表现是「每次启动都把整份事件流重写一遍」。必须用
   `READ_WRITE`（文件须已存在，先把空文件建出来）。
5. **`client` 不采任何标识。** 没有设备 id、没有账号、没有 IP；`run` 只是
   「种子 + 毫秒时间戳」，跨局不可关联。服务端也**不要**记 IP / UA。
