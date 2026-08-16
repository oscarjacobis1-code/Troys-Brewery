begin;
select plan(9);

select ok((select count(*) from pg_tables where schemaname='public' and rowsecurity is false and tablename not like 'pg_%')=0,'all public tables have RLS enabled');
select function_returns('public','create_public_order',array['uuid','jsonb'],'jsonb','public order creation returns safe JSON');
select function_returns('public','get_public_order_status',array['uuid'],'jsonb','public tracking returns safe JSON');
select ok(not has_function_privilege('anon','public.create_counter_order(uuid,jsonb)','execute'),'anonymous users cannot create counter orders');
select ok(not has_function_privilege('anon','public.get_admin_dashboard(uuid)','execute'),'anonymous users cannot read admin reporting');
select ok(not has_function_privilege('anon','public.transition_order(uuid,text,text)','execute'),'anonymous users cannot transition orders');
select ok(not has_function_privilege('anon','public.assign_delivery(uuid,uuid)','execute'),'anonymous users cannot assign drivers');
select ok(not has_function_privilege('authenticated','app.build_order(uuid,text,jsonb,uuid)','execute'),'clients cannot call the internal pricing function');
select ok(not has_function_privilege('authenticated','app.consume_stock(uuid,uuid)','execute'),'clients cannot call the internal stock function');

select * from finish();
rollback;
