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