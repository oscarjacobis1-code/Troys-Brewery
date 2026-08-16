import { config, isConfigured } from './config.js';

const SESSION_KEY = 'troys_auth_session';

function headers(auth = true) {
  const session = getSession();
  return {
    apikey: config.supabaseAnonKey,
    Authorization: `Bearer ${auth && session?.access_token ? session.access_token : config.supabaseAnonKey}`,
    'Content-Type': 'application/json'
  };
}

async function request(path, options = {}) {
  if (!isConfigured()) throw new Error('Supabase is not configured.');
  const response = await fetch(`${config.supabaseUrl}${path}`, {
    ...options,
    headers: { ...headers(options.auth !== false), ...(options.headers || {}) }
  });
  const body = response.status === 204 ? null : await response.json().catch(() => null);
  if (!response.ok) throw new Error(body?.message || body?.error_description || body?.hint || `Request failed (${response.status})`);
  return body;
}

export function getSession() {
  try { return JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null'); } catch { return null; }
}

export function clearSession() {
  sessionStorage.removeItem(SESSION_KEY);
}

export async function signIn(email, password, deviceName) {
  const session = await request('/auth/v1/token?grant_type=password', {
    method: 'POST', auth: false, body: JSON.stringify({ email, password })
  });
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  await rpc('start_device_session', { p_store_id: config.storeId, p_device_name: deviceName || 'Unknown device' });
  return session;
}

export async function signOut() {
  try { await rpc('end_device_session', {}); } finally {
    await request('/auth/v1/logout', { method: 'POST' }).catch(() => undefined);
    clearSession();
  }
}

export async function rpc(name, params, { publicCall = false } = {}) {
  return request(`/rest/v1/rpc/${name}`, {
    method: 'POST', auth: !publicCall, body: JSON.stringify(params || {})
  });
}

export const api = Object.freeze({
  myAccess: () => rpc('get_my_access', { p_store_id: config.storeId }),
  menu: () => rpc('get_public_menu', { p_store_id: config.storeId }, { publicCall: true }),
  createOnlineOrder: payload => rpc('create_public_order', { p_store_id: config.storeId, p_payload: payload }, { publicCall: true }),
  trackOrder: token => rpc('get_public_order_status', { p_tracking_token: token }, { publicCall: true }),
  staffWorkspace: () => rpc('get_staff_workspace', { p_store_id: config.storeId }),
  createCounterOrder: payload => rpc('create_counter_order', { p_store_id: config.storeId, p_payload: payload }),
  transitionOrder: (orderId, nextStatus, note = null) => rpc('transition_order', { p_order_id: orderId, p_next_status: nextStatus, p_note: note }),
  assignDelivery: (orderId, driverId) => rpc('assign_delivery', { p_order_id: orderId, p_driver_id: driverId }),
  driverWorkspace: () => rpc('get_driver_workspace', { p_store_id: config.storeId }),
  adminDashboard: () => rpc('get_admin_dashboard', { p_store_id: config.storeId }),
  heartbeat: () => rpc('heartbeat_device_session', {})
});
