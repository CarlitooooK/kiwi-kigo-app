-- =============================================
-- FACE ENROLLMENTS — Enrolamiento facial (Idea 1)
-- Ejecutar en el SQL Editor de Supabase.
-- =============================================
-- Guarda el embedding facial (MobileFaceNet, 192-d, L2-normalizado) de un
-- visitante para reconocimiento en visitas futuras. On-device: el embedding se
-- calcula en el F10 y se guarda aquí como array JSON.
--
-- `is_recurrent` lo activa el ANFITRIÓN tras un checkout (autoridad de
-- confianza). Solo los recurrentes pueden entrar directo con el rostro; el
-- resto solo autollena datos.

CREATE TABLE IF NOT EXISTS public.face_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id UUID NOT NULL REFERENCES public.visitors(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES public.organizations(id),
  embedding JSONB NOT NULL,               -- array de 192 floats (L2-normalizado)
  photo_path TEXT,                        -- ruta en storage (opcional)
  is_recurrent BOOLEAN NOT NULL DEFAULT FALSE,
  -- Integración Kigo Verify (opcional): id del enrollment remoto + estado.
  kigo_enrollment_id TEXT,
  kigo_status TEXT,                       -- PENDING/COMPLETED/etc
  consent_version TEXT NOT NULL DEFAULT '1.0',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_face_enroll_org ON public.face_enrollments(organization_id);
CREATE INDEX IF NOT EXISTS idx_face_enroll_visitor ON public.face_enrollments(visitor_id);
CREATE INDEX IF NOT EXISTS idx_face_enroll_recurrent ON public.face_enrollments(is_recurrent);

-- updated_at automático (usa la función existente handle_updated_at)
DROP TRIGGER IF EXISTS set_updated_at_face_enrollments ON public.face_enrollments;
CREATE TRIGGER set_updated_at_face_enrollments
  BEFORE UPDATE ON public.face_enrollments
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- RLS: mismas políticas que el resto (anon puede leer/insertar/actualizar en
-- ambiente de demo). Ajustar a producción después.
ALTER TABLE public.face_enrollments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_all_face_enrollments" ON public.face_enrollments;
CREATE POLICY "anon_all_face_enrollments" ON public.face_enrollments
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- También añade el evento de journey para el enrolamiento facial y el acceso
-- por rostro. EJECUTAR TAMBIÉN este bloque (recrea el CHECK de event_type):

ALTER TABLE public.visitor_journey_events
  DROP CONSTRAINT IF EXISTS visitor_journey_events_event_type_check;

ALTER TABLE public.visitor_journey_events
  ADD CONSTRAINT visitor_journey_events_event_type_check
  CHECK (event_type IN (
    'VISIT_CREATED','VISITOR_ARRIVED','IDENTITY_VALIDATED','EVIDENCE_PROCESSED',
    'TRUST_EVALUATED','ACCESS_REQUESTED','HOST_NOTIFIED','HOST_APPROVED',
    'HOST_REJECTED','AUTO_AUTHORIZED','CHECKED_IN','CHECKED_OUT','ESCALATED',
    'CANCELLED','FACE_ENROLLED','FACE_MATCH','RECURRENT_ENTERED'
  ));
