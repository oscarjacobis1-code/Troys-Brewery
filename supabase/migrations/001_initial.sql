begin;

create extension if not exists pgcrypto;
create schema if not exists app;
revoke all on schema app from public, anon, authenticated;

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  timezone text not null default 'America/Guyana',
  currency text not null default 'GYD',
  delivery_fee integer not null default 0 check(delivery_fee>=0),
  minimum_delivery_subtotal integer not null default 0 check(minimum_delivery_subtotal>=0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  phone text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.store_memberships (
  store_id uuid not null references public.stores(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','manager','cashier','barista','dispatcher','driver')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (store_id,user_id)
);

create or replace function app.has_store_role(p_store_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select exists(select 1 from public.store_memberships m where m.store_id=p_store_id and m.user_id=auth.uid() and m.active and m.role=any(p_roles));
$$;

create table public.device_sessions (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id),
  user_id uuid not null references auth.users(id), device_name text not null check(length(device_name) between 2 and 80),
  logged_in_at timestamptz not null default now(), last_seen_at timestamptz not null default now(), logged_out_at timestamptz
);
create unique index one_open_device_session on public.device_sessions(user_id) where logged_out_at is null;

create table public.menu_categories (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id) on delete cascade,
  name text not null, sort_order integer not null default 0, active boolean not null default true
);
create table public.menu_items (
  id uuid primary key default gen_random_uuid(), category_id uuid not null references public.menu_categories(id) on delete cascade,
  name text not null, description text not null default '', active boolean not null default true, sort_order integer not null default 0
);
create table public.item_variants (
  id uuid primary key default gen_random_uuid(), item_id uuid not null references public.menu_items(id) on delete cascade,
  name text not null, price integer not null check(price>=0), active boolean not null default true, is_default boolean not null default false
);
create unique index one_default_variant_per_item on public.item_variants(item_id) where is_default;
create table public.modifier_options (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id) on delete cascade,
  name text not null, price integer not null default 0 check(price>=0), active boolean not null default true
);
create table public.variant_modifier_options (
  variant_id uuid not null references public.item_variants(id) on delete cascade,
  modifier_option_id uuid not null references public.modifier_options(id) on delete cascade,
  primary key(variant_id,modifier_option_id)
);

create table public.inventory_items (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id) on delete cascade,
  name text not null, unit text not null, on_hand numeric(14,3) not null default 0 check(on_hand>=0),
  reorder_level numeric(14,3) not null default 0 check(reorder_level>=0), active boolean not null default true,
  unique(store_id,name)
);
create table public.variant_recipes (
  variant_id uuid not null references public.item_variants(id) on delete cascade,
  inventory_item_id uuid not null references public.inventory_items(id), quantity numeric(14,3) not null check(quantity>0),
  primary key(variant_id,inventory_item_id)
);
create table public.stock_movements (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id),
  inventory_item_id uuid not null references public.inventory_items(id), quantity_delta numeric(14,3) not null check(quantity_delta<>0),
  reason text not null check(reason in ('sale','refund','restock','waste','count_adjustment','staff_use')),
  order_id uuid, actor_id uuid references auth.users(id), note text, created_at timestamptz not null default now()
);

