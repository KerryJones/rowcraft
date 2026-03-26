-- Add current FTP to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS current_ftp_watts int;

-- FTP history table
CREATE TABLE public.ftp_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tested_at timestamptz NOT NULL DEFAULT now(),
  ftp_watts int NOT NULL CHECK (ftp_watts > 0),
  test_type text NOT NULL CHECK (test_type IN ('ramp', '20min', 'manual')),
  source_result_id uuid REFERENCES public.workout_results(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE public.ftp_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own FTP history"
  ON public.ftp_history FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own FTP history"
  ON public.ftp_history FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Index for efficient per-user FTP history queries
CREATE INDEX idx_ftp_history_user_tested
  ON public.ftp_history (user_id, tested_at DESC);
