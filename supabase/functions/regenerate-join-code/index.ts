// regenerate-join-code — a class rep rotates their own cohort's join code
// (e.g. after a leak). Class-rep-gated; operates only on the caller's cohort.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient, getCallerId, getCallerProfile } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const admin = adminClient();
  const callerId = await getCallerId(req, admin);
  if (!callerId) return json({ error: "unauthorized" }, 401);

  const profile = await getCallerProfile(admin, callerId);
  if (!profile) return json({ error: "lookup_failed" }, 500);
  if (profile.role !== "class_rep" || !profile.cohortId) {
    return json({ error: "forbidden" }, 403);
  }

  const { data: code, error: genErr } = await admin.rpc("gen_unique_join_code");
  if (genErr || typeof code !== "string") {
    return json({ error: "generate_failed" }, 500);
  }

  const { error: updateErr } = await admin
    .from("cohorts")
    .update({ join_code: code })
    .eq("id", profile.cohortId);
  if (updateErr) return json({ error: "update_failed" }, 500);

  return json({ join_code: code }, 200);
});
