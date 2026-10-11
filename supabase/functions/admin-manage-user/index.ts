import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const STATUSES = ["active", "inactive", "suspended"];

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Admin-only user management that needs service-role privileges:
//   { user_id, action: "reset_password", password }
//   { user_id, action: "set_status", status: "active" | "inactive" | "suspended" }
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing authorization" }, 401);

  const caller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
  const { data: callerData, error: callerError } = await caller.auth.getUser();
  if (callerError || !callerData.user) return json({ error: "Invalid session" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const { data: callerProfile } = await admin
    .from("profiles")
    .select("role,status")
    .eq("id", callerData.user.id)
    .maybeSingle();
  if (callerProfile?.role !== "admin" || callerProfile?.status !== "active") {
    return json({ error: "Solo un administrador puede gestionar usuarios" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }

  const userId = String(body.user_id ?? "");
  const action = String(body.action ?? "");
  if (!/^[0-9a-f-]{36}$/i.test(userId)) return json({ error: "Usuario inválido" }, 400);

  const { data: target } = await admin.from("profiles").select("id,role").eq("id", userId).maybeSingle();
  if (!target) return json({ error: "El usuario no existe" }, 404);

  if (action === "reset_password") {
    const password = String(body.password ?? "");
    if (password.length < 8) return json({ error: "La contraseña debe tener al menos 8 caracteres" }, 400);
    const { error } = await admin.auth.admin.updateUserById(userId, { password });
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  if (action === "set_status") {
    const status = String(body.status ?? "");
    if (!STATUSES.includes(status)) return json({ error: "Estado inválido" }, 400);
    if (userId === callerData.user.id && status !== "active") {
      return json({ error: "No puede desactivar su propia cuenta" }, 400);
    }
    const { error: profileError } = await admin.from("profiles").update({ status }).eq("id", userId);
    if (profileError) return json({ error: profileError.message }, 400);
    // Block (or unblock) sign-in at the Auth level too, not only in the app.
    const { error: banError } = await admin.auth.admin.updateUserById(userId, {
      ban_duration: status === "active" ? "none" : "876000h",
    });
    if (banError) return json({ error: banError.message }, 400);
    return json({ ok: true, status });
  }

  return json({ error: "Acción inválida" }, 400);
});
