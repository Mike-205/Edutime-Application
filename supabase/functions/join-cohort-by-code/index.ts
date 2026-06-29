// join-cohort-by-code — self-service cohort join (no approval queue).
//
// Responsibility (pressure-test decision):
//   - Look up the cohort by join_code.
//   - On match, set the caller's users.cohort_id immediately (no waiting state).
//   - On no match, return a clear "invalid code" error.
// The class rep's remove-student action is the safety valve; there is no
// approval step. Implemented in the "cohort & membership" milestone.

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // TODO(cohort milestone): authenticate caller, read { join_code } from body,
  // resolve cohort, update users.cohort_id, return the joined cohort summary.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  void supabase;

  return new Response(
    JSON.stringify({ error: "not_implemented", function: "join-cohort-by-code" }),
    { status: 501, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});