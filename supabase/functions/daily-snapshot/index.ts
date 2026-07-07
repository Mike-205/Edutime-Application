// daily-snapshot — scheduled instrumentation writer.
//
// Runs once/day (Supabase scheduled function / pg_cron). Delegates all metric
// computation to the record_daily_snapshot() DB function (SECURITY DEFINER,
// which can read auth.users + pg_database_size) and returns the row. This is the
// queryable log behind both the success metrics and the free-tier upgrade
// trigger (DB > 400MB, MAU > 500, >=3 active cohorts for 7 consecutive days).
// Upsert-per-day, so a stray extra call is harmless. Not a dashboard.

import { corsHeaders, json } from "../_shared/cors.ts";
import { adminClient } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const { data, error } = await adminClient().rpc("record_daily_snapshot");
  if (error) {
    return json({ error: "snapshot_failed", detail: error.message }, 500);
  }
  return json({ snapshot: data }, 200);
});
