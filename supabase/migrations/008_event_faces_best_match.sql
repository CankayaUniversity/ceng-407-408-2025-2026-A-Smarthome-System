-- Closest resident candidate for unknown / borderline face matches (identity review UI).

ALTER TABLE public.event_faces
  ADD COLUMN IF NOT EXISTS best_match_resident_id UUID REFERENCES public.residents(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_event_faces_best_match_resident
  ON public.event_faces (best_match_resident_id)
  WHERE best_match_resident_id IS NOT NULL;
