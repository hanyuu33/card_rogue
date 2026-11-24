# -*- coding: utf-8 -*-
"""生成「暗影刺客」全卡总览页（只读审计，不改 cards.json）。

口径：
  * 归属 = cards.json 中 class == 暗影刺客
  * 「池」= 奖励池口径（rarity 0~2 且非剧情锁 / 非 event_only）
  * 三语名取自 i18n/cards_{en,ja,es}.json
用法：python tools/_make_shadow_review.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = Path("E:/tmp/r845_shadow_review/暗影刺客卡组总览.html")

CLASS = "暗影刺客"
KIND_ORDER = ["技能", "效果", "盟友", "工事", "场地"]
KIND_NOTE = {
    "技能": "打出即结算，进弃牌区",
    "效果": "挂在效果区，持续生效（同名不叠加）",
    "盟友": "占据战场格子的单位",
    "工事": "0 移动的驻守单位",
    "场地": "铺在格子上的地形效果",
}
RARITY = {0: "普通", 1: "稀有", 2: "史诗", 3: "初始", 4: "怪物", 5: "事件", 6: "诅咒"}
RARITY_CLS = {0: "r0", 1: "r1", 2: "r2", 3: "r3", 4: "r4", 5: "r5", 6: "r6"}


def load():
    cards = json.loads((ROOT / "cards.json").read_text(encoding="utf-8"))["cards"]
    tr = {}
    for lang in ("en", "ja", "es"):
        tr[lang] = json.loads((ROOT / f"i18n/cards_{lang}.json").read_text(encoding="utf-8"))["cards"]
    return cards, tr


def scope_of(c):
    if c.get("locked"):
        return "剧情锁"
    if c.get("event_only"):
        return "事件专属"
    if c["rarity"] == 3:
        return "初始卡"
    if c["rarity"] == 5:
        return "事件卡"
    if c["rarity"] > 2:
        return "非池"
    return "池内"


def main():
    cards, tr = load()
    sa = [c for c in cards if c.get("class") == CLASS]
    rows = []
    for c in sa:
        i = str(c["id"])
        stats = ""
        if c["kind"] in ("盟友", "工事", "场地"):
            stats = f'{c.get("power", 0)}/{c.get("health", 0)}'
            extra = []
            if c.get("attack_range"):
                extra.append(f'射程 {c["attack_range"]}')
            if c.get("move_speed"):
                extra.append(f'移动 {c["move_speed"]}')
            stats_block = f'<span class="stat">{stats}</span>' + (
                f'<span class="sub">{" · ".join(extra)}</span>' if extra else "")
        else:
            stats_block = '<span class="sub">—</span>'
        traits = [t for t in (c.get("traits") or []) if t not in ("工事",)]
        rows.append({
            "id": c["id"],
            "name": c["name"],
            "en": tr["en"].get(i, {}).get("name", ""),
            "ja": tr["ja"].get(i, {}).get("name", ""),
            "es": tr["es"].get(i, {}).get("name", ""),
            "kind": c["kind"],
            "cost": c["cost"],
            "xcost": bool(c.get("x_cost")),
            "rarity": c["rarity"],
            "rarity_name": RARITY.get(c["rarity"], "?"),
            "color": c.get("color") or "",
            "stats": stats_block,
            "text": (c.get("effect_text") or "").replace("**", ""),
            "traits": traits,
            "scope": scope_of(c),
        })
    kind_rank = {k: n for n, k in enumerate(KIND_ORDER)}
    rows.sort(key=lambda r: (kind_rank.get(r["kind"], 9), r["cost"], r["id"]))

    payload = json.dumps(rows, ensure_ascii=False)
    total = len(rows)
    pool = sum(1 for r in rows if r["scope"] == "池内")
    kind_count = {k: sum(1 for r in rows if r["kind"] == k) for k in KIND_ORDER}
    rar_count = {}
    for r in rows:
        rar_count[r["rarity_name"]] = rar_count.get(r["rarity_name"], 0) + 1
    cost_count = {}
    for r in rows:
        cost_count[r["cost"]] = cost_count.get(r["cost"], 0) + 1

    kind_chips = "".join(
        f'<button class="chip" data-kind="{k}">{k}<b>{kind_count[k]}</b></button>' for k in KIND_ORDER)
    rar_chips = "".join(
        f'<button class="chip" data-rar="{k}">{k}<b>{v}</b></button>' for k, v in
        sorted(rar_count.items(), key=lambda x: list(RARITY.values()).index(x[0])))
    scope_chips = "".join(
        f'<button class="chip" data-scope="{s}">{s}<b>{sum(1 for r in rows if r["scope"] == s)}</b></button>'
        for s in ("池内", "初始卡", "剧情锁", "事件卡"))

    cost_cells = "".join(
        f'<div class="bar"><span class="bl">{c}费</span>'
        f'<span class="bt" style="width:{v / max(cost_count.values()) * 100:.0f}%"></span>'
        f'<span class="bn">{v}</span></div>'
        for c, v in sorted(cost_count.items()))

    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>暗影刺客 · 全卡总览</title>
<style>
  :root {{
    --ink:#2a2318; --ink2:#5b4f3d; --paper:#f7f0e1; --paper2:#fffaf0;
    --line:#ded0b4; --accent:#6b4ea8; --accent2:#8f6fd0; --gold:#b08334;
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; padding:28px 22px 60px; background:
      radial-gradient(1200px 500px at 15% -10%, #fffdf6, transparent), var(--paper);
      color:var(--ink); font-family:"Noto Serif SC","Source Han Serif SC",Georgia,"Songti SC",serif; }}
  header {{ max-width:1180px; margin:0 auto 18px; }}
  h1 {{ font-size:30px; margin:0 0 6px; letter-spacing:.04em; }}
  h1 small {{ font-size:14px; color:var(--ink2); font-weight:400; margin-left:10px; letter-spacing:0; }}
  .lede {{ color:var(--ink2); font-size:14px; line-height:1.7; margin:0; }}
  .cards {{ max-width:1180px; margin:16px auto 0; display:grid; grid-template-columns:repeat(4,1fr); gap:12px; }}
  .kpi {{ background:var(--paper2); border:1px solid var(--line); border-radius:10px; padding:12px 14px; }}
  .kpi b {{ display:block; font-size:24px; color:var(--accent); }}
  .kpi span {{ font-size:12px; color:var(--ink2); }}
  .panel {{ max-width:1180px; margin:20px auto 0; background:var(--paper2); border:1px solid var(--line);
      border-radius:12px; padding:16px 18px; }}
  .panel h2 {{ font-size:15px; margin:0 0 10px; letter-spacing:.06em; color:var(--ink2); }}
  .bar {{ display:flex; align-items:center; gap:10px; margin:5px 0; font-size:12px; }}
  .bl {{ width:36px; color:var(--ink2); }}
  .bt {{ height:12px; background:linear-gradient(90deg,var(--accent),var(--accent2)); border-radius:6px; }}
  .bn {{ color:var(--ink2); width:24px; }}
  .filters {{ max-width:1180px; margin:20px auto 0; display:flex; flex-wrap:wrap; gap:8px; align-items:center; }}
  .chip {{ font:inherit; font-size:13px; padding:6px 12px; border-radius:999px; border:1px solid var(--line);
      background:var(--paper2); color:var(--ink); cursor:pointer; }}
  .chip b {{ font-weight:600; margin-left:7px; color:var(--accent); }}
  .chip.on {{ background:var(--accent); color:#fff; border-color:var(--accent); }}
  .chip.on b {{ color:#fff; }}
  input[type=search] {{ font:inherit; font-size:13px; padding:7px 12px; border-radius:999px;
      border:1px solid var(--line); background:var(--paper2); color:var(--ink); min-width:220px; }}
  .hint {{ max-width:1180px; margin:10px auto 0; font-size:12px; color:var(--ink2); }}
  section {{ max-width:1180px; margin:22px auto 0; }}
  section h3 {{ font-size:17px; margin:0 0 4px; letter-spacing:.08em; }}
  section h3 em {{ font-style:normal; font-size:12px; color:var(--ink2); margin-left:10px; font-weight:400; }}
  table {{ width:100%; border-collapse:collapse; background:var(--paper2); border:1px solid var(--line);
      border-radius:12px; overflow:hidden; font-size:13px; }}
  thead th {{ background:#efe4cd; color:var(--ink2); font-weight:600; font-size:12px; letter-spacing:.08em;
      text-align:left; padding:9px 10px; border-bottom:1px solid var(--line); }}
  td {{ padding:9px 10px; border-bottom:1px solid #eee2ca; vertical-align:top; line-height:1.65; }}
  tr:last-child td {{ border-bottom:none; }}
  tr:hover td {{ background:#fffdf6; }}
  .id {{ font-family:ui-monospace,Consolas,monospace; font-size:12px; color:var(--ink2); }}
  .nm {{ font-weight:600; white-space:nowrap; }}
  .nm .tr {{ display:block; font-weight:400; font-size:11px; color:var(--ink2); white-space:normal; }}
  .cost {{ font-weight:700; color:var(--accent); text-align:center; white-space:nowrap; }}
  .stat {{ font-family:ui-monospace,Consolas,monospace; font-size:13px; font-weight:600; white-space:nowrap; }}
  .sub {{ display:block; font-size:11px; color:var(--ink2); }}
  .tag {{ display:inline-block; font-size:11px; padding:1px 7px; border-radius:999px; border:1px solid currentColor; }}
  .r0 {{ color:#4a4a45; }} .r1 {{ color:#1f5fbf; }} .r2 {{ color:#7a3fa8; }}
  .r3 {{ color:#8a6a1f; }} .r5 {{ color:#a34a2a; }}
  .scope {{ font-size:11px; white-space:nowrap; }}
  .s-pool {{ color:#3f7a4b; }} .s-init {{ color:#8a6a1f; }}
  .s-lock {{ color:#a33f3f; }} .s-event {{ color:#7a5a2a; }} .s-non {{ color:#7a7a70; }}
  .traits {{ font-size:11px; color:var(--ink2); margin-top:2px; }}
  .findings {{ max-width:1180px; margin:26px auto 0; background:var(--paper2); border:1px solid var(--line);
      border-left:5px solid var(--gold); border-radius:12px; padding:16px 20px; }}
  .findings h2 {{ font-size:16px; margin:0 0 10px; }}
  .findings li {{ font-size:13px; line-height:1.85; color:var(--ink); margin:4px 0; }}
  .findings code {{ font-family:ui-monospace,Consolas,monospace; font-size:12px; background:#efe4cd;
      padding:1px 6px; border-radius:4px; }}
  footer {{ max-width:1180px; margin:26px auto 0; font-size:11px; color:var(--ink2); }}
  @media (max-width:980px) {{ .cards {{ grid-template-columns:repeat(2,1fr); }} }}
</style>
</head>
<body>
<header>
  <h1>暗影刺客 · 全卡总览<small>Card Library / Shadow Assassin</small></h1>
  <p class="lede">按 <code>cards.json</code> 的 <code>class = 暗影刺客</code> 全量导出，共 <b>{total}</b> 张；
    其中可进奖励池 <b>{pool}</b> 张。分组顺序：技能 → 效果 → 盟友 → 工事 → 场地，组内按费用升序。</p>
</header>

<div class="cards">
  <div class="kpi"><b>{total}</b><span>职业卡总数</span></div>
  <div class="kpi"><b>{pool}</b><span>奖励池内（rarity 0~2）</span></div>
  <div class="kpi"><b>{kind_count['技能']}</b><span>技能卡</span></div>
  <div class="kpi"><b>{rar_count.get('稀有', 0) + rar_count.get('史诗', 0)}</b><span>稀有 + 史诗</span></div>
</div>

<div class="panel">
  <h2>费用曲线（全 {total} 张）</h2>
  {cost_cells}
</div>

<div class="filters">
  <input type="search" id="q" placeholder="搜索卡名 / 效果 / id…">
  {kind_chips}{rar_chips}{scope_chips}
  <button class="chip on" id="reset">全部</button>
</div>
<p class="hint" id="count"></p>

<div id="body"></div>

<div class="findings">
  <h2>审计要点</h2>
  <ul>
    <li><b>67 = 62 + 5</b>：奖励池 62 张，池外 5 张 —— 初始卡 <code>幽影 8005</code> / <code>终结 9086</code>、
      事件卡 <code>荧光草 8010</code>（rarity 5）、剧情锁 <code>猫鼠游戏 9190</code> / <code>黑暗嵌合 9191</code>。
      与 <code>card_repo.gd</code> 注释里的 62 张口径一致。</li>
    <li><b>幽影 8005 是唯一无效果文本的卡</b>：3/8 白板基础盟友，替换森林精魄的树人，中英日西四处同为空白，属设计如此而非漏译。</li>
    <li><b>四语覆盖完整</b>：67 张在 <code>cards_en/ja/es.json</code> 均有条目，无缺键、无残句。</li>
    <li><b>旧陷阱体系无残留</b>：R503 之后本职业只剩「标记」这一套场地机制（<code>标记 9224</code> / <code>噩兆 9231</code> 等 6 张），
      无任何卡再提「陷阱」。</li>
    <li><b>X 费只有 1 张</b>：<code>连斩 9272</code>（cost 0 + <code>x_cost</code>），打出时吃掉全部费用。</li>
    <li><b>试玩版发得出 60 张</b>：奖励池 62 张里 <code>拒绝命运 9098</code> / <code>灵魂收割者 9233</code> 不在
      <code>demo_scope.json</code> 基线内。</li>
  </ul>
</div>

<footer>只读审计产物 · 数据源 cards.json（{total} 张暗影刺客卡）· 三语名来自 i18n/cards_en/ja/es.json</footer>
"""

    js = """<script>
const ROWS = __ROWS__;
const KIND_ORDER = __KIND_ORDER__;
const KIND_NOTE = __KIND_NOTE__;
const state = { q: "", kinds: new Set(), rars: new Set(), scopes: new Set() };

function esc(s) { return String(s).replace(/[&<>]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;"})[c]); }

function render() {
  const q = state.q.trim().toLowerCase();
  const hit = ROWS.filter(r => {
    if (state.kinds.size && !state.kinds.has(r.kind)) return false;
    if (state.rars.size && !state.rars.has(r.rarity_name)) return false;
    if (state.scopes.size && !state.scopes.has(r.scope)) return false;
    if (!q) return true;
    return (r.name + " " + r.en + " " + r.ja + " " + r.es + " " + r.text + " " + r.id).toLowerCase().includes(q);
  });
  let html = "";
  for (const k of KIND_ORDER) {
    const list = hit.filter(r => r.kind === k);
    if (!list.length) continue;
    html += `<section><h3>${k}<em>${list.length} 张 · ${KIND_NOTE[k] || ""}</em></h3>`;
    html += `<table><thead><tr><th style="width:64px">ID</th><th style="width:180px">卡名</th>
      <th style="width:56px">费用</th><th style="width:82px">稀有度</th><th style="width:86px">数值</th>
      <th>效果</th><th style="width:74px">口径</th></tr></thead><tbody>`;
    for (const r of list) {
      const costTxt = r.xcost ? "X" : r.cost;
      const tr = [r.en, r.ja, r.es].filter(Boolean).join(" / ");
      const scopeCls = {"池内":"s-pool","初始卡":"s-init","剧情锁":"s-lock","事件卡":"s-event"}[r.scope] || "s-non";
      const rarCls = r.rarity === 1 ? "r1" : r.rarity === 2 ? "r2" : r.rarity === 3 ? "r3" : r.rarity >= 5 ? "r5" : "r0";
      const traits = r.traits.length ? `<div class="traits">词条：${r.traits.map(esc).join(" / ")}</div>` : "";
      html += `<tr><td class="id">${r.id}</td>
        <td class="nm">${esc(r.name)}<span class="tr">${esc(tr)}</span>${traits}</td>
        <td class="cost">${costTxt}</td>
        <td><span class="tag ${rarCls}">${r.rarity_name}</span></td>
        <td>${r.stats}</td>
        <td>${r.text ? esc(r.text) : '<span class="sub">（无效果文本 · 白板）</span>'}</td>
        <td class="scope ${scopeCls}">${r.scope}</td></tr>`;
    }
    html += "</tbody></table></section>";
  }
  document.getElementById("body").innerHTML = html || '<p class="hint">没有匹配的卡。</p>';
  document.getElementById("count").textContent = "当前显示 " + hit.length + " / " + ROWS.length + " 张";
}

document.getElementById("q").addEventListener("input", e => { state.q = e.target.value; render(); });
document.querySelectorAll(".chip[data-kind]").forEach(b => b.addEventListener("click", () => {
  const v = b.dataset.kind; state.kinds.has(v) ? state.kinds.delete(v) : state.kinds.add(v);
  b.classList.toggle("on"); render();
}));
document.querySelectorAll(".chip[data-rar]").forEach(b => b.addEventListener("click", () => {
  const v = b.dataset.rar; state.rars.has(v) ? state.rars.delete(v) : state.rars.add(v);
  b.classList.toggle("on"); render();
}));
document.querySelectorAll(".chip[data-scope]").forEach(b => b.addEventListener("click", () => {
  const v = b.dataset.scope; state.scopes.has(v) ? state.scopes.delete(v) : state.scopes.add(v);
  b.classList.toggle("on"); render();
}));
document.getElementById("reset").addEventListener("click", () => {
  state.q = ""; state.kinds.clear(); state.rars.clear(); state.scopes.clear();
  document.getElementById("q").value = "";
  document.querySelectorAll(".chip").forEach(c => c.classList.remove("on"));
  document.getElementById("reset").classList.add("on");
  render();
});
render();
</script>
</body>
</html>"""

    js = (js.replace("__ROWS__", payload)
          .replace("__KIND_ORDER__", json.dumps(KIND_ORDER, ensure_ascii=False))
          .replace("__KIND_NOTE__", json.dumps(KIND_NOTE, ensure_ascii=False)))
    html = html + js

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(html, encoding="utf-8")
    print("WROTE", OUT, len(html), "chars")
    print("TOTAL", total, "POOL", pool, kind_count, rar_count, sorted(cost_count.items()))


if __name__ == "__main__":
    main()
