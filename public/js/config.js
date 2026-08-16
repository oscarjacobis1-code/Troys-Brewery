const raw = window.__TROYS_CONFIG__ || {};

export const config = Object.freeze({
  supabaseUrl: String(raw.supabaseUrl || '').replace(/\/$/, ''),
  supabaseAnonKey: String(raw.supabaseAnonKey || ''),
  storeId: String(raw.storeId || ''),
  storeTimeZone: String(raw.storeTimeZone || 'America/Guyana'),
  currency: String(raw.currency || 'GYD')
});

export function isConfigured() {
  return /^https:\/\/.+\.supabase\.co$/.test(config.supabaseUrl)
    && config.supabaseAnonKey.length > 40
    && /^[0-9a-f-]{36}$/i.test(config.storeId)
    && config.storeId !== '00000000-0000-0000-0000-000000000000';
}