create sequence public.order_number_seq;
create table public.orders (
  id uuid primary key default gen_random_uuid(), store_id uuid not null references public.stores(id),
  idempotency_key uuid not null,
  order_number text not null unique default ('TB-'||to_char(now(),'YYMMDD')||'-'||lpad(nextval('public.order_number_seq')::text,5,'0')),
  tracking_token uuid not null unique default gen_random_uuid(), source text not null check(source in ('online','counter')),
  fulfilment text not null check(fulfilment in ('pickup','delivery','dine_in')),
  status text not null default 'pending_payment' check(status in ('pending_payment','confirmed','accepted','preparing','ready_for_pickup','awaiting_driver','picked_up','out_for_delivery','collected','delivered','cancelled','refunded','failed_delivery')),
  payment_status text not null default 'unpaid' check(payment_status in ('unpaid','pending','paid','partially_refunded','refunded','failed')),
  customer_name text not null, customer_phone text, delivery_address text, notes text check(length(notes)<=500),
  subtotal integer not null check(subtotal>=0), delivery_fee integer not null default 0 check(delivery_fee>=0), total integer not null check(total>=0),
  requested_for timestamptz, created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index unique_order_request on public.orders(store_id,idempotency_key);
alter table public.stock_movements add constraint stock_order_fk foreign key(order_id) references public.orders(id);
create table public.order_items (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id) on delete cascade,
  variant_id uuid not null references public.item_variants(id), item_name text not null, variant_name text not null,
  quantity integer not null check(quantity between 1 and 100), unit_price integer not null check(unit_price>=0), line_total integer not null check(line_total>=0)
);
create table public.order_item_modifiers (
  order_item_id uuid not null references public.order_items(id) on delete cascade,
  modifier_option_id uuid not null references public.modifier_options(id), name text not null, unit_price integer not null check(unit_price>=0),
  primary key(order_item_id,modifier_option_id)
);
create table public.payments (
  id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
  method text not null check(method in ('cash','mmg','card')), status text not null check(status in ('pending','paid','failed','refunded')),
  amount integer not null check(amount>0), provider_reference text, received_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create unique index unique_provider_payment_reference on public.payments(method,provider_reference) where provider_reference is not null;
create table public.order_status_history (
  id bigint generated always as identity primary key, order_id uuid not null references public.orders(id) on delete cascade,
  from_status text, to_status text not null, actor_id uuid references auth.users(id), note text, created_at timestamptz not null default now()
);
create table public.deliveries (
  id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id) on delete cascade,
  store_id uuid not null references public.stores(id), driver_id uuid references auth.users(id), assigned_by uuid references auth.users(id),
  assigned_at timestamptz, proof_note text, delivered_at timestamptz
);
create table public.audit_log (
  id bigint generated always as identity primary key, store_id uuid references public.stores(id), actor_id uuid references auth.users(id),
  action text not null, entity_type text not null, entity_id text not null, details jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);

