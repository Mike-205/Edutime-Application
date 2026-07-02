// FCM HTTP v1 client for Edge Functions (Deno).
//
// The legacy FCM server-key API was shut down by Google (mid-2024). This uses
// FCM HTTP v1: sign a short-lived JWT with the service-account private key
// (RS256), exchange it for an OAuth2 access token, then call the v1 send
// endpoint. No external deps — Web Crypto + fetch only.
//
// Env: FCM_SERVICE_ACCOUNT = the full service-account JSON (a single string).
// Get it from Firebase console -> Project settings -> Service accounts ->
// "Generate new private key". project_id is read from that JSON.
//
// Access tokens last ~1h; cached per function instance to avoid re-signing on
// every push (the notifications milestone fans out many pushes per change).

interface ServiceAccount {
  client_email: string;
  private_key: string;
  token_uri: string;
  project_id: string;
}

const FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging";
const DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token";

let cachedAccount: ServiceAccount | null = null;
let cachedToken: { value: string; expiresAt: number } | null = null;

function loadAccount(): ServiceAccount {
  if (cachedAccount) return cachedAccount;
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT");
  if (!raw) throw new Error("FCM_SERVICE_ACCOUNT is not set");
  let acct: ServiceAccount;
  try {
    acct = JSON.parse(raw) as ServiceAccount;
  } catch {
    throw new Error("FCM_SERVICE_ACCOUNT is not valid JSON");
  }
  if (!acct.client_email || !acct.private_key || !acct.project_id) {
    throw new Error(
      "FCM_SERVICE_ACCOUNT missing client_email / private_key / project_id",
    );
  }
  acct.token_uri ||= DEFAULT_TOKEN_URI;
  cachedAccount = acct;
  return acct;
}

/** base64url, no padding. */
function base64url(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64urlJson(obj: unknown): string {
  return base64url(new TextEncoder().encode(JSON.stringify(obj)));
}

/** PEM (PKCS#8) private key -> CryptoKey for RS256 signing. */
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const der = Uint8Array.from(
    atob(
      pem
        .replace(/-----BEGIN PRIVATE KEY-----/, "")
        .replace(/-----END PRIVATE KEY-----/, "")
        .replace(/\s+/g, ""),
    ),
    (c) => c.charCodeAt(0),
  );
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Mint (or reuse a cached) OAuth2 access token via the JWT-bearer grant. */
async function mintAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt > now + 60) return cachedToken.value;

  const acct = loadAccount();
  const signingInput = `${base64urlJson({ alg: "RS256", typ: "JWT" })}.${
    base64urlJson({
      iss: acct.client_email,
      scope: FCM_SCOPE,
      aud: acct.token_uri,
      iat: now,
      exp: now + 3600,
    })
  }`;
  const key = await importPrivateKey(acct.private_key);
  const sig = await crypto.subtle.sign(
    { name: "RSASSA-PKCS1-v1_5" },
    key,
    new TextEncoder().encode(signingInput),
  );
  const assertion = `${signingInput}.${base64url(new Uint8Array(sig))}`;

  const res = await fetch(acct.token_uri, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`token exchange failed: ${res.status} ${await res.text()}`);
  }
  const tok = await res.json() as { access_token: string; expires_in: number };
  cachedToken = { value: tok.access_token, expiresAt: now + tok.expires_in };
  return tok.access_token;
}

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

export interface SendResult {
  token: string;
  ok: boolean;
  name?: string; // FCM message id on success
  status?: number;
  error?: string;
  unregistered?: boolean; // stale token — caller should delete it
}

/** Send one push via FCM HTTP v1. */
export async function sendPush(msg: PushMessage): Promise<SendResult> {
  const acct = loadAccount();
  const accessToken = await mintAccessToken();
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${acct.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: msg.token,
          notification: { title: msg.title, body: msg.body },
          data: msg.data,
        },
      }),
    },
  );
  if (res.ok) {
    const out = await res.json() as { name: string };
    return { token: msg.token, ok: true, name: out.name };
  }
  const error = await res.text();
  // UNREGISTERED / NOT_FOUND => the token is dead; caller should prune it.
  const unregistered = res.status === 404 ||
    /UNREGISTERED|registration-token-not-registered/i.test(error);
  return { token: msg.token, ok: false, status: res.status, error, unregistered };
}

/**
 * Fan one message out to many tokens from a single invocation (ARCHITECTURE.md
 * NFR #4 — batch inside the function, never one invocation per recipient).
 */
export async function sendPushMulti(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<SendResult[]> {
  return await Promise.all(
    tokens.map((token) => sendPush({ token, title, body, data })),
  );
}
