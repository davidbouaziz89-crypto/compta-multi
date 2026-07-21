// Edge function : création d'un utilisateur (secrétaire / comptable / admin)
// Réservée aux administrateurs. Crée l'auth user + le profil + les accès sociétés.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

    // 1) Vérifie que l'appelant est admin
    const authHeader = req.headers.get("Authorization") || "";
    const asCaller = createClient(url, anonKey, { global: { headers: { Authorization: authHeader } } });
    const { data: { user }, error: uErr } = await asCaller.auth.getUser();
    if (uErr || !user) return json({ error: "Non authentifié" }, 401);
    const admin = createClient(url, serviceKey);
    const { data: prof } = await admin.from("app_users").select("is_admin").eq("user_id", user.id).maybeSingle();
    if (!prof || !prof.is_admin) return json({ error: "Réservé aux administrateurs" }, 403);

    // 2) Payload
    const { email, password, is_admin = false, access = [] } = await req.json();
    if (!email || !password || password.length < 6) return json({ error: "Email + mot de passe (min. 6) requis" }, 400);

    // 3) Crée l'utilisateur
    const { data: created, error: cErr } = await admin.auth.admin.createUser({
      email, password, email_confirm: true,
    });
    if (cErr) return json({ error: cErr.message }, 400);
    const newId = created.user.id;

    // 4) Profil (le trigger l'a créé ; on force is_admin si demandé)
    await admin.from("app_users").upsert({ user_id: newId, email, is_admin: !!is_admin });

    // 5) Accès sociétés
    if (Array.isArray(access) && access.length) {
      const rows = access
        .filter((a: any) => a && a.company_id && a.role)
        .map((a: any) => ({ company_id: a.company_id, user_id: newId, role: a.role }));
      if (rows.length) {
        const { error: aErr } = await admin.from("company_access").insert(rows);
        if (aErr) return json({ error: "Utilisateur créé mais accès non posés : " + aErr.message }, 207);
      }
    }
    return json({ ok: true, user_id: newId });
  } catch (e) {
    return json({ error: String(e?.message || e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
