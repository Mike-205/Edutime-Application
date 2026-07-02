-- seed.sql — local/dev seed data + a guide for real production seeding.
--
-- The reference hierarchy is seeded by the platform owner (superadmin) from
-- campus knowledge as a one-time step BEFORE any user onboards. A class rep can
-- schedule NOTHING until this data exists — a course must be seeded for the
-- cohort's program, and a venue must exist for the room being booked.
--
-- Insert ORDER matters (FK dependencies):
--   1. faculties
--   2. departments      (-> faculties)
--   3. programs         (-> departments)
--   4. courses          (-> programs)          [the unit registry]
--   5. cohorts          (-> programs)           name = "<program.abbr> <year>"
--   6. buildings
--   7. rooms            (-> buildings)          only the rooms each bldg has;
--                                                display "S-101" is derived on
--                                                read (bldg.abbr || '-' || number)
--   8. venues           (physical -> rooms; online -> meeting_link/platform)
--
-- Venue rule (see 0001): PHYSICAL venues are ONE row per room (shared reference
-- data — the conflict constraint depends on this). ONLINE venues are created
-- PER EVENT by the scheduler, so seed at most a template/none here.
--
-- Faculty Rep accounts are bootstrapped manually (out-of-band verification +
-- service-role promotion) and are intentionally NOT seeded here.
--
-- HOW TO SEED REAL CHUKA DATA:
--   Replace the DEV SAMPLE below with the real faculties/departments/programs/
--   courses and buildings/rooms. Let ids default (gen_random_uuid()); only pin
--   ids when a later insert must reference them in the same script, as shown.
--   Keep abbreviations consistent — cohort/room display names are built from them.

-- DEV SAMPLE (remove for production) -----------------------------------------
-- A full faculty -> department -> program -> course chain plus a building/room/
-- venue, so scheduling and the join-by-code flow are testable locally without an
-- out-of-band admin step. Join with code DEVCS1.

insert into faculties (id, name, abbreviation, description) values
  ('f0000000-0000-0000-0000-000000000001',
   'Faculty of Science', 'FSCI', 'Sample faculty for local development');

insert into departments (id, faculty_id, name, description) values
  ('d0000000-0000-0000-0000-000000000001',
   'f0000000-0000-0000-0000-000000000001',
   'Computer Science', 'Sample department for local development');

insert into programs
  (id, department_id, name, abbreviation, code, level, duration_semesters)
values
  ('40000000-0000-0000-0000-000000000001',
   'd0000000-0000-0000-0000-000000000001',
   'BSc Computer Science', 'BSC-CS', 'CS', 'degree', 8);

insert into courses
  (id, program_id, name, abbreviation, semester_taught, lecture_hours, credits)
values
  ('c1000000-0000-0000-0000-000000000001',
   '40000000-0000-0000-0000-000000000001',
   'Introduction to Programming', 'CS101', 1, 45, 3),
  ('c1000000-0000-0000-0000-000000000002',
   '40000000-0000-0000-0000-000000000001',
   'Data Structures & Algorithms', 'CS201', 2, 45, 3);

insert into cohorts
  (id, program_id, name, join_code, intake_year, current_semester, pace)
values
  ('c0000000-0000-0000-0000-000000000001',
   '40000000-0000-0000-0000-000000000001',
   'BSC-CS 2025', 'DEVCS1', 2025, 1, 'bimester');

insert into buildings (id, name, abbreviation, description) values
  ('b0000000-0000-0000-0000-000000000001',
   'Science Complex', 'SC', 'Sample building for local development');

-- Only the rooms this building actually has. Display name ("SC-101") is derived
-- on read from the building abbreviation + number, never stored.
insert into rooms (id, building_id, number, capacity, room_type) values
  ('40000000-0000-0000-0000-0000000000aa',
   'b0000000-0000-0000-0000-000000000001', '101', 250, 'lecture_hall'),
  ('40000000-0000-0000-0000-0000000000bb',
   'b0000000-0000-0000-0000-000000000001', '102',  60, 'lab');

-- Physical venues: exactly one per room (the conflict constraint relies on this).
-- No label needed — the display name comes from the linked room.
insert into venues (id, type, room_id) values
  ('40000000-0000-0000-0000-0000000000a1',
   'physical', '40000000-0000-0000-0000-0000000000aa'),
  ('40000000-0000-0000-0000-0000000000b1',
   'physical', '40000000-0000-0000-0000-0000000000bb');
-- Online venues are created per event by the scheduler; none seeded here.
