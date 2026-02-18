/* eslint-disable max-len */
/* eslint-disable require-jsdoc */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const latestValueRef = db
    .collection("gold_prices")
    .doc("latest")
    .collection("current")
    .doc("value");
const historyItemsRef = db
    .collection("gold_prices")
    .doc("history")
    .collection("items");

const PRICE_FIELDS = [
  {key: "ygea16", label: "YGEA 16"},
  {key: "k16Buy", label: "16 Buy"},
  {key: "k16Sell", label: "16 Sell"},
  {key: "k16newBuy", label: "16 New Buy"},
  {key: "k16newSell", label: "16 New Sell"},
  {key: "k15Buy", label: "15 Buy"},
  {key: "k15Sell", label: "15 Sell"},
  {key: "k15newBuy", label: "15 New Buy"},
  {key: "k15newSell", label: "15 New Sell"},
];

function escapeHtml(value) {
  const input = value === undefined || value === null ? "" : value;
  return String(input)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
}

function compactMoney(value) {
  if (value === null || value === undefined || value === "") return "";
  const num = Number(value);
  if (!Number.isFinite(num)) return "";
  return num.toLocaleString("en-US");
}

function nowInYangon() {
  const now = new Date();

  try {
    const date = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Asia/Yangon",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).format(now);

    const time = new Intl.DateTimeFormat("en-US", {
      timeZone: "Asia/Yangon",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).format(now);

    return {date, time};
  } catch (err) {
    const fallback = now.toISOString().split("T");
    const date = fallback[0];
    const time = fallback[1].slice(0, 5);
    return {date, time};
  }
}

function idFromTimestamp(ts) {
  return "auto_" + ts
      .toDate()
      .toISOString()
      .replace(/[-:.TZ]/g, "")
      .slice(0, 14);
}

function readFormBody(req) {
  if (req.body && typeof req.body === "object" && !Buffer.isBuffer(req.body)) {
    const out = {};
    Object.keys(req.body).forEach((k) => {
      const input = req.body[k] === undefined || req.body[k] === null ?
        "" :
        req.body[k];
      out[k] = String(input);
    });
    return out;
  }

  const raw = req.rawBody ? req.rawBody.toString("utf8") : "";
  if (!raw) return {};

  const params = new URLSearchParams(raw);
  const out = {};
  for (const [k, v] of params.entries()) {
    out[k] = v;
  }
  return out;
}

function parsePrice(raw) {
  const input = raw === undefined || raw === null ? "" : raw;
  const cleaned = String(input).trim().replace(/[,\s]/g, "");
  if (!cleaned) return null;
  if (!/^\d+$/.test(cleaned)) return Number.NaN;

  const value = Number(cleaned);
  if (!Number.isFinite(value) || value < 0) return Number.NaN;
  return value;
}

function parsePricePayload(input) {
  const parsed = {};
  const values = {};
  const errors = [];

  PRICE_FIELDS.forEach((field) => {
    const value = input[field.key];
    const raw = String(value === undefined || value === null ? "" : value)
        .trim();
    values[field.key] = raw;

    const number = parsePrice(raw);
    if (number === null) {
      errors.push(`${field.label} is required.`);
      return;
    }
    if (Number.isNaN(number)) {
      errors.push(`${field.label} must be a whole number.`);
      return;
    }
    parsed[field.key] = number;
  });

  return {parsed, values, errors};
}

function renderPanel({values, message, error, lastMeta}) {
  const rows = PRICE_FIELDS.map((field) => {
    const raw = values[field.key];
    const value = escapeHtml(raw === undefined || raw === null ? "" : raw);
    return `
      <label class="row">
        <span>${escapeHtml(field.label)}</span>
        <input name="${escapeHtml(field.key)}" value="${value}" inputmode="numeric" required />
      </label>
    `;
  }).join("\n");

  const status = error ?
    `<div class="notice error">${escapeHtml(error)}</div>` :
    (message ? `<div class="notice ok">${escapeHtml(message)}</div>` : "");

  const lastLine = lastMeta ?
    `<p class="meta">Last saved: ${escapeHtml(lastMeta)}</p>` :
    "";

  return `
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>MMGold Admin Update</title>
  <style>
    body {
      margin: 0;
      font-family: Arial, sans-serif;
      background: #f4f6f8;
      color: #1f2937;
    }
    .wrap {
      max-width: 560px;
      margin: 24px auto;
      padding: 20px;
      background: #ffffff;
      border-radius: 14px;
      box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08);
    }
    h1 {
      margin: 0 0 8px;
      font-size: 22px;
    }
    p {
      margin: 0 0 14px;
      color: #4b5563;
    }
    .meta {
      font-size: 13px;
      color: #6b7280;
    }
    .row {
      display: grid;
      gap: 8px;
      margin-bottom: 12px;
    }
    .row span {
      font-size: 14px;
      font-weight: 600;
    }
    input {
      border: 1px solid #d1d5db;
      border-radius: 10px;
      padding: 10px 12px;
      font-size: 15px;
    }
    .key {
      margin-top: 20px;
      padding-top: 14px;
      border-top: 1px solid #e5e7eb;
    }
    button {
      width: 100%;
      border: 0;
      border-radius: 10px;
      padding: 12px;
      font-size: 16px;
      font-weight: 700;
      color: white;
      background: #0f766e;
      cursor: pointer;
      margin-top: 6px;
    }
    .notice {
      border-radius: 10px;
      padding: 10px 12px;
      margin-bottom: 14px;
      font-size: 14px;
    }
    .notice.ok {
      background: #dcfce7;
      color: #166534;
    }
    .notice.error {
      background: #fee2e2;
      color: #991b1b;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>MMGold Admin Panel</h1>
    <p>Update latest Myanmar gold prices from browser.</p>
    ${lastLine}
    ${status}
    <form method="post">
      ${rows}
      <label class="row key">
        <span>Admin Key</span>
        <input type="password" name="adminKey" autocomplete="off" required />
      </label>
      <button type="submit">Save Latest Prices</button>
    </form>
  </div>
</body>
</html>
  `;
}

function hasPriceChanges(before, after) {
  return PRICE_FIELDS.some((field) => before[field.key] !== after[field.key]);
}

exports.archiveGoldPriceOnUpdate = functions.firestore
    .document("gold_prices/latest/current/value")
    .onUpdate(async (change, context) => {
      const before = change.before.data();
      const after = change.after.data();

      if (!before) {
        return null;
      }
      if (!after) {
        return null;
      }
      if (!hasPriceChanges(before, after)) {
        return null;
      }

      const now = admin.firestore.Timestamp.now();

      const historyDoc = {
        ...before,
        archivedAt: now,
        archivedBy: "auto_trigger",
      };

      const id = `${idFromTimestamp(now)}_${context.eventId.slice(0, 8)}`;

      await historyItemsRef
          .doc(id)
          .set(historyDoc);

      return null;
    });

exports.goldPriceAdminPanel = functions.https.onRequest(async (req, res) => {
  res.set("Cache-Control", "no-store");
  res.set("Content-Type", "text/html; charset=utf-8");

  const latestSnap = await latestValueRef.get();
  const latest = latestSnap.data() || {};
  const initialValues = {};

  PRICE_FIELDS.forEach((field) => {
    initialValues[field.key] = latest[field.key] == null ?
          "" :
          String(latest[field.key]);
  });

  const lastMeta = latest.date && latest.time ?
        `${latest.date} ${latest.time}` :
        null;

  if (req.method === "GET") {
    res.status(200).send(renderPanel({
      values: initialValues,
      lastMeta,
    }));
    return;
  }

  if (req.method !== "POST") {
    res.set("Allow", "GET, POST");
    res.status(405).send(renderPanel({
      values: initialValues,
      error: "Method not allowed.",
      lastMeta,
    }));
    return;
  }

  const secret = process.env.ADMIN_PANEL_KEY || "";
  if (!secret) {
    res.status(500).send(renderPanel({
      values: initialValues,
      error: "Server secret is not configured.",
      lastMeta,
    }));
    return;
  }

  const form = readFormBody(req);
  const input = form.adminKey === undefined || form.adminKey === null ?
        "" :
        form.adminKey;
  const adminKey = String(input).trim();

  if (adminKey !== secret) {
    res.status(401).send(renderPanel({
      values: {
        ...initialValues,
        ...form,
      },
      error: "Invalid admin key.",
      lastMeta,
    }));
    return;
  }

  const {parsed, values, errors} = parsePricePayload(form);
  if (errors.length > 0) {
    res.status(400).send(renderPanel({
      values: {
        ...initialValues,
        ...values,
      },
      error: errors.join(" "),
      lastMeta,
    }));
    return;
  }

  const mmNow = nowInYangon();
  await latestValueRef.set({
    ...parsed,
    date: mmNow.date,
    time: mmNow.time,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: "web_admin_panel",
  }, {merge: true});

  const savedPreview = {};
  PRICE_FIELDS.forEach((field) => {
    savedPreview[field.key] = compactMoney(parsed[field.key]);
  });

  res.status(200).send(renderPanel({
    values: savedPreview,
    message: "Latest prices updated successfully.",
    lastMeta: `${mmNow.date} ${mmNow.time}`,
  }));
});
