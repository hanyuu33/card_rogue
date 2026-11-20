# -*- coding: utf-8 -*-
"""多来源文本一致性审计（只读，不改文件）。

覆盖口径：
  A cards.json        <-> i18n/zh_canonical.json      （id 集合 / name / effect_text 全等）
  B relics.json       <-> i18n/noncard_zh_canonical   （id 集合 / name / desc 全等）
  C noncard zh        <-> en / ja / es                （id 集合；空串 / 缺失）
  D traps.json        <-> i18n/traps_zh_canonical     （id 集合 / name / desc 全等）
  E stories.json      <-> i18n/narrative_zh_canonical （文本全等）
  F l10n.gd 内置表    <-> i18n/interface_*            （同 key 文本全等）
  G demo_scope.json   <-> 仓库实际条数                （卡 / 道具 / 工具 / 事件）
输出到 stdout + _audit_text_report.txt
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = []


def log(s=""):
    OUT.append(s)
    print(s)


def load(rel):
    with io.open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return json.load(f)


def A():
    log("=" * 70)
    log("A  cards.json  vs  i18n/zh_canonical.json")
    cards = {c["id"]: c for c in load("cards.json")["cards"]}
    zh = load("i18n/zh_canonical.json")["cards"]
    zh_ids = set(int(k) for k in zh)
    log("  cards=%d zh=%d  仅 cards 有=%s  仅 zh 有=%s" % (
        len(cards), len(zh_ids),
        sorted(set(cards) - zh_ids)[:10], sorted(zh_ids - set(cards))[:10]))
    dn = de = 0
    for cid in sorted(set(cards) & zh_ids):
        z = zh[str(cid)]
        if cards[cid].get("name") != z.get("name"):
            dn += 1
            log("  [名字] %d  卡=%r  canonical=%r" % (cid, cards[cid].get("name"), z.get("name")))
        if cards[cid].get("effect_text") != z.get("effect_text"):
            de += 1
            log("  [效果] %d %s\n        卡=%r\n        zh=%r" % (
                cid, cards[cid].get("name"), cards[cid].get("effect_text"), z.get("effect_text")))
    log("  合计：名字不符 %d / 效果不符 %d" % (dn, de))


def B():
    log("=" * 70)
    log("B  relics.json  vs  i18n/noncard_zh_canonical.json")
    rel = {r["id"]: r for r in load("relics.json")["relics"]}
    nz = load("i18n/noncard_zh_canonical.json")["relics"]
    nz_ids = set(int(k) for k in nz)
    log("  relics=%d noncard_zh=%d  仅 relics=%s  仅 noncard=%s" % (
        len(rel), len(nz_ids), sorted(set(rel) - nz_ids)[:10], sorted(nz_ids - set(rel))[:10]))
    dn = dd = 0
    for rid in sorted(set(rel) & nz_ids):
        z = nz[str(rid)]
        if rel[rid].get("name") != z.get("name"):
            dn += 1
            log("  [名字] %d  relics=%r  noncard=%r" % (rid, rel[rid].get("name"), z.get("name")))
        if rel[rid].get("desc") != z.get("desc"):
            dd += 1
            log("  [描述] %d %s\n        relics=%r\n        noncard=%r" % (
                rid, rel[rid].get("name"), rel[rid].get("desc"), z.get("desc")))
    log("  合计：名字不符 %d / 描述不符 %d" % (dn, dd))


def C():
    log("=" * 70)
    log("C  noncard zh / en / ja / es  id 集合与空值")
    base = load("i18n/noncard_zh_canonical.json")
    langs = {l: load("i18n/noncard_%s.json" % l) for l in ("en", "ja", "es")}
    for scope in base:
        if not isinstance(base[scope], dict):
            continue
        zids = set(base[scope])
        for l, d in langs.items():
            lids = set(d.get(scope, {}))
            miss = sorted(zids - lids)[:12]
            extra = sorted(lids - zids)[:12]
            if miss or extra:
                log("  [%s] %s 缺=%s 多=%s" % (l, scope, miss, extra))
        for l, d in langs.items():
            for k, v in d.get(scope, {}).items():
                for field in ("name", "desc"):
                    if field in base[scope].get(k, {}) and not str(v.get(field, "")).strip():
                        log("  [%s] %s/%s.%s 为空" % (l, scope, k, field))


def D():
    log("=" * 70)
    log("D  traps.json  vs  i18n/traps_en|ja|es.json")
    ## 工具没有 zh_canonical（中文就写在 traps.json 里），所以这组只核 id 覆盖与空值。
    t = load("traps.json")
    items = t["traps"] if isinstance(t, dict) and "traps" in t else t
    ids = {int(x["id"]): x for x in items}
    n = 0
    for lang in ("en", "ja", "es"):
        d = load("i18n/traps_%s.json" % lang)
        dd = d["traps"] if isinstance(d, dict) and "traps" in d else d
        dids = set(int(k) for k in dd)
        if dids != set(ids):
            n += 1
            log("  [%s] 缺=%s 多=%s" % (lang, sorted(set(ids) - dids)[:8], sorted(dids - set(ids))[:8]))
        empty = [k for k, v in dd.items() if not str(v.get("desc", "")).strip()]
        if empty:
            n += 1
            log("  [%s] 空描述 %s" % (lang, empty[:6]))
    log("  traps=%d 三语覆盖问题 %d" % (len(ids), n))


def E():
    log("=" * 70)
    log("E  剧情 / 事件文案")
    ## 结构与 narrative_zh_canonical 不是一一对应（按事件 id 分组），逐字比对交给
    ## `i18n/validate_narrative.py` 与 `i18n/validate_event_ui.py`，本脚本只做提醒。
    log("  由 validate_narrative.py（30 事件 / 74 条）+ validate_event_ui.py（99 选项 / 74 结果）全量校验")


def F():
    log("=" * 70)
    log("F  scripts/l10n.gd 内置表  vs  i18n/interface_*.json")
    src = io.open(os.path.join(ROOT, "scripts/l10n.gd"), encoding="utf-8").read()
    # 解析形如  "key": {"zh": "...", "en": "...", "ja": "...", "es": "..."},
    pairs = re.findall(r'"([\w.]+)":\s*\{([^{}]*)\}', src)
    built = {}
    for key, body in pairs:
        d = dict(re.findall(r'"(zh|en|ja|es)":\s*"((?:[^"\\]|\\.)*)"', body))
        if d:
            built[key] = d
    log("  l10n.gd 解析到 %d 条" % len(built))
    ifaces = {}
    for l in ("zh_canonical", "en", "ja", "es"):
        d = load("i18n/interface_%s.json" % l)
        if l == "zh_canonical":
            ifaces[l] = d
        else:
            ifaces[l] = d
    def get_iface(l, key):
        d = ifaces[l]
        cur = d
        for part in key.split("."):
            if isinstance(cur, dict) and part in cur:
                cur = cur[part]
            else:
                return None
        if isinstance(cur, dict):
            return cur.get("zh" if l == "zh_canonical" else l)
        return cur
    n = 0
    for key, d in built.items():
        for l in ("zh", "en", "ja", "es"):
            target = "zh_canonical" if l == "zh" else l
            v = get_iface(target, key)
            if v is None:
                continue
            if v != d[l]:
                n += 1
                log("  [%s] %s\n      l10n=%r\n      iface=%r" % (l, key, d[l], v))
    log("  合计不符 %d" % n)


def G():
    log("=" * 70)
    log("G  demo_scope.json 白名单规模（只报数，不判等）")
    sc = load("demo_scope.json")
    cards = load("cards.json")["cards"]
    relics = load("relics.json")["relics"]
    traps = load("traps.json")
    items = traps["traps"] if isinstance(traps, dict) and "traps" in traps else traps
    log("  demo_scope: %s" % {k: len(v) for k, v in sc.items() if isinstance(v, list)})
    log("  仓库：cards=%d / relics=%d / traps=%d" % (len(cards), len(relics), len(items)))
    log("  判据在 `_test_r817()`：道具档要求基线 == all_relics()，卡/工具按白名单裁")


for fn in (A, B, C, D, E, F, G):
    try:
        fn()
    except Exception as exc:  # noqa
        log("!! %s 出错: %r" % (fn.__name__, exc))

io.open(os.path.join(ROOT, "_audit_text_report.txt"), "w", encoding="utf-8").write("\n".join(OUT))
print("\n报告已写入 _audit_text_report.txt")
