// schedule-lecture — UX layer over the DB conflict constraints.
//
// Responsibility (see ARCHITECTURE.md "Data Flow — Core Action"):
//   1. Run a readable pre-check and, on conflict, return a forwardable error
//      ("Venue LH3 is taken by Stats II, 14:00-16:00") BEFORE attempting insert.
//   2. Insert the lecture (one row, or one row per occurrence for a recurring
//      series sharing a recurrence_group_id).
//   3. The Postgres EXCLUDE constraints remain the ground truth — a constraint
//      violation is caught and surfaced as the same readable conflict error.
//   4. Append a lecture_audit_log row.
//
// This function is NOT the authority. The database is. Implemented in the
// "scheduling" milestone (/code-branch).

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // TODO(scheduling milestone): authenticate caller, validate class_rep role,
  // run pre-check, materialize occurrences, insert under constraint, audit-log.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  void supabase; // referenced once milestone logic lands

  return new Response(
    JSON.stringify({ error: "not_implemented", function: "schedule-lecture" }),
    { status: 501, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});