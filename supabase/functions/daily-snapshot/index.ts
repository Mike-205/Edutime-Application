// daily-snapshot — scheduled instrumentation writer.
//
// Runs once/day (Supabase scheduled function / pg_cron). Records MAU, active
// cohort count, DB size estimate, and conflict-incident count into
// daily_snapshots. This is the queryable log behind both the success metrics
// and the free-tier upgrade trigger (DB > 400MB, MAU > 500, >=3 active
// cohorts for 7 consecutive days). Not a dashboard.

import { createClient } from "jsr:@supabase/supabase-js@2";

Deno.serve(async () => {
  // TODO(instrumentation milestone): compute metrics and upsert today's row.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  void supabase;

  return new Response(
    JSON.stringify({ error: "not_implemented", function: "daily-snapshot" }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  );
});