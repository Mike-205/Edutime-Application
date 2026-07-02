// request-account-deletion — the surfaced Kenya DPA deletion path.
//
// Records a pending deletion request for the authenticated user. Fulfilment is
// MANUAL at MVP: the owner deletes the auth.users row, which cascades to erase
// the person (users/device_tokens/notifications) and set-nulls their authored
// events + audit (0011), retaining the cohort's schedule. Deduplicated so a user
// can't stack pending requests.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = adminClient();
  const callerId = await getCallerId(req, admin);
  if (!callerId) return json({ error: "unauthorized" }, 401);

  const { data: existing } = await admin
    .from("deletion_requests")
    .select("id")
    .eq("user_id", callerId)
    .eq("status", "pending")
    .maybeSingle();
  if (existing) return json({ ok: true, already_requested: true }, 200);

  const { error } = await admin
    .from("deletion_requests")
    .insert({ user_id: callerId });
  if (error) return json({ error: "request_failed" }, 500);

  return json({ ok: true }, 201);
});
