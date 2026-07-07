// fcm-poc — proof-of-concept for FCM HTTP v1 dispatch.
//
// Purpose: prove the hardest backend path end-to-end BEFORE the notifications
// milestone — mint an OAuth2 token from the service-account key and land one
// real push on a real device. This is a throwaway harness, NOT part of the MVP
// surface: delete it once `dispatch-fcm` is implemented and verified (both
// reuse ../_shared/fcm.ts, so the transport is already proven).
//
// Local run:
//   supabase functions serve fcm-poc --env-file supabase/functions/.env
//   curl -i -X POST http://localhost:54321/functions/v1/fcm-poc \
//     -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
//     -H "Content-Type: application/json" \
//     -d '{"token":"<device-fcm-token>","title":"Edutime","body":"It works 🎉"}'
//
// Env (in supabase/functions/.env — never commit):
//   FCM_SERVICE_ACCOUNT='<full service-account JSON on one line>'
// Grab a device token by logging FirebaseMessaging.instance.getToken() from the
// Flutter app on a physical device (FCM push does not deliver to emulators
// without Play services).

import { corsHeaders, json } from "../_shared/cors.ts";
import { sendPush } from "../_shared/fcm.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_body" }, 400);
  }

  const token = (body.token as string | undefined)?.trim();
  if (!token) return json({ error: "missing_token" }, 400);
  const title = (body.title as string | undefined)?.trim() || "Edutime";
  const text = (body.body as string | undefined)?.trim() ||
    "FCM HTTP v1 proof-of-concept 🎉";

  try {
    const result = await sendPush({
      token,
      title,
      body: text,
      data: { source: "fcm-poc" },
    });
    // Return FCM's verdict verbatim so you can see exactly what happened.
    return json(result, result.ok ? 200 : 502);
  } catch (e) {
    // Config error: missing/invalid FCM_SERVICE_ACCOUNT or token-exchange failure.
    return json({ error: "dispatch_failed", detail: String(e) }, 500);
  }
});
