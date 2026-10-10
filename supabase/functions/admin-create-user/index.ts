// admin-create-user
//
// Creates a user of any role on behalf of a signed-in admin.
// The secret key never leaves this function: the caller only sends its own
// access token, and authorization is decided from `public.profiles`.
//
// Flow: authenticate caller -> require active admin profile -> validate body
// -> create the Auth user -> provision profile and role data through the
// `admin_provision_user` RPC -> delete the Auth user again if the RPC fails.

import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const ROLES = ["farmer", "technician", "supervisor", "admin"] as const;
type Role = (typeof ROLES)[number];

const AGE_RANGES = ["18-29", "30-39", "40-49", "50-59", "60-69", "70+"];
const ZONE_ROLES: Role[] = ["technician", "supervisor"];
const MIN_PASSWORD_LENGTH = 8;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

interface NewUserInput {
  email: string;
  password: string;
  fullName: string;
  role: Role;
  phone: string | null;
  zoneIds: string[];
  communityId: string | null;
  ageRange: string | null;
}

type ValidationResult =
  | { ok: true; value: NewUserInput }
  | { ok: false; error: string; field: string };

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function invalid(field: string, error: string): ValidationResult {
  return { ok: false, error, field };
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isAbsent(value: unknown): boolean {
  return value === undefined || value === null;
}

/** Resolves the server-side secret key, preferring the new key format. */
function resolveSecretKey(): string | null {
  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (secretKeys) {
    try {
      const parsed = JSON.parse(secretKeys);
      if (typeof parsed?.default === "string" && parsed.default) {
        return parsed.default;
      }
    } catch {
      // Fall through to the legacy variable.
    }
  }
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? null;
}

function readBearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

function validateBody(body: unknown): ValidationResult {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return invalid("body", "Request body must be a JSON object");
  }
  const input = body as Record<string, unknown>;

  const email = typeof input.email === "string"
    ? input.email.trim().toLowerCase()
    : "";
  if (!EMAIL_PATTERN.test(email)) {
    return invalid("email", "A valid email is required");
  }

  const password = input.password;
  if (typeof password !== "string" || password.length < MIN_PASSWORD_LENGTH) {
    return invalid(
      "password",
      `Password must be at least ${MIN_PASSWORD_LENGTH} characters`,
    );
  }

  const fullName = typeof input.full_name === "string"
    ? input.full_name.trim()
    : "";
  if (!fullName) {
    return invalid("full_name", "Full name is required");
  }

  if (!ROLES.includes(input.role as Role)) {
    return invalid("role", `Role must be one of: ${ROLES.join(", ")}`);
  }
  const role = input.role as Role;

  let phone: string | null = null;
  if (!isAbsent(input.phone)) {
    if (typeof input.phone !== "string") {
      return invalid("phone", "Phone must be a string");
    }
    phone = input.phone.trim() || null;
  }

  let zoneIds: string[] = [];
  if (!isAbsent(input.zone_ids)) {
    if (!Array.isArray(input.zone_ids) || !input.zone_ids.every(isUuid)) {
      return invalid("zone_ids", "Zone ids must be an array of UUIDs");
    }
    // Zones only apply to technicians and supervisors.
    if (ZONE_ROLES.includes(role)) {
      zoneIds = [...new Set(input.zone_ids as string[])];
    }
  }

  let communityId: string | null = null;
  if (!isAbsent(input.community_id)) {
    if (!isUuid(input.community_id)) {
      return invalid("community_id", "Community id must be a UUID");
    }
    communityId = input.community_id;
  }

  let ageRange: string | null = null;
  if (!isAbsent(input.age_range)) {
    if (
      typeof input.age_range !== "string" ||
      !AGE_RANGES.includes(input.age_range)
    ) {
      return invalid(
        "age_range",
        `Age range must be one of: ${AGE_RANGES.join(", ")}`,
      );
    }
    ageRange = input.age_range;
  }

  return {
    ok: true,
    value: {
      email,
      password,
      fullName,
      role,
      phone,
      zoneIds,
      communityId,
      ageRange,
    },
  };
}

