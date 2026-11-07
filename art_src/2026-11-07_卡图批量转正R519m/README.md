# R519m R478–R479 待确认卡图批量转正

用户口径：「将之前那批转正」。

## 范围

- 原 `_pending` 共 32 张。
- 28 张仍对应 `cards.json` 现有卡牌，全部移入 `assets/pics/<id>.png`，manifest 标为 approved。
- 其中 8074 量产型代达罗斯等 8 张曾被 `art_plan.json` 标为暂不做；本轮按用户整批转正指示解除标记。
- 另外 8 条历史上已有正式图、却仍留在 skip 的过期记录一并清理，素材审计恢复通过。

## 已移除旧卡的遗留稿

`removed_cards/` 保存 4 张在当前 `cards.json` 中已没有对应卡牌的旧稿，不放入正式图库，避免孤儿图：

| id | 旧卡名 |
|---|---|
| 8013 | 冻结陷阱 |
| 8017 | 巨物陷阱 |
| 8063 | 黑暗陷阱 |
| 9107 | 暗影狩猎 |

manifest 对应状态为 `archived_removed_card`，保留 prompt / ref / 原图路径以便追溯。

## 验证

- `_review/{8074,8022,9043,9125}_gallery_1280.png`：代表卡图均正常，无黄色 pending 三角。
- `_art_index.py`：207 已完成 / 74 待做 / 15 暂不做，体检通过。
- `tools/cardart.py list`：没有待确认卡图。
- `_verify.py`：mana PASS / engine 5236 / reward 26 / bgm 39 / smoke 64，全部通过。
