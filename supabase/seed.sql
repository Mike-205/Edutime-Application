-- seed.sql — local/dev seed data.
--
-- Venues are seeded by the platform owner (superadmin) from physical campus
-- knowledge as a one-time step BEFORE any user onboards. Replace the sample
-- rows below with the real Chuka University venue registry.
--
-- Faculty Rep accounts are bootstrapped manually (out-of-band verification +
-- service-role promotion) and are intentionally NOT seeded here.

insert into venues (name, capacity, type, building) values
  ('LH1',  250, 'lecture_hall',  'Main Block'),
  ('LH3',  180, 'lecture_hall',  'Main Block'),
  ('Lab 2', 60, 'lab',           'Science Complex'),
  ('TR4',   40, 'tutorial_room', 'Annex'),
  ('Online', null, 'online',     null);

-- DEV SAMPLE (remove for production) -----------------------------------------
-- A faculty → program → cohort chain so the join-by-code flow is testable
-- locally without an out-of-band admin step. Real faculties/programs/cohorts
-- are created out-of-band by the platform owner. Join with code DEVCS1.
insert into faculties (id, name, description) values
  ('f0000000-0000-0000-0000-000000000001',
   'Faculty of Science', 'Sample faculty for local development');

insert into programs (id, faculty_id, name, description, total_semesters) values
  ('40000000-0000-0000-0000-000000000001',
   'f0000000-0000-0000-0000-000000000001',
   'BSc Computer Science', 'Sample program for local development', 8);

insert into cohorts (id, program_id, intake_year, current_semester, join_code)
values
  ('c0000000-0000-0000-0000-000000000001',
   '40000000-0000-0000-0000-000000000001', 2025, 1, 'DEVCS1');