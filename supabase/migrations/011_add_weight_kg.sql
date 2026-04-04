-- Add weight (kg) to profiles for C2 Logbook weight class derivation.
alter table profiles add column weight_kg numeric check (weight_kg > 0 and weight_kg < 500);
