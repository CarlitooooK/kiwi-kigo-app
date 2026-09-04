-- ============================================================================
-- Kigo Welcome — Auto-expire "ghost" visits (server-side, pg_cron)
-- ============================================================================
-- Cancels visits that got stuck in a limbo state because the visitor abandoned
-- the flow, so they don't linger forever in the host console:
--
--   • PENDING / IN_PROGRESS  → CANCELLED after 10 minutes of inactivity
--       (visitor started but never got authorized / never finished).
--   • ACTIVE / CHECKED_IN    → CANCELLED after 8 hours
--       (entered but nobody ever checked them out).
--
-- Non-destructive: nothing is deleted; status just moves to CANCELLED and a
-- journey event is written so it stays auditable. Runs as SECURITY DEFINER so
-- it bypasses RLS, and is scheduled with pg_cron to run every minute — no app,
-- console, or kiosk needs to be open.
--
-- Apply: paste this whole file into the Supabase SQL Editor and run once.
-- ============================================================================

-- 1) Enable pg_cron (Supabase ships it; safe to run if already enabled).
create extension if not exists pg_cron;

-- 2) The cleanup function.
create or replace function public.expire_stale_visits()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  pending_cutoff timestamptz := now() - interval '10 minutes';
  active_cutoff  timestamptz := now() - interval '8 hours';
  affected_ids   uuid[];
begin
  -- Collect the ids we're about to cancel (both buckets in one pass), so we
  -- can both update them and log a journey event for each.
  select array_agg(id) into affected_ids
  from public.visits
  where
    (status in ('PENDING', 'IN_PROGRESS') and updated_at < pending_cutoff)
    or
    (status in ('ACTIVE', 'CHECKED_IN')   and updated_at < active_cutoff);

  if affected_ids is null or array_length(affected_ids, 1) is null then
    return 0;
  end if;

  -- Flip them to CANCELLED.
  update public.visits
  set status = 'CANCELLED',
      updated_at = now()
  where id = any(affected_ids);

  -- Audit trail: one journey event per cancelled visit.
  insert into public.visitor_journey_events (visit_id, event_type, payload)
  select
    id,
    'CANCELLED',
    jsonb_build_object('reason', 'AUTO_TIMEOUT', 'by', 'pg_cron')
  from unnest(affected_ids) as id;

  return array_length(affected_ids, 1);
end;
$$;

-- 3) Schedule it every minute. Unschedule first so re-running this file is safe
--    (avoids duplicate jobs with the same name).
do $$
begin
  perform cron.unschedule('expire-stale-visits')
  where exists (select 1 from cron.job where jobname = 'expire-stale-visits');
end;
$$;

select cron.schedule(
  'expire-stale-visits',
  '* * * * *',                 -- every minute
  $$ select public.expire_stale_visits(); $$
);

-- ---------------------------------------------------------------------------
-- Handy checks (run manually if you want to verify):
--   select public.expire_stale_visits();        -- run once, returns count
--   select * from cron.job;                      -- confirm the schedule
--   select * from cron.job_run_details           -- recent runs
--     order by start_time desc limit 10;
-- ---------------------------------------------------------------------------