/** Returns true when the caller has an active, non-deleted admin profile. */
async function isActiveAdmin(
  admin: SupabaseClient,
  userId: string,
): Promise<boolean> {
  const { data, error } = await admin
    .from("profiles")
    .select("role, status, deleted_at")
    .eq("id", userId)
    .maybeSingle();

  if (error) {
    console.error("admin-create-user: profile lookup failed", error.message);
    return false;
  }
  return data?.role === "admin" && data.status === "active" &&
    data.deleted_at === null;
}

function isEmailTaken(error: { code?: string; message?: string }): boolean {
  return error.code === "email_exists" ||
    /already (been )?registered/i.test(error.message ?? "");
}

/** Maps a Postgres error code raised by the provisioning RPC to a response. */
function provisioningErrorResponse(code: string | undefined): Response {
  switch (code) {
    case "23505":
      return json({ error: "A user with this phone or id already exists" }, 409);
    case "23503":
    case "23514":
    case "22P02":
      return json({ error: "Invalid reference or value in user data" }, 400);
    case "42501":
      return json({ error: "Only an active admin can create users" }, 403);
    default:
      return json({ error: "Could not create the user profile" }, 500);
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKey = resolveSecretKey();
  if (!supabaseUrl || !secretKey) {
    console.error("admin-create-user: missing server configuration");
    return json({ error: "Server configuration error" }, 500);
  }

  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Authentication: the caller must present a valid access token.
  const token = readBearerToken(req);
  if (!token) {
    return json({ error: "Missing bearer token" }, 401);
  }
  const { data: callerData, error: callerError } = await admin.auth.getUser(
    token,
  );
  const caller = callerData?.user;
  if (callerError || !caller) {
    return json({ error: "Invalid or expired token" }, 401);
  }

  // Authorization: decided from public.profiles, never from user_metadata.
  if (!(await isActiveAdmin(admin, caller.id))) {
    return json({ error: "Only an active admin can create users" }, 403);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON body", field: "body" }, 400);
  }

  const validation = validateBody(body);
  if (!validation.ok) {
    return json({ error: validation.error, field: validation.field }, 400);
  }
  const input = validation.value;

  // The role lives in public.profiles only; nothing goes into user_metadata.
  const { data: created, error: createError } = await admin.auth.admin
    .createUser({
      email: input.email,
      password: input.password,
      email_confirm: true,
    });
  if (createError || !created?.user) {
    if (createError && isEmailTaken(createError)) {
      return json({ error: "A user with this email already exists" }, 409);
    }
    return json(
      { error: createError?.message ?? "Could not create the user" },
      400,
    );
  }
  const newUserId = created.user.id;

  const { error: rpcError } = await admin.rpc("admin_provision_user", {
    p_actor_id: caller.id,
    p_user_id: newUserId,
    p_full_name: input.fullName,
    p_email: input.email,
    p_phone: input.phone,
    p_role: input.role,
    p_zone_ids: input.zoneIds,
    p_community_id: input.communityId,
    p_age_range: input.ageRange,
  });

  if (rpcError) {
    console.error(
      "admin-create-user: provisioning failed",
      rpcError.code,
      rpcError.message,
    );
    // Roll back the Auth user so no account is left without a profile.
    const { error: cleanupError } = await admin.auth.admin.deleteUser(
      newUserId,
    );
    if (cleanupError) {
      console.error(
        "admin-create-user: orphaned auth user, cleanup failed",
        newUserId,
        cleanupError.message,
      );
    }
    return provisioningErrorResponse(rpcError.code);
  }

  return json(
    {
      id: newUserId,
      email: input.email,
      role: input.role,
      full_name: input.fullName,
    },
    201,
  );
});
