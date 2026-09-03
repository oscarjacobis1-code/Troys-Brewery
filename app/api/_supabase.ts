const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

export async function supabaseRequest<T>(path: string, init?: RequestInit): Promise<T> {
  if (!url || !key) throw new Error("The live order service is not configured.");
  const response = await fetch(`${url}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: key,
      Authorization: `Bearer ${key}`,
      "Content-Type": "application/json",
      ...(init?.headers || {}),
    },
  });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.message || body.error_description || "The database request failed.");
  }
  return response.json() as Promise<T>;
}

export function apiError(error: unknown) {
  const message = error instanceof Error ? error.message : "The live service is temporarily unavailable.";
  return Response.json({ message }, { status: 502 });
}
