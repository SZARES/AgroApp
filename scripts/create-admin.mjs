#!/usr/bin/env node
// Creates (or provisions) an admin user for AgroApp.
//
// Usage (PowerShell):
//   $env:SUPABASE_SERVICE_ROLE_KEY = "<service_role key from Supabase Dashboard > Settings > API Keys>"
//   node scripts/create-admin.mjs --email admin@aider.org --name "Admin AIDER"
//
// The password is asked on the terminal (hidden). Never commit the service_role key.
// Optional: SUPABASE_URL (defaults to the project below), --phone 999999999.

import { createInterface } from "node:readline";
import { Writable } from "node:stream";

const url = (process.env.SUPABASE_URL ?? "https://odttcsahrucsohtbqbro.supabase.co").replace(/\/$/, "");
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : undefined;
}

function askHidden(question) {
  return new Promise((resolve) => {
    let muted = false;
    const output = new Writable({
      write(chunk, _enc, cb) {
        if (!muted) process.stdout.write(chunk);
        cb();
      },
    });
    const rl = createInterface({ input: process.stdin, output, terminal: true });
    rl.question(question, (answer) => {
      rl.close();
      process.stdout.write("\n");
      resolve(answer);
    });
    muted = true;
  });
}

function fail(message) {
  console.error(`\n✗ ${message}`);
  process.exit(1);
}

if (!serviceKey) fail("Falta la variable SUPABASE_SERVICE_ROLE_KEY (ver instrucciones al inicio del script).");

const email = (arg("email") ?? "").trim().toLowerCase();
const fullName = (arg("name") ?? "").trim();
const phone = arg("phone") ?? null;

if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) fail("Indique un correo válido con --email.");
if (email.endsWith("@agricultores.agroapp")) fail("Ese dominio está reservado para agricultores.");
if (!fullName) fail('Indique el nombre con --name "Nombre Apellido".');

const password = process.env.ADMIN_PASSWORD ?? (await askHidden("Contraseña (mínimo 8 caracteres): "));
if (password.length < 8) fail("La contraseña debe tener al menos 8 caracteres.");
if (!process.env.ADMIN_PASSWORD) {
  const again = await askHidden("Repita la contraseña: ");
  if (again !== password) fail("Las contraseñas no coinciden.");
}

const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  "Content-Type": "application/json",
};

// 1) Auth user (email already confirmed).
const created = await fetch(`${url}/auth/v1/admin/users`, {
  method: "POST",
  headers,
  body: JSON.stringify({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, role: "admin" },
  }),
});
const createdBody = await created.json().catch(() => ({}));
if (!created.ok) fail(createdBody.msg ?? createdBody.message ?? `No se pudo crear el usuario (HTTP ${created.status}).`);
const userId = createdBody.id;

// 2) Profile row through the same RPC the admin Edge Function uses.
const provisioned = await fetch(`${url}/rest/v1/rpc/admin_provision_user`, {
  method: "POST",
  headers,
  body: JSON.stringify({
    p_user_id: userId,
    p_email: email,
    p_full_name: fullName,
    p_role: "admin",
    p_phone: phone,
    p_zone_ids: [],
    p_community_id: null,
    p_age_range: null,
    p_dni: null,
  }),
});

if (!provisioned.ok) {
  const detail = await provisioned.json().catch(() => ({}));
  // Roll back the Auth user so no orphan account remains.
  await fetch(`${url}/auth/v1/admin/users/${userId}`, { method: "DELETE", headers });
  fail(detail.message ?? `No se pudo crear el perfil (HTTP ${provisioned.status}). Se deshizo el usuario de Auth.`);
}

console.log(`\n✓ Admin creado: ${email}`);
console.log("  Ya puede entrar en la app escribiendo ese correo y su contraseña.");
