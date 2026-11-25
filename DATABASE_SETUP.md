# FISH ACTIVITY database setup

## Status
The initial PostgreSQL/Supabase schema is in database/001_initial_schema.sql. This is the database foundation; it is not yet connected to a live Supabase project. The GitHub Pages app currently has no project URL or public key, so cloud writes are not active.

## What is stored
- Environment snapshots: immutable weather/marine/tide forecast values, units, provider/model, retrieval time, and target time.
- Predictions: species, spot, target time, score, component breakdown, missing factors, source snapshot IDs, and algorithm version.
- Fishing trips: outing details and successful, blank, no-fishing, or unknown result.
- Catch records: species, timestamp, size, weight, quantity, method, and bait/lure.
- Spot observations: local baitfish, actual current, tide, water clarity, water temperature, wave, and access notes.
- Fishing spots and species: reference catalogs with coordinate accuracy, access status, ecological profile confidence, and source provenance.

## Setup
1. Create a Supabase project at https://supabase.com/.
2. Open SQL Editor in the Supabase dashboard.
3. Run the complete contents of database/001_initial_schema.sql.
4. Enable an authentication method before saving personal trip/catch records.
5. Never expose the service_role/secret key in index.html or a public repository.
6. The browser may use only the project URL and public anon/publishable key, with Row Level Security enabled. Shared automated forecast ingestion should run through a trusted Edge Function/server using the service role key.

## Collection workflow
- On successful weather/marine API responses, preserve forecast snapshots with provider, model, retrieved time, forecast target time, units, and per-field availability.
- When scores are calculated, store component values/weights, missing factors, algorithm version, and linked snapshot IDs.
- Record every outing, including blank trips; link each catch to its trip.
- Keep user-entered observations separate from broad model forecasts.
- Later compare predictions against trips/catches by species, spot, season, tide, and forecast conditions.

## Data quality rules
- Missing values remain NULL/missing, never zero.
- Store provider/model and retrieval timestamp for each forecast.
- Forecast coordinates are approximate unless independently verified.
- Environmental suitability is not catch probability.
- Do not tune a model using catch-only records; include blank trips and fishing effort/duration.
- Personal records remain private through Row Level Security.
