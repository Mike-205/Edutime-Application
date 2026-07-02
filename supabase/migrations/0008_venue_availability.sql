-- 0008_venue_availability.sql — cross-cohort venue availability (Journey 3)
--
-- "Which rooms are free right now?" is inherently CROSS-COHORT: a room is busy
-- if ANY cohort booked it. But events_select_own_cohort (0003) restricts a
-- client to its own cohort's events, so this cannot be computed client-side.
--
-- This SECURITY DEFINER function bypasses that RLS to reveal ONLY room
-- busy-ness — venue id, composed room name, type, occupied flag, and when it
-- frees up. It exposes NO other cohort's schedule, course, lecturer, or personal
-- data, so the DPA cross-cohort isolation guarantee is preserved (room occupancy
-- is not protected personal data). See ARCHITECTURE.md Journey 3.
--
-- Only PHYSICAL venues are returned: they are shared rooms one can walk to.
-- Online venues are per-event and meaningless to "browse for a free room".
--
-- No aggregation needed: the events_no_venue_overlap EXCLUDE constraint (0002)
-- guarantees at most one non-canceled event overlaps a venue at any instant, so
-- the LEFT JOIN yields 0 or 1 row per venue.
create or replace function public.venue_availability(at_time timestamptz)
returns table (
  venue_id     uuid,
  display_name text,
  room_type    room_type,
  occupied     boolean,
  busy_until   timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    v.id                                as venue_id,
    b.abbreviation || '-' || r.number   as display_name,
    r.room_type                         as room_type,
    (e.id is not null)                  as occupied,
    e.end_time                          as busy_until
  from venues v
  join rooms r     on r.id = v.room_id
  join buildings b on b.id = r.building_id
  left join events e
    on  e.venue_id = v.id
    and e.status <> 'canceled'
    and e.start_time <= at_time
    and e.end_time   >  at_time
  where v.type = 'physical'
  order by display_name;
$$;

grant execute on function public.venue_availability(timestamptz) to authenticated;
