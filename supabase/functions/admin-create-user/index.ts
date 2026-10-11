import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ROLES = ["farmer", "technician", "supervisor", "admin"];
const FARMER_EMAIL_DOMAIN = "agricultores.agroapp";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing authorization" }, 401);

  // Identify the caller with their own JWT, then require the admin role.
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
    return json({ error: "Solo un administrador puede crear usuarios" }, 403);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }

  const password = String(body.password ?? "");
  const fullName = String(body.full_name ?? "").trim();
  const role = String(body.role ?? "");
  const dni = String(body.dni ?? "").trim();

  // Farmers sign in with their DNI; the login email is derived from it.
  let email = String(body.email ?? "").trim().toLowerCase();
  if (role === "farmer") {
    if (!/^[0-9]{8}$/.test(dni)) return json({ error: "El DNI debe tener 8 números" }, 400);
    email = `${dni}@${FARMER_EMAIL_DOMAIN}`;
  }

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return json({ error: "Correo inválido" }, 400);
  if (role !== "farmer" && email.endsWith(`@${FARMER_EMAIL_DOMAIN}`)) {
    return json({ error: "Ese dominio está reservado para agricultores" }, 400);
  }
  if (password.length < 8) return json({ error: "La contraseña debe tener al menos 8 caracteres" }, 400);
  if (!fullName) return json({ error: "El nombre es obligatorio" }, 400);
  if (!ROLES.includes(role)) return json({ error: "Rol inválido" }, 400);

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, role },
  });
  if (createError || !created.user) {
    return json({ error: createError?.message ?? "No se pudo crear el usuario" }, 400);
  }

  const { data: provisioned, error: rpcError } = await admin.rpc("admin_provision_user", {
    p_user_id: created.user.id,
    p_email: email,
    p_full_name: fullName,
    p_role: role,
    p_phone: body.phone ?? null,
    p_zone_ids: body.zone_ids ?? [],
    p_community_id: body.community_id ?? null,
    p_age_range: body.age_range ?? null,
    p_dni: role === "farmer" ? dni : null,
  });

  if (rpcError) {
    // Roll back the Auth user so no orphan account remains.
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: rpcError.message }, 400);
  }

  return json({ ok: true, ...provisioned }, 201);
});
