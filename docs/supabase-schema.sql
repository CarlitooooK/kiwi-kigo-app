-- =============================================
-- KIGO WELCOME INTELLIGENCE — MVP SCHEMA
-- Schema de CREACIÓN de la base. Nota: las políticas RLS fueron
-- modificadas después de este script (temas de seguridad).
-- Storage buckets en Supabase: `visit-evidence` y `visitor-photos`.
-- =============================================

-- 1. ORGANIZATIONS
CREATE TABLE public.organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  address TEXT,
  timezone TEXT DEFAULT 'America/Mexico_City',
  settings JSONB DEFAULT '{
    "auto_access_enabled": false,
    "trust_threshold": 70.0,
    "host_timeout_minutes": 5,
    "require_id_capture": true,
    "require_photo": true
  }'::jsonb,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. PROFILES (extends auth.users)
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'HOST' CHECK (role IN ('ADMIN', 'HOST', 'RECEPTION')),
  organization_id UUID REFERENCES public.organizations(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. VISITORS
CREATE TABLE public.visitors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  company TEXT,
  email TEXT,
  phone TEXT,
  visitor_type TEXT DEFAULT 'VISITOR' CHECK (
    visitor_type IN ('VISITOR', 'CLIENT', 'PROVIDER', 'MAINTENANCE', 'DELIVERY', 'INTERVIEW', 'OTHER')
  ),
  organization_id UUID REFERENCES public.organizations(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 4. VISITS
CREATE TABLE public.visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visitor_id UUID REFERENCES public.visitors(id),
  host_id UUID REFERENCES public.profiles(id),
  organization_id UUID NOT NULL REFERENCES public.organizations(id),
  purpose TEXT,
  area TEXT,
  source TEXT DEFAULT 'KIOSK' CHECK (source IN ('KIGO_APP', 'KIOSK', 'MANUAL')),
  status TEXT DEFAULT 'PENDING' CHECK (
    status IN ('PENDING', 'PRE_AUTHORIZED', 'IN_PROGRESS', 'CHECKED_IN', 'ACTIVE', 'COMPLETED', 'REJECTED', 'CANCELLED')
  ),
  scheduled_start TIMESTAMPTZ,
  scheduled_end TIMESTAMPTZ,
  checked_in_at TIMESTAMPTZ,
  checked_out_at TIMESTAMPTZ,
  is_preauthorized BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 5. VISIT EVIDENCE
CREATE TABLE public.visit_evidence (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('ID_FRONT', 'ID_BACK', 'SELFIE')),
  storage_path TEXT NOT NULL,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 6. TRUST EVALUATIONS
CREATE TABLE public.trust_evaluations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  score NUMERIC(5,2) CHECK (score >= 0 AND score <= 100),
  factors JSONB DEFAULT '{}',
  engine TEXT DEFAULT 'MOCK' CHECK (engine IN ('MOCK', 'AI_V1', 'AI_V2')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 7. ACCESS DECISIONS
CREATE TABLE public.access_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  decision TEXT NOT NULL CHECK (decision IN ('GRANTED', 'DENIED', 'REQUIRES_HOST', 'MANUAL_REVIEW')),
  decided_by TEXT CHECK (decided_by IN ('POLICY_AUTO', 'HOST', 'RECEPTION', 'ADMIN')),
  decided_by_user_id UUID REFERENCES public.profiles(id),
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. VISITOR JOURNEY EVENTS
CREATE TABLE public.visitor_journey_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL CHECK (
    event_type IN (
      'VISIT_CREATED', 'VISITOR_ARRIVED', 'IDENTITY_VALIDATED',
      'EVIDENCE_PROCESSED', 'TRUST_EVALUATED', 'ACCESS_REQUESTED',
      'HOST_NOTIFIED', 'HOST_APPROVED', 'HOST_REJECTED',
      'AUTO_AUTHORIZED', 'CHECKED_IN', 'CHECKED_OUT', 'ESCALATED'
    )
  ),
  payload JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 9. CONSENT RECORDS
CREATE TABLE public.consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  visit_id UUID NOT NULL REFERENCES public.visits(id) ON DELETE CASCADE,
  consent_version TEXT NOT NULL DEFAULT '1.0',
  accepted_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================
-- INDEXES
-- =============================================
CREATE INDEX idx_visits_organization ON public.visits(organization_id);
CREATE INDEX idx_visits_status ON public.visits(status);
CREATE INDEX idx_visits_host ON public.visits(host_id);
CREATE INDEX idx_visits_visitor ON public.visits(visitor_id);
CREATE INDEX idx_visits_scheduled ON public.visits(scheduled_start);
CREATE INDEX idx_visitors_organization ON public.visitors(organization_id);
CREATE INDEX idx_visitors_email ON public.visitors(email);
CREATE INDEX idx_visitors_phone ON public.visitors(phone);
CREATE INDEX idx_journey_visit ON public.visitor_journey_events(visit_id);
CREATE INDEX idx_journey_created ON public.visitor_journey_events(created_at);
CREATE INDEX idx_evidence_visit ON public.visit_evidence(visit_id);
CREATE INDEX idx_profiles_organization ON public.profiles(organization_id);

-- =============================================
-- TRIGGERS: auto-update updated_at
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_organizations
  BEFORE UPDATE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at_profiles
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at_visitors
  BEFORE UPDATE ON public.visitors
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER set_updated_at_visits
  BEFORE UPDATE ON public.visits
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================
-- AUTO-CREATE PROFILE ON SIGNUP
-- =============================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'HOST')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================
-- SEED: Demo organization
-- =============================================
INSERT INTO public.organizations (id, name, address, settings)
VALUES (
  'a0000000-0000-0000-0000-000000000001',
  'Kigo Demo Office',
  'Av. Chapultepec 123, CDMX',
  '{
    "auto_access_enabled": true,
    "trust_threshold": 70.0,
    "host_timeout_minutes": 5,
    "require_id_capture": true,
    "require_photo": true
  }'::jsonb
);
