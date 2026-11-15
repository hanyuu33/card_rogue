/**
 * Quackill 匿名遥测接收器（Cloudflare Worker）
 *
 * 客户端（`scripts/telemetry.gd` → `TelemetryUploader`）用 POST 把**一批完整行**打过来，
 * Content-Type: text/plain，一行一条 JSON。这里只做三件事：
 *   1. 大小 / 方法 / 路径校验；
 *   2. 逐行 JSON 校验（坏行计数，一条不合法不整批丢）；
 *   3. 原样写进 R2（对象名 = 时间戳 + 随机后缀），离线分析时批量下载。
 *
 * 为什么用 R2 而不是 D1/KV：
 *   * 事件流是**只写一次、批量读**的形态，对象存储最便宜；
 *   * 分析脚本直接吃 jsonl，R2 下来的文件不用再导一次。
 *
 * 部署：
 *   1. `npm i -g wrangler && wrangler login`
 *   2. `wrangler r2 bucket create quackill-telemetry`
 *   3. `wrangler deploy worker.js --name quackill-telemetry`
 *   4. 把生成的 `https://quackill-telemetry.<你的子域>.workers.dev/ingest`
 *      填进 `scripts/telemetry.gd` 的 `UPLOAD_ENDPOINT`。
 *
 * 隐私：**不要**在这里记录 IP、User-Agent、Referer。玩家点「同意」发的是对局统计，
 * 不是「谁在玩」。日志里也不要打印请求头 —— 那是最容易无意中收进个人数据的地方。
 */

const MAX_BYTES = 1024 * 1024;      // 单批上限 1MB（客户端每批 256KB，留足余量）
const MAX_LINES = 20000;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === "GET") {
      // 健康检查：部署完 curl 一下，别拿游戏去试。
      return new Response("ok", { headers: { "content-type": "text/plain" } });
    }
    if (request.method !== "POST" || url.pathname.replace(/\/+$/, "") !== "/ingest") {
      return text(404, "not found");
    }
    const len = Number(request.headers.get("content-length") || "0");
    if (len > MAX_BYTES) return text(413, "too large");

    let body;
    try {
      body = await request.text();
    } catch {
      return text(400, "read failed");
    }
    if (!body || body.length > MAX_BYTES) return text(413, "too large");

    const lines = body.split("\n");
    if (lines.length > MAX_LINES) return text(413, "too many lines");

    let good = 0;
    let bad = 0;
    const kept = [];
    for (const line of lines) {
      const t = line.trim();
      if (!t) continue;
      let e = null;
      try {
        e = JSON.parse(t);
      } catch {
        bad++;
        continue;
      }
      if (e && typeof e === "object" && typeof e.ev === "string") {
        kept.push(t);
        good++;
      } else {
        bad++;
      }
    }
    if (good === 0) return text(400, `no valid events (${bad} bad)`);

    // 分批落 R2：一条对象一个客户批次，分析时按名字排序就是时间序。
    const stamp = new Date().toISOString().replace(/[:.]/g, "-");
    const rand = Math.random().toString(36).slice(2, 8);
    const key = `raw/${stamp}-${rand}.jsonl`;
    if (!env.BUCKET) return text(500, "R2 binding BUCKET missing");
    await env.BUCKET.put(key, kept.join("\n") + "\n", {
      httpMetadata: { contentType: "text/plain; charset=utf-8" },
    });
    return text(200, `ok ${good}${bad ? ` bad ${bad}` : ""}`);
  },
};

function text(code, msg) {
  return new Response(msg, {
    status: code,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
