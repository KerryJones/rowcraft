-- Add max heart rate to profiles for HR zone calculations
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS max_heart_rate int;
