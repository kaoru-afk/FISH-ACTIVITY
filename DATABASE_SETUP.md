# FISH ACTIVITY database setup

## Current status
The schema foundation is maintained in database/001_initial_schema.sql. The browser application has Supabase connection/authentication and fishing-record workflows in its source. However, a successful public read check does not prove that signup/login or private-row inserts/updates work. Verify these flows in the deployed app before treating them as production-ready.

## What is stored
- Environment snapshots: weather/marine/tide values, provider/model, retrieval time, target time, units and quality.
- Predictions: species, spot, target time, score, component breakdown, missing factors, source snapshot IDs and algorithm version.
- Fishing trips: outing details and caught, blank, no-fishing or unknown result.
- Catch records: species, timestamp, size, weight, quantity, method and bait/lure.
- Spot observations: local baitfish, current, tide, water clarity, water temperature, wave and access notes.
- Fishing spots and species: reference catalogs with coordinate accuracy, access status, profile confidence and source provenance.

## Setup and security
1. Create a Supabase project.
2. Run the complete SQL in database/001_initial_schema.sql in the Supabase SQL Editor.
3. Enable the required authentication provider and configure the deployed GitHub Pages URL as the Site URL and allowed redirect URL.
4. Use only the project URL and public anon/publishable key in browser code.
5. Never place service_role/secret keys in index.html or a public repository.
6. Keep RLS enabled. SQL GRANT privileges and RLS policies are separate controls; both must be checked.
7. Shared automated ingestion requiring privileged credentials must run in a trusted server/Edge Function, not in the browser.

## Verification checklist
- Confirm public read access to fishing_spots and fish_species.
- Register and verify an account using the deployed domain redirect.
- Log in and log out from the deployed app.
- Insert and read back a fishing_trips row as the authenticated owner.
- Insert and read back a catch_records row linked to that trip.
- Verify another user cannot read or modify those private rows.
- Verify blank and no_fishing remain distinct in storage and analytics.

## Data quality rules
- Missing values remain NULL/missing, never zero.
- Store provider/model and retrieval timestamp for each forecast.
- Forecast coordinates are approximate unless independently verified.
- Environmental suitability is not catch probability.
- Do not tune a model using catch-only records; include blank trips and fishing effort/duration.
- Personal records remain private through Row Level Security.

## Related documents
See docs/README.md for the requirements, functional, system, database, scoring and test specifications.