create or replace function app.build_order(p_store_id uuid,p_source text,p_payload jsonb,p_created_by uuid)
returns public.orders language plpgsql security definer set search_path=public,app,pg_temp as $$
declare v_order public.orders; v_subtotal integer:=0; v_line integer; v_item jsonb; v_variant record; v_modifier_total integer; v_order_item_id uuid; v_fulfilment text:=p_payload->>'fulfilment'; v_delivery_fee integer:=0; v_minimum integer:=0;
begin
  if not exists(select 1 from stores where id=p_store_id and active) then raise exception 'Store is unavailable'; end if;
  if v_fulfilment not in ('pickup','delivery','dine_in') then raise exception 'Invalid fulfilment'; end if;
  if v_fulfilment='delivery' and nullif(trim(p_payload->>'address'),'') is null then raise exception 'Delivery address required'; end if;
  if jsonb_array_length(coalesce(p_payload->'items','[]'::jsonb))=0 then raise exception 'Order requires at least one item'; end if;
  if nullif(p_payload->>'idempotency_key','') is null then raise exception 'Idempotency key required'; end if;
  insert into orders(store_id,idempotency_key,source,fulfilment,customer_name,customer_phone,delivery_address,notes,subtotal,total,requested_for,created_by)
  values(p_store_id,(p_payload->>'idempotency_key')::uuid,p_source,v_fulfilment,coalesce(nullif(trim(p_payload#>>'{customer,name}'),''),'Guest'),nullif(trim(p_payload#>>'{customer,phone}'),''),nullif(trim(p_payload->>'address'),''),nullif(trim(p_payload->>'notes'),''),0,0,nullif(p_payload->>'requested_for','')::timestamptz,p_created_by) returning * into v_order;
  for v_item in select * from jsonb_array_elements(p_payload->'items') loop
    select v.id,v.price,v.name variant_name,i.name item_name into v_variant from item_variants v join menu_items i on i.id=v.item_id join menu_categories c on c.id=i.category_id where v.id=(v_item->>'variant_id')::uuid and v.active and i.active and c.active and c.store_id=p_store_id;
    if not found then raise exception 'Unavailable menu item'; end if;
    if coalesce((v_item->>'quantity')::integer,0) not between 1 and 100 then raise exception 'Invalid item quantity'; end if;
    if exists(select 1 from jsonb_array_elements_text(coalesce(v_item->'modifier_option_ids','[]'::jsonb)) selected where not exists(select 1 from variant_modifier_options allowed join modifier_options m on m.id=allowed.modifier_option_id where allowed.variant_id=v_variant.id and allowed.modifier_option_id=selected.value::uuid and m.store_id=p_store_id and m.active)) then raise exception 'Invalid modifier selection'; end if;
    select coalesce(sum(m.price),0) into v_modifier_total from modifier_options m join variant_modifier_options allowed on allowed.modifier_option_id=m.id where allowed.variant_id=v_variant.id and m.id in (select value::uuid from jsonb_array_elements_text(coalesce(v_item->'modifier_option_ids','[]'::jsonb))) and m.store_id=p_store_id and m.active;
    v_line:=(v_variant.price+v_modifier_total)*(v_item->>'quantity')::integer; v_subtotal:=v_subtotal+v_line;
    insert into order_items(order_id,variant_id,item_name,variant_name,quantity,unit_price,line_total) values(v_order.id,v_variant.id,v_variant.item_name,v_variant.variant_name,(v_item->>'quantity')::integer,v_variant.price,v_line) returning id into v_order_item_id;
    insert into order_item_modifiers(order_item_id,modifier_option_id,name,unit_price) select v_order_item_id,m.id,m.name,m.price from modifier_options m join variant_modifier_options allowed on allowed.modifier_option_id=m.id where allowed.variant_id=v_variant.id and m.id in (select value::uuid from jsonb_array_elements_text(coalesce(v_item->'modifier_option_ids','[]'::jsonb))) and m.store_id=p_store_id and m.active;
  end loop;
  if v_fulfilment='delivery' then select delivery_fee,minimum_delivery_subtotal into v_delivery_fee,v_minimum from stores where id=p_store_id; if v_subtotal<v_minimum then raise exception 'Delivery minimum is %',v_minimum; end if; end if;
  update orders set subtotal=v_subtotal,delivery_fee=v_delivery_fee,total=v_subtotal+v_delivery_fee,updated_at=now() where id=v_order.id returning * into v_order;
  insert into order_status_history(order_id,to_status,actor_id) values(v_order.id,'pending_payment',p_created_by);
  return v_order;
end $$;
revoke all on function app.build_order(uuid,text,jsonb,uuid) from public,anon,authenticated;

create or replace function app.consume_stock(p_order_id uuid,p_actor uuid)
returns void language plpgsql security definer set search_path=public,app,pg_temp as $$
declare r record; v_on_hand numeric(14,3);
begin
  for r in select i.id,i.store_id,sum(vr.quantity*oi.quantity) required from order_items oi join variant_recipes vr on vr.variant_id=oi.variant_id join inventory_items i on i.id=vr.inventory_item_id where oi.order_id=p_order_id group by i.id,i.store_id order by i.id loop
    select on_hand into v_on_hand from inventory_items where id=r.id for update;
    if v_on_hand<r.required then raise exception 'Insufficient stock for %',r.id; end if;
    update inventory_items set on_hand=on_hand-r.required where id=r.id;
    insert into stock_movements(store_id,inventory_item_id,quantity_delta,reason,order_id,actor_id) values(r.store_id,r.id,-r.required,'sale',p_order_id,p_actor);
  end loop;
end $$;
revoke all on function app.consume_stock(uuid,uuid) from public,anon,authenticated;

create or replace function public.get_public_menu(p_store_id uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
select jsonb_build_object('items',coalesce(jsonb_agg(jsonb_build_object('name',i.name,'description',i.description,'category_name',c.name,'default_variant_id',v.id,'from_price',v.price) order by c.sort_order,i.sort_order),'[]'::jsonb)) from menu_categories c join menu_items i on i.category_id=c.id join item_variants v on v.item_id=i.id and v.is_default and v.active where c.store_id=p_store_id and c.active and i.active;
$$;

create or replace function public.create_public_order(p_store_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,app,pg_temp as $$ declare o orders; begin select * into o from orders where store_id=p_store_id and idempotency_key=(p_payload->>'idempotency_key')::uuid; if not found then o:=app.build_order(p_store_id,'online',p_payload,null); end if; return jsonb_build_object('order_number',o.order_number,'tracking_token',o.tracking_token,'total',o.total,'status',o.status); end $$;
create or replace function public.get_public_order_status(p_tracking_token uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$ select jsonb_build_object('order_number',order_number,'status',status,'payment_status',payment_status,'requested_for',requested_for,'updated_at',updated_at) from orders where tracking_token=p_tracking_token $$;

create or replace function public.create_counter_order(p_store_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,app,pg_temp as $$
declare o orders; v_method text:=p_payload->>'payment_method'; begin
  if not app.has_store_role(p_store_id,array['owner','admin','manager','cashier']) then raise exception 'Not authorised'; end if;
  if v_method not in ('cash','mmg','card') then raise exception 'Invalid payment method'; end if;
  select * into o from orders where store_id=p_store_id and idempotency_key=(p_payload->>'idempotency_key')::uuid;
  if found then return jsonb_build_object('id',o.id,'order_number',o.order_number,'total',o.total,'status',o.status); end if;
  if v_method in ('mmg','card') and nullif(trim(p_payload->>'provider_reference'),'') is null then raise exception 'Payment reference required'; end if;
  o:=app.build_order(p_store_id,'counter',p_payload,auth.uid());
  perform app.consume_stock(o.id,auth.uid());
  insert into payments(order_id,method,status,amount,provider_reference,received_by) values(o.id,v_method,'paid',o.total,nullif(p_payload->>'provider_reference',''),auth.uid());
  update orders set payment_status='paid',status='confirmed',updated_at=now() where id=o.id returning * into o;
  insert into order_status_history(order_id,from_status,to_status,actor_id) values(o.id,'pending_payment','confirmed',auth.uid());
  insert into audit_log(store_id,actor_id,action,entity_type,entity_id,details) values(p_store_id,auth.uid(),'counter_payment_confirmed','order',o.id::text,jsonb_build_object('amount',o.total,'method',v_method));
  return jsonb_build_object('id',o.id,'order_number',o.order_number,'total',o.total,'status',o.status);
end $$;

create or replace function public.assign_delivery(p_order_id uuid,p_driver_id uuid) returns void language plpgsql security definer set search_path=public,app,pg_temp as $$
declare o orders;
begin
  select * into o from orders where id=p_order_id for update;
  if not found or o.status<>'awaiting_driver' or o.fulfilment<>'delivery' then raise exception 'Order is not ready for driver assignment'; end if;
  if not app.has_store_role(o.store_id,array['owner','admin','manager','dispatcher']) then raise exception 'Not authorised'; end if;
  if not exists(select 1 from store_memberships where store_id=o.store_id and user_id=p_driver_id and role='driver' and active) then raise exception 'Driver is unavailable'; end if;
  insert into deliveries(order_id,store_id,driver_id,assigned_by,assigned_at) values(o.id,o.store_id,p_driver_id,auth.uid(),now()) on conflict(order_id) do update set driver_id=excluded.driver_id,assigned_by=excluded.assigned_by,assigned_at=excluded.assigned_at;
  insert into audit_log(store_id,actor_id,action,entity_type,entity_id,details) values(o.store_id,auth.uid(),'driver_assigned','order',o.id::text,jsonb_build_object('driver_id',p_driver_id));
end $$;

create or replace function app.valid_transition(p_from text,p_to text) returns boolean language sql immutable as $$ select (p_from,p_to) in (('pending_payment','confirmed'),('pending_payment','cancelled'),('confirmed','accepted'),('confirmed','cancelled'),('accepted','preparing'),('accepted','cancelled'),('preparing','ready_for_pickup'),('preparing','awaiting_driver'),('preparing','cancelled'),('ready_for_pickup','collected'),('awaiting_driver','picked_up'),('picked_up','out_for_delivery'),('out_for_delivery','delivered'),('out_for_delivery','failed_delivery'),('failed_delivery','awaiting_driver')) $$;
create or replace function public.transition_order(p_order_id uuid,p_next_status text,p_note text default null) returns void language plpgsql security definer set search_path=public,app,pg_temp as $$
declare o orders; v_role text; begin
  select * into o from orders where id=p_order_id for update; if not found then raise exception 'Order not found'; end if;
  select role into v_role from store_memberships where store_id=o.store_id and user_id=auth.uid() and active;
  if v_role is null then raise exception 'Not authorised'; end if;
  if v_role='driver' and (not exists(select 1 from deliveries where order_id=o.id and driver_id=auth.uid()) or p_next_status not in ('picked_up','out_for_delivery','delivered','failed_delivery')) then raise exception 'Driver transition not authorised'; end if;
  if not app.valid_transition(o.status,p_next_status) then raise exception 'Invalid status transition'; end if;
  if p_next_status='awaiting_driver' and o.fulfilment<>'delivery' then raise exception 'Pickup order cannot be dispatched'; end if;
  update orders set status=p_next_status,updated_at=now() where id=o.id;
  insert into order_status_history(order_id,from_status,to_status,actor_id,note) values(o.id,o.status,p_next_status,auth.uid(),p_note);
  if p_next_status='delivered' then update deliveries set delivered_at=now() where order_id=o.id; end if;
end $$;

create or replace function public.start_device_session(p_store_id uuid,p_device_name text) returns uuid language plpgsql security definer set search_path=public,app,pg_temp as $$ declare v_id uuid; begin if not app.has_store_role(p_store_id,array['owner','admin','manager','cashier','barista','dispatcher','driver']) then raise exception 'Not authorised'; end if; update device_sessions set logged_out_at=now() where user_id=auth.uid() and logged_out_at is null; insert into device_sessions(store_id,user_id,device_name) values(p_store_id,auth.uid(),trim(p_device_name)) returning id into v_id; return v_id; end $$;
create or replace function public.heartbeat_device_session() returns void language sql security definer set search_path=public,pg_temp as $$ update device_sessions set last_seen_at=now() where user_id=auth.uid() and logged_out_at is null $$;
create or replace function public.end_device_session() returns void language sql security definer set search_path=public,pg_temp as $$ update device_sessions set logged_out_at=now(),last_seen_at=now() where user_id=auth.uid() and logged_out_at is null $$;
create or replace function public.get_my_access(p_store_id uuid) returns jsonb language sql stable security definer set search_path=public,pg_temp as $$ select jsonb_build_object('role',m.role,'display_name',p.display_name) from store_memberships m join profiles p on p.user_id=m.user_id where m.store_id=p_store_id and m.user_id=auth.uid() and m.active and p.active $$;

create or replace function public.get_staff_workspace(p_store_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,app,pg_temp as $$ declare result jsonb; begin if not app.has_store_role(p_store_id,array['owner','admin','manager','cashier','barista','dispatcher']) then raise exception 'Not authorised'; end if; select jsonb_build_object('menu',(select get_public_menu(p_store_id)->'items'),'drivers',coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'display_name',p.display_name)) from store_memberships m join profiles p on p.user_id=m.user_id where m.store_id=p_store_id and m.role='driver' and m.active and p.active),'[]'::jsonb),'orders',coalesce((select jsonb_agg(jsonb_build_object('id',o.id,'order_number',o.order_number,'status',o.status,'fulfilment',o.fulfilment,'created_at',o.created_at,'items',(select coalesce(jsonb_agg(jsonb_build_object('name',oi.item_name,'quantity',oi.quantity)),'[]'::jsonb) from order_items oi where oi.order_id=o.id)) order by o.created_at) from orders o where o.store_id=p_store_id and o.status in ('confirmed','accepted','preparing','ready_for_pickup','awaiting_driver')),'[]'::jsonb)) into result; return result; end $$;
create or replace function public.get_driver_workspace(p_store_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,app,pg_temp as $$ declare result jsonb; begin if not app.has_store_role(p_store_id,array['driver']) then raise exception 'Not authorised'; end if; select jsonb_build_object('deliveries',coalesce(jsonb_agg(jsonb_build_object('order_id',o.id,'order_number',o.order_number,'status',o.status,'customer_name',o.customer_name,'customer_phone',o.customer_phone,'address',o.delivery_address,'next_status',case o.status when 'awaiting_driver' then 'picked_up' when 'picked_up' then 'out_for_delivery' when 'out_for_delivery' then 'delivered' end,'next_label',case o.status when 'awaiting_driver' then 'Confirm pickup' when 'picked_up' then 'Start delivery' when 'out_for_delivery' then 'Confirm delivered' end)),'[]'::jsonb)) into result from deliveries d join orders o on o.id=d.order_id where d.store_id=p_store_id and d.driver_id=auth.uid() and o.status in ('awaiting_driver','picked_up','out_for_delivery','failed_delivery'); return result; end $$;
create or replace function public.get_admin_dashboard(p_store_id uuid) returns jsonb language plpgsql stable security definer set search_path=public,app,pg_temp as $$ declare result jsonb; declare tz text; begin if not app.has_store_role(p_store_id,array['owner','admin','manager']) then raise exception 'Not authorised'; end if; select timezone into tz from stores where id=p_store_id; select jsonb_build_object('net_sales',coalesce((select sum(total) from orders where store_id=p_store_id and payment_status in ('paid','partially_refunded') and (created_at at time zone tz)::date=(now() at time zone tz)::date),0),'paid_orders',(select count(*) from orders where store_id=p_store_id and payment_status='paid' and (created_at at time zone tz)::date=(now() at time zone tz)::date),'open_orders',(select count(*) from orders where store_id=p_store_id and status not in ('collected','delivered','cancelled','refunded')),'refunds',coalesce((select sum(amount) from payments p join orders o on o.id=p.order_id where o.store_id=p_store_id and p.status='refunded' and (p.created_at at time zone tz)::date=(now() at time zone tz)::date),0),'average_order',coalesce((select avg(total)::integer from orders where store_id=p_store_id and payment_status='paid' and (created_at at time zone tz)::date=(now() at time zone tz)::date),0),'sessions',coalesce((select jsonb_agg(jsonb_build_object('name',p.display_name,'role',m.role,'device_name',s.device_name,'logged_in_at',s.logged_in_at,'last_seen_at',s.last_seen_at)) from device_sessions s join profiles p on p.user_id=s.user_id join store_memberships m on m.user_id=s.user_id and m.store_id=s.store_id where s.store_id=p_store_id and s.logged_out_at is null and s.last_seen_at>now()-interval '2 minutes'),'[]'::jsonb),'low_stock',coalesce((select jsonb_agg(jsonb_build_object('name',name,'unit',unit,'on_hand',on_hand,'reorder_level',reorder_level)) from inventory_items where store_id=p_store_id and active and on_hand<=reorder_level),'[]'::jsonb),'recent_orders',coalesce((select jsonb_agg(jsonb_build_object('order_number',order_number,'created_at',created_at,'source',source,'status',status,'payment_status',payment_status,'total',total) order by created_at desc) from (select * from orders where store_id=p_store_id order by created_at desc limit 50) x),'[]'::jsonb)) into result; return result; end $$;

alter table stores enable row level security; alter table profiles enable row level security; alter table store_memberships enable row level security; alter table device_sessions enable row level security; alter table menu_categories enable row level security; alter table menu_items enable row level security; alter table item_variants enable row level security; alter table modifier_options enable row level security; alter table variant_modifier_options enable row level security; alter table inventory_items enable row level security; alter table variant_recipes enable row level security; alter table stock_movements enable row level security; alter table orders enable row level security; alter table order_items enable row level security; alter table order_item_modifiers enable row level security; alter table payments enable row level security; alter table order_status_history enable row level security; alter table deliveries enable row level security; alter table audit_log enable row level security;

create policy stores_public_read on stores for select using(active);
create policy own_profile_read on profiles for select to authenticated using(user_id=auth.uid());
create policy own_membership_read on store_memberships for select to authenticated using(user_id=auth.uid());
create policy team_orders_read on orders for select to authenticated using(app.has_store_role(store_id,array['owner','admin','manager','cashier','barista','dispatcher']) or exists(select 1 from deliveries d where d.order_id=orders.id and d.driver_id=auth.uid()));
create policy managers_inventory_read on inventory_items for select to authenticated using(app.has_store_role(store_id,array['owner','admin','manager','cashier','barista']));
create policy managers_stock_read on stock_movements for select to authenticated using(app.has_store_role(store_id,array['owner','admin','manager']));
create policy assigned_delivery_read on deliveries for select to authenticated using(driver_id=auth.uid() or app.has_store_role(store_id,array['owner','admin','manager','dispatcher']));
create policy manager_audit_read on audit_log for select to authenticated using(app.has_store_role(store_id,array['owner','admin','manager']));

revoke execute on all functions in schema public from public;
grant usage on schema public to anon,authenticated;
grant usage on schema app to authenticated;
grant execute on function app.has_store_role(uuid,text[]) to authenticated;
grant execute on function get_public_menu(uuid),create_public_order(uuid,jsonb),get_public_order_status(uuid) to anon,authenticated;
grant execute on function create_counter_order(uuid,jsonb),transition_order(uuid,text,text),assign_delivery(uuid,uuid),start_device_session(uuid,text),heartbeat_device_session(),end_device_session(),get_my_access(uuid),get_staff_workspace(uuid),get_driver_workspace(uuid),get_admin_dashboard(uuid) to authenticated;
revoke insert,update,delete on all tables in schema public from anon,authenticated;

commit;
