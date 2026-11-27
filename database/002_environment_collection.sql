-- FISH ACTIVITY: automated environmental data collection foundation
-- Apply after database/001_initial_schema.sql in Supabase SQL Editor.
begin;

create table if not exists public.data_collection_targets (
  id uuid primary key default gen_random_uuid(),
  target_key text not null unique,
  target_type text not null check (target_type in ('spot','area')),
  prefecture text not null,
  municipality text not null,
  area_name text,
  location_name text not null,
  spot_id uuid references public.fishing_spots(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  coordinate_precision text not null default 'approximate'
    check (coordinate_precision in ('exact','approximate','area_center')),
  collection_interval_minutes integer not null default 60
    check (collection_interval_minutes in (30,60,180,360,720,1440)),
  data_categories text[] not null default array['weather','marine','tide']::text[],
  is_active boolean not null default true,
  source_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint data_collection_target_spot_check
    check ((target_type = 'spot' and spot_id is not null) or
           (target_type = 'area' and spot_id is null))
);

create index if not exists data_collection_targets_active_idx
  on public.data_collection_targets (is_active, target_type, municipality);

alter table public.environment_snapshots
  add column if not exists collection_target_id uuid
    references public.data_collection_targets(id) on delete set null;

alter table public.environment_snapshots
  add column if not exists record_type text not null default 'unknown';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'environment_snapshots_record_type_check'
      and conrelid = 'public.environment_snapshots'::regclass
  ) then
    alter table public.environment_snapshots
      add constraint environment_snapshots_record_type_check
      check (record_type in ('observation','forecast','model_estimate','manual','unknown'));
  end if;
end $$;

create index if not exists environment_snapshots_target_time_idx
  on public.environment_snapshots (collection_target_id, forecast_for desc);

-- Observation imports are idempotent. Forecast vintages remain append-only:
-- each forecast retrieval can be preserved with its own retrieved_at.
create unique index if not exists environment_snapshots_observation_dedupe_idx
  on public.environment_snapshots
    (collection_target_id, forecast_for, data_kind, provider)
  where record_type = 'observation' and collection_target_id is not null;

create table if not exists public.data_collection_runs (
  id uuid primary key default gen_random_uuid(),
  collection_target_id uuid references public.data_collection_targets(id) on delete set null,
  provider text not null,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running','succeeded','partial','failed')),
  records_inserted integer not null default 0 check (records_inserted >= 0),
  records_skipped integer not null default 0 check (records_skipped >= 0),
  error_summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (finished_at is null or finished_at >= started_at)
);

create index if not exists data_collection_runs_started_idx
  on public.data_collection_runs (started_at desc);
create index if not exists data_collection_runs_target_started_idx
  on public.data_collection_runs (collection_target_id, started_at desc);

drop trigger if exists data_collection_targets_updated_at on public.data_collection_targets;
create trigger data_collection_targets_updated_at
  before update on public.data_collection_targets
  for each row execute function public.set_updated_at();

alter table public.data_collection_targets enable row level security;
alter table public.data_collection_runs enable row level security;

drop policy if exists "public read active collection targets" on public.data_collection_targets;
create policy "public read active collection targets"
  on public.data_collection_targets for select using (is_active = true);

-- Writes are performed only by trusted scheduled server functions using the
-- Supabase service_role key. Never place that key in GitHub Pages/browser code.
grant select on public.data_collection_targets to anon, authenticated;
grant all on public.data_collection_targets to service_role;
grant all on public.environment_snapshots to service_role;
grant all on public.data_collection_runs to service_role;

comment on table public.data_collection_targets is
  'Configured spot/area locations for scheduled environmental data collection. Default interval is 60 minutes.';
comment on column public.environment_snapshots.record_type is
  'observation=observed/reanalysis value; forecast=forecast vintage; model_estimate=model-derived; manual=user observation; unknown=legacy/unclassified.';
comment on table public.data_collection_runs is
  'Operational log for scheduled data collection jobs; write access is service-side only.';

commit;
