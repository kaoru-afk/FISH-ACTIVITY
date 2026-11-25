# Supabase Edge Function: ingest-forecast

This function stores immutable weather/marine/tide/current snapshots. It does not expose the service-role key to the browser.

## Deploy
1. Install/use the Supabase CLI in a trusted development environment.
2. Link this repository to the Supabase project.
3. Set project secrets (the CLI reads these from the project):
   - SUPABASE_URL
   - SUPABASE_ANON_KEY
   - SUPABASE_SERVICE_ROLE_KEY
4. Deploy: `supabase functions deploy ingest-forecast`.

The function requires a valid signed-in user's bearer token, validates the incoming snapshot shape, and writes through the server-side service role. Do not disable JWT verification.

## Request
POST to `/functions/v1/ingest-forecast` with an Authorization bearer token and:
```json
{
  "snapshots": [{
    "spot_key": "sample-spot",
    "forecast_for": "2026-11-25T06:00:00+09:00",
    "data_kind": "weather",
    "provider": "open-meteo",
    "model_name": "forecast",
    "latitude": 34.0,
    "longitude": 133.0,
    "payload": { "wind_speed_10m": 4.2, "temperature_2m": 16.1 },
    "units": { "wind_speed_10m": "m/s", "temperature_2m": "°C" },
    "quality": { "coordinate_precision": "approximate" },
    "app_version": "1"
  }]
}
```

The function stamps retrieved_at on the server. Missing values should be omitted or null, never fabricated as zero. Only send forecast data that was actually returned by its provider.
