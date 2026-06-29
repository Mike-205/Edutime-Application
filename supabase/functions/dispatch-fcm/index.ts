// dispatch-fcm — push notifications on lecture changes.
//
// Trigger path (ARCHITECTURE.md open question #1, recommended):
//   Supabase Database Webhook on `lectures` (INSERT/UPDATE) -> this function.
// Responsibility:
//   - Determine the change type (new | updated | canceled).
//   - Resolve recipient FCM tokens for the affected cohort's students.
//   - Send via FCM and write a notifications row per recipient (in-app history).
// A last-minute venue change must fire a fresh notification. Implemented in the
// "notifications" milestone — the feature defended to the death in the cut-list.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // TODO(notifications milestone): verify webhook secret, parse the lecture
  // change payload, resolve tokens, call FCM, insert notifications rows.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  void supabase;

  return new Response(
    JSON.stringify({ error: "not_implemented", function: "dispatch-fcm" }),
    { status: 501, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});