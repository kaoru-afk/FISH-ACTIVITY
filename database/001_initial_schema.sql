create extension if not exists pgcrypto;
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;

create table if not exists public.fishing_spots (
 id uuid primary key default gen_random_uuid(), spot_key text not null unique, name text not null,
 prefecture text not null, area_key text not null, area_name text,
 spot_type text not null check (spot_type in ('port','rocky','offshore','surf','river','other')),
 latitude double precision not null check (latitude between -90 and 90),
 longitude double precision not null check (longitude between -180 and 180),
 coordinate_precision text not null default 'approximate' check (coordinate_precision in ('exact','approximate','area_center')),
 access_status text not null default 'unverified' check (access_status in ('verified_open','restricted','prohibited','unverified')),
 access_notes text, source_name text, source_url text, last_verified_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

create table if not exists public.fish_species (
 id uuid primary key default gen_random_uuid(), species_key text not null unique, name_ja text not null unique,
 scientific_name text, profile jsonb not null default '{}'::jsonb,
 profile_confidence text not null default 'unverified' check (profile_confidence in ('high','medium','low','unverified')),
 source_notes text, source_url text, updated_at timestamptz not null default now()
);

create table if not exists public.environment_snapshots (
 id uuid primary key default gen_random_uuid(), spot_id uuid references public.fishing_spots(id) on delete set null,
 spot_key text, forecast_for timestamptz not null, retrieved_at timestamptz not null default now(),
 data_kind text not null check (data_kind in ('weather','marine','tide','current','baitfish','manual_observation')),
 provider text not null, model_name text, latitude double precision, longitude double precision,
 payload jsonb not null, units jsonb not null default '{}'::jsonb, quality jsonb not null default '{}'::jsonb,
 app_version text, created_at timestamptz not null default now()
);
create index if not exists environment_snapshots_spot_time_idx on public.environment_snapshots (spot_id, forecast_for desc);
create index if not exists environment_snapshots_kind_time_idx on public.environment_snapshots (data_kind, forecast_for desc);
create index if not exists environment_snapshots_retrieved_idx on public.environment_snapshots (retrieved_at desc);

create table if not exists public.predictions (
 id uuid primary key default gen_random_uuid(), spot_id uuid references public.fishing_spots(id) on delete set null,
 spot_key text, species_id uuid references public.fish_species(id) on delete set null,
 species_name text not null, target_time timestamptz not null, generated_at timestamptz not null default now(),
 score integer check (score between 0 and 100),
 score_type text not null default 'environmental_suitability' check (score_type in ('environmental_suitability','catch_probability')),
 components jsonb not null default '[]'::jsonb, missing_factors jsonb not null default '[]'::jsonb,
 input_snapshot_ids uuid[] not null default '{}', algorithm_version text not null, explanation text,
 created_at timestamptz not null default now()
);
create index if not exists predictions_spot_species_time_idx on public.predictions (spot_id, species_name, target_time desc);
create index if not exists predictions_generated_idx on public.predictions (generated_at desc);

create table if not exists public.fishing_trips (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 spot_id uuid references public.fishing_spots(id) on delete set null, spot_name text not null,
 prefecture text, area_name text, started_at timestamptz not null, ended_at timestamptz,
 target_species text[] not null default '{}', fishing_method text, tackle jsonb not null default '{}'::jsonb,
 bait_or_lure text, result_status text not null default 'unknown'
 check (result_status in ('caught','blank','no_fishing','unknown')),
 notes text, weather_snapshot_id uuid references public.environment_snapshots(id) on delete set null,
 prediction_id uuid references public.predictions(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (ended_at is null or ended_at >= started_at)
);
create index if not exists fishing_trips_user_started_idx on public.fishing_trips (user_id, started_at desc);
create index if not exists fishing_trips_spot_started_idx on public.fishing_trips (spot_id, started_at desc);

create table if not exists public.catch_records (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 trip_id uuid not null references public.fishing_trips(id) on delete cascade,
 species_id uuid references public.fish_species(id) on delete set null, species_name text not null,
 caught_at timestamptz not null, length_cm numeric(6,2) check (length_cm is null or length_cm > 0),
 weight_kg numeric(7,3) check (weight_kg is null or weight_kg > 0),
 quantity integer not null default 1 check (quantity > 0), fishing_method text, bait_or_lure text,
 notes text, created_at timestamptz not null default now()
);
create index if not exists catch_records_user_caught_idx on public.catch_records (user_id, caught_at desc);
create index if not exists catch_records_species_caught_idx on public.catch_records (species_name, caught_at desc);

create table if not exists public.spot_observations (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 spot_id uuid references public.fishing_spots(id) on delete set null, spot_name text not null,
 observed_at timestamptz not null default now(),
 observation_type text not null check (observation_type in ('baitfish','current','tide','water_clarity','water_temperature','wave','wildlife','access','other')),
 value jsonb not null, notes text, created_at timestamptz not null default now()
);
create index if not exists spot_observations_spot_time_idx on public.spot_observations (spot_id, observed_at desc);

drop trigger if exists fishing_spots_updated_at on public.fishing_spots;
create trigger fishing_spots_updated_at before update on public.fishing_spots for each row execute function public.set_updated_at();
drop trigger if exists fishing_trips_updated_at on public.fishing_trips;
create trigger fishing_trips_updated_at before update on public.fishing_trips for each row execute function public.set_updated_at();

alter table public.fishing_spots enable row level security;
alter table public.fish_species enable row level security;
alter table public.environment_snapshots enable row level security;
alter table public.predictions enable row level security;
alter table public.fishing_trips enable row level security;
alter table public.catch_records enable row level security;
alter table public.spot_observations enable row level security;

drop policy if exists "public read fishing spots" on public.fishing_spots;
create policy "public read fishing spots" on public.fishing_spots for select using (true);
drop policy if exists "public read fish species" on public.fish_species;
create policy "public read fish species" on public.fish_species for select using (true);
drop policy if exists "authenticated read environment snapshots" on public.environment_snapshots;
create policy "authenticated read environment snapshots" on public.environment_snapshots for select to authenticated using (true);
drop policy if exists "authenticated read predictions" on public.predictions;
create policy "authenticated read predictions" on public.predictions for select to authenticated using (true);
drop policy if exists "owners manage trips" on public.fishing_trips;
create policy "owners manage trips" on public.fishing_trips for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "owners manage catches" on public.catch_records;
create policy "owners manage catches" on public.catch_records for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "owners manage observations" on public.spot_observations;
create policy "owners manage observations" on public.spot_observations for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

comment on table public.environment_snapshots is 'Append-only forecast snapshots preserving forecast vintage.';
comment on table public.predictions is 'Environmental suitability predictions, not catch guarantees.';
comment on table public.fishing_trips is 'One row per outing, including blank trips.';
comment on table public.catch_records is 'Catch events linked to a fishing trip.';
