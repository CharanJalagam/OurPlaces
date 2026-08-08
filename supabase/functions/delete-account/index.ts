// delete-account — permanently deletes the calling user's account + data.
//
// The app calls this via `supabase.functions.invoke("delete-account")`, which
// sends the user's JWT. We identify the caller from that token, then use the
// service-role key (auto-injected into Edge Functions) to delete their data and
// finally the auth user itself. A client can never delete an auth user directly,
// which is why this must run server-side.
//
// Deploy:  supabase functions deploy delete-account
// (No manual secrets needed — SUPABASE_URL / SUPABASE_ANON_KEY /
//  SUPABASE_SERVICE_ROLE_KEY are provided by the platform.)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Identify the caller from their JWT.
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userErr } = await userClient.auth.getUser();
    if (userErr || !user) return json({ error: "Invalid or expired session" }, 401);

    const uid = user.id;

    // Service-role client for the actual deletion.
    const admin = createClient(supabaseUrl, serviceKey);

    // 1) Best-effort storage cleanup (user files live under a `{uid}/` prefix).
    for (const bucket of ["visit-images", "userProfiles"]) {
      try {
        const { data: files } = await admin.storage.from(bucket).list(uid);
        if (files && files.length) {
          await admin.storage
            .from(bucket)
            .remove(files.map((f) => `${uid}/${f.name}`));
        }
      } catch (_) {
        // Non-fatal — keep going so the account still gets deleted.
      }
    }

    // 2) Delete the user's rows (children first for FK safety).
    await admin.from("visit_images").delete().eq("user_id", uid);
    await admin.from("visits").delete().eq("user_id", uid);
    await admin.from("places").delete().eq("user_id", uid); // private places only
    await admin.from("users").delete().eq("id", uid);

    // 3) Delete the auth user.
    const { error: delErr } = await admin.auth.admin.deleteUser(uid);
    if (delErr) return json({ error: delErr.message }, 500);

    return json({ success: true }, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
