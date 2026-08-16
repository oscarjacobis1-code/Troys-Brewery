import { readFile, readdir, stat } from 'node:fs/promises';
import { resolve, relative, dirname } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const failures = [];
const required = ['README.md','package.json','public/index.html','public/order.html','public/login.html','public/staff.html','public/delivery.html','public/admin.html','public/js/api.js','supabase/migrations/001_initial.sql','docs/ACCEPTANCE.md','.github/workflows/quality-gate.yml'];

async function filesBelow(directory) {
  const output = [];
  for (const entry of await readdir(directory)) {
    const path = resolve(directory, entry);
    if ((await stat(path)).isDirectory()) output.push(...await filesBelow(path)); else output.push(path);
  }
  return output;
}

for (const file of required) {
  try { await stat(resolve(root,file)); } catch { failures.push(`Missing required file: ${file}`); }
}

const sourceFiles = (await filesBelow(root)).filter(path => !path.includes('/.git/') && !path.includes('/node_modules/'));
for (const path of sourceFiles) {
  const content = await readFile(path,'utf8').catch(()=>'');
  const name = relative(root,path);
  if (name === 'scripts/check-project.mjs') continue;
  if (/SUPABASE_SERVICE_ROLE_KEY|serviceRoleKey/.test(content)) failures.push(`Service-role credential variable is forbidden in ${name}`);
  if (/sk_live_|ghp_|AKIA[0-9A-Z]{16}|eyJ[a-zA-Z0-9_-]{20,}\.[a-zA-Z0-9_-]{20,}/.test(content)) failures.push(`Possible committed secret in ${name}`);
  if (/localStorage\s*\./.test(content)) failures.push(`Business data must not use localStorage: ${name}`);
  if (/brewery2026|troy2026|Demo:\s*<strong>/.test(content)) failures.push(`Hard-coded demo credentials in ${name}`);
}

for (const htmlPath of sourceFiles.filter(path=>path.endsWith('.html'))) {
  const html = await readFile(htmlPath,'utf8');
  for (const match of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
    const link = match[1];
    if (/^(https?:|#|mailto:|tel:)/.test(link) || link.includes('{{')) continue;
    const clean = link.split('#')[0].split('?')[0];
    if (!clean) continue;
    try { await stat(resolve(dirname(htmlPath),clean)); } catch { failures.push(`Broken local reference in ${relative(root,htmlPath)}: ${link}`); }
  }
}

const sql = await readFile(resolve(root,'supabase/migrations/001_initial.sql'),'utf8');
const tables = [...sql.matchAll(/create table public\.([a-z_]+)/g)].map(match=>match[1]);
for (const table of tables) if (!new RegExp(`alter table ${table} enable row level security`,'i').test(sql)) failures.push(`RLS not enabled for ${table}`);
for (const match of sql.matchAll(/security definer([\s\S]*?)\$\$/gi)) if (!/set search_path\s*=/.test(match[1])) failures.push('SECURITY DEFINER function missing fixed search_path');
for (const requiredSql of ['app.consume_stock','idempotency_key','create_public_order','create_counter_order','transition_order','assign_delivery','get_admin_dashboard','revoke execute on all functions in schema public']) if (!sql.includes(requiredSql)) failures.push(`Missing database control: ${requiredSql}`);

if (failures.length) {
  console.error(`Quality gate failed with ${failures.length} issue(s):\n- ${failures.join('\n- ')}`);
  process.exit(1);
}
console.log(`Quality gate passed: ${sourceFiles.length} files, ${tables.length} RLS tables.`);
