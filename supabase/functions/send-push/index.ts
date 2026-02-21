import { createClient } from "https://esm.sh/@supabase/supabase-js@2.57.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const firebaseProjectId = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const firebaseClientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const firebasePrivateKey = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "").replace(
  /\\n/g,
  "\n",
);

const validTargets = new Set(["gold_price", "holdings", "calculator", "history"]);
const textEncoder = new TextEncoder();

type SendPayload = {
  title?: unknown;
  body?: unknown;
  target?: unknown;
  type?: unknown;
  payload?: unknown;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse({ error: "Supabase env is missing" }, 500);
  }
  if (!firebaseProjectId || !firebaseClientEmail || !firebasePrivateKey) {
    return jsonResponse({ error: "Firebase env is missing" }, 500);
  }

  const bearer = req.headers.get("Authorization") ?? "";
  const jwt = bearer.startsWith("Bearer ") ? bearer.slice(7).trim() : "";
  if (!jwt) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${jwt}` },
    },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const serviceClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser(jwt);
  const user = userData.user;
  if (userErr || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const { data: adminRow } = await serviceClient
    .from("admins")
    .select("user_id")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!adminRow) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  const input = await req.json().catch(() => ({} as SendPayload));
  const title = cleanText(input.title, 80);
  const body = cleanText(input.body, 220);
  const target = normalizeTarget(input.target);
  const type = cleanText(input.type, 40) || "admin_custom";
  const dataPayload = sanitizeDataPayload(input.payload);

  if (!title || !body) {
    return jsonResponse({ error: "title and body are required" }, 400);
  }

  const { data: inserted, error: insertErr } = await serviceClient
    .from("app_notifications")
    .insert({
      title,
      body,
      target,
      type,
      payload: dataPayload,
      created_by: user.id,
    })
    .select("id")
    .single();

  if (insertErr) {
    return jsonResponse({ error: `Insert failed: ${insertErr.message}` }, 500);
  }

  const { data: tokenRows, error: tokenErr } = await serviceClient
    .from("app_push_tokens")
    .select("token")
    .eq("is_active", true)
    .limit(5000);
  if (tokenErr) {
    return jsonResponse({ error: `Token read failed: ${tokenErr.message}` }, 500);
  }

  const tokens = [...new Set(
    (tokenRows ?? [])
      .map((row) => String(row.token ?? "").trim())
      .filter((token) => token.length > 0),
  )];

  if (tokens.isEmpty) {
    return jsonResponse({
      ok: true,
      notification_id: inserted.id,
      sent: 0,
      failed: 0,
      removed_tokens: 0,
    });
  }

  const accessToken = await getFirebaseAccessToken({
    clientEmail: firebaseClientEmail,
    privateKey: firebasePrivateKey,
  });

  const sendResult = await sendToTokens({
    projectId: firebaseProjectId,
    accessToken,
    title,
    body,
    target,
    type,
    payload: dataPayload,
    tokens,
  });

  if (sendResult.invalidTokens.length > 0) {
    await serviceClient
      .from("app_push_tokens")
      .delete()
      .in("token", sendResult.invalidTokens);
  }

  return jsonResponse({
    ok: true,
    notification_id: inserted.id,
    sent: sendResult.sent,
    failed: sendResult.failed,
    removed_tokens: sendResult.invalidTokens.length,
  });
});

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function cleanText(raw: unknown, maxLen: number): string {
  const value = String(raw ?? "").trim();
  if (!value) return "";
  return value.slice(0, maxLen);
}

function normalizeTarget(raw: unknown): string {
  const value = String(raw ?? "").trim().toLowerCase();
  return validTargets.has(value) ? value : "gold_price";
}

function sanitizeDataPayload(raw: unknown): Record<string, string> {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return {};
  }

  const input = raw as Record<string, unknown>;
  const output: Record<string, string> = {};
  for (const [k, v] of Object.entries(input)) {
    const key = k.trim().replace(/[^a-zA-Z0-9_]/g, "_").slice(0, 40);
    if (!key) continue;
    output[key] = stringifyDataValue(v).slice(0, 250);
  }
  return output;
}

function stringifyDataValue(value: unknown): string {
  if (value == null) return "";
  if (typeof value === "string") return value;
  if (typeof value === "number" || typeof value === "boolean") {
    return String(value);
  }
  try {
    return JSON.stringify(value);
  } catch (_) {
    return String(value);
  }
}

async function sendToTokens(args: {
  projectId: string;
  accessToken: string;
  title: string;
  body: string;
  target: string;
  type: string;
  payload: Record<string, string>;
  tokens: string[];
}) {
  const { projectId, accessToken, title, body, target, type, payload, tokens } =
    args;

  const invalidTokens: string[] = [];
  let sent = 0;
  let failed = 0;

  const data = {
    target,
    type,
    ...payload,
  };

  const endpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  for (let i = 0; i < tokens.length; i += 25) {
    const chunk = tokens.slice(i, i + 25);
    await Promise.all(
      chunk.map(async (token) => {
        const result = await sendOneFcmMessage({
          endpoint,
          accessToken,
          token,
          title,
          body,
          data,
        });
        if (result.ok) {
          sent += 1;
          return;
        }
        failed += 1;
        if (result.unregistered) {
          invalidTokens.push(token);
        }
      }),
    );
  }

  return { sent, failed, invalidTokens };
}

async function sendOneFcmMessage(args: {
  endpoint: string;
  accessToken: string;
  token: string;
  title: string;
  body: string;
  data: Record<string, string>;
}) {
  const { endpoint, accessToken, token, title, body, data } = args;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
    },
    body: JSON.stringify({
      message: {
        token,
        notification: { title, body },
        data,
        android: {
          priority: "HIGH",
          notification: {
            channel_id: "mmgold_updates",
            icon: "ic_stat_mmgold",
            sound: "default",
          },
        },
        apns: {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default" } },
        },
      },
    }),
  });

  if (response.ok) {
    return { ok: true, unregistered: false };
  }

  const text = await response.text();
  const unregistered = text.includes("UNREGISTERED") ||
    text.includes("registration-token-not-registered") ||
    text.includes("Requested entity was not found");
  return { ok: false, unregistered };
}

async function getFirebaseAccessToken(args: {
  clientEmail: string;
  privateKey: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: args.clientEmail,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const jwtHeader = base64UrlEncode(JSON.stringify(header));
  const jwtClaim = base64UrlEncode(JSON.stringify(claimSet));
  const signingInput = `${jwtHeader}.${jwtClaim}`;

  const key = await importPrivateKey(args.privateKey);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    textEncoder.encode(signingInput),
  );

  const assertion =
    `${signingInput}.${base64UrlEncodeBytes(new Uint8Array(signature))}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Google token request failed: ${text}`);
  }

  const json = await response.json();
  const token = String(json.access_token ?? "");
  if (!token) {
    throw new Error("Google token is empty");
  }
  return token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const clean = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");

  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

function base64UrlEncode(input: string): string {
  return base64UrlEncodeBytes(textEncoder.encode(input));
}

function base64UrlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
