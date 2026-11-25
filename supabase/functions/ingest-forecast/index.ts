import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "POST required" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceKey) return json({ error: "Server configuration missing" }, 500);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return json({ error: "Authentication required" }, 401);

  const authClient = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: authData, error: authError } = await authClient.auth.getUser();
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  if (!body || !Array.isArray(body.snapshots) || body.snapshots.length > 100) {
    return json({ error: "snapshots must be an array with at most 100 items" }, 400);
  }

  const allowedKinds = new Set(["weather", "marine", "tide", "current", "baitfish", "manual_observation"]);
  const rows = [];
  for (const item of body.snapshots) {
    if (!item || typeof item.provider !== "string" || !allowedKinds.has(item.data_kind) ||
        typeof item.forecast_for !== "string" || !item.payload || typeof item.payload !== "object") {
      return json({ error: "Invalid snapshot item" }, 400);
    }
    rows.push({
      spot_key: typeof item.spot_key === "string" ? item.spot_key : null,
      forecast_for: item.forecast_for,
      retrieved_at: new Date().toISOString(),
      data_kind: item.data_kind,
      provider: item.provider,
      model_name: typeof item.model_name === "string" ? item.model_name : null,
      latitude: Number.isFinite(item.latitude) ? item.latitude : null,
      longitude: Number.isFinite(item.longitude) ? item.longitude : null,
      payload: item.payload,
      units: item.units && typeof item.units === "object" ? item.units : {},
      quality: item.quality && typeof item.quality === "object" ? item.quality : {},
      app_version: typeof item.app_version === "string" ? item.app_version : null,
    });
  }

  if (rows.length === 0) return json({ inserted: 0 });
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await admin.from("environment_snapshots").insert(rows).select("id");
  if (error) return json({ error: "Database insert failed", detail: error.message }, 500);
  return json({ inserted: data?.length ?? 0, ids: data?.map((x) => x.id) ?? [] });
});
