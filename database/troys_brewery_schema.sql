begin;

create schema if not exists private;

create table public.stores (
  id bigint generated always as identity primary key,
  name text not null,
  slug text not null unique,
  address text,
  timezone text not null default 'America/Guyana',
  currency_code text not null default 'GYD',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.staff_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  store_id bigint not null references public.stores(id) on delete cascade,
  role text not null check (role in ('owner','manager','cashier','barista','kitchen','driver')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.menu_categories (
  id bigint generated always as identity primary key,
  store_id bigint not null references public.stores(id) on delete cascade,
  name text not null,
  slug text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug)
);

create table public.menu_items (
  id bigint generated always as identity primary key,
  store_id bigint not null references public.stores(id) on delete cascade,
  category_id bigint not null references public.menu_categories(id),
  slug text not null,
  name text not null,
  short_description text,
  description text,
  base_price numeric(12,2) not null check (base_price >= 0),
  image_key text not null default 'coffee',
  is_available boolean not null default true,
  is_popular boolean not null default false,
  supports_customization boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug)
);

create table public.modifier_groups (
  id bigint generated always as identity primary key,
  store_id bigint not null references public.stores(id) on delete cascade,
  name text not null,
  slug text not null,
  selection_type text not null default 'single' check (selection_type in ('single','multiple')),
  minimum_selections integer not null default 0 check (minimum_selections >= 0),
  maximum_selections integer not null default 1 check (maximum_selections >= minimum_selections),
  sort_order integer not null default 0,
  is_active boolean not null default true,
  unique (store_id, slug)
);

create table public.modifier_options (
  id bigint generated always as identity primary key,
  group_id bigint not null references public.modifier_groups(id) on delete cascade,
  name text not null,
  slug text not null,
  price_delta numeric(12,2) not null default 0,
  sort_order integer not null default 0,
  is_default boolean not null default false,
  is_available boolean not null default true,
  unique (group_id, slug)
);

create table public.menu_item_modifier_groups (
  menu_item_id bigint not null references public.menu_items(id) on delete cascade,
  modifier_group_id bigint not null references public.modifier_groups(id) on delete cascade,
  sort_order integer not null default 0,
  primary key (menu_item_id, modifier_group_id)
);

create table public.inventory_items (
  id bigint generated always as identity primary key,
  store_id bigint not null references public.stores(id) on delete cascade,
  slug text not null,
  name text not null,
  category text not null,
  stock_unit text not null,
  quantity_on_hand numeric(14,3) not null default 0,
  par_level numeric(14,3) not null default 0 check (par_level >= 0),
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (store_id, slug)
);

create table public.suppliers (
  id bigint generated always as identity primary key,
  store_id bigint not null references public.stores(id) on delete cascade,
  name text not null,
  contact_name text,
  phone text,
  email text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.supplier_items (
  id bigint generated always as identity primary key,
  supplier_id bigint references public.suppliers(id) on delete set null,
  inventory_item_id bigint not null references public.inventory_items(id) on delete cascade,
  supplier_sku text,
  pack_quantity numeric(14,3) not null check (pack_quantity > 0),
  pack_cost numeric(12,2) not null check (pack_cost >= 0),
  waste_percentage numeric(5,2) not null default 0 check (waste_percentage between 0 and 100),
  is_preferred boolean not null default false,
  effective_from timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.menu_item_recipe_lines (
  menu_item_id bigint not null references public.menu_items(id) on delete cascade,
  inventory_item_id bigint not null references public.inventory_items(id),
  quantity numeric(14,3) not null check (quantity >= 0),
  primary key (menu_item_id, inventory_item_id)
);

create table public.menu_item_modifier_recipe_lines (
  menu_item_id bigint not null references public.menu_items(id) on delete cascade,
  modifier_option_id bigint not null references public.modifier_options(id) on delete cascade,
  inventory_item_id bigint not null references public.inventory_items(id),
  quantity_delta numeric(14,3) not null,
  primary key (menu_item_id, modifier_option_id, inventory_item_id)
);

create table public.orders (
  id bigint generated always as identity primary key,
  store_id bigint not null references public.stores(id),
  order_number text unique,
  customer_id uuid references auth.users(id) on delete set null,
  customer_name text not null,
  customer_phone text,
  customer_email text,
  channel text not null check (channel in ('pickup','dine_in','delivery','counter')),
  status text not null default 'new' check (status in ('new','accepted','preparing','ready','out_for_delivery','completed','cancelled','refunded')),
  payment_method text not null default 'pay_at_counter' check (payment_method in ('cash','mmg','card','pay_at_counter')),
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded','partially_refunded')),
  subtotal numeric(12,2) not null default 0 check (subtotal >= 0),
  delivery_fee numeric(12,2) not null default 0 check (delivery_fee >= 0),
  total numeric(12,2) not null default 0 check (total >= 0),
  delivery_address text,
  customer_notes text,
  promised_at timestamptz,
  completed_at timestamptz,
  priority boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.order_items (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  menu_item_id bigint references public.menu_items(id) on delete set null,
  item_name text not null,
  quantity integer not null check (quantity > 0 and quantity <= 50),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  special_instructions text,
  created_at timestamptz not null default now()
);

create table public.order_item_modifiers (
  id bigint generated always as identity primary key,
  order_item_id bigint not null references public.order_items(id) on delete cascade,
  modifier_option_id bigint references public.modifier_options(id) on delete set null,
  group_name text not null,
  option_name text not null,
  price_delta numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create table public.order_status_history (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references auth.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now()
);

create table public.payments (
  id bigint generated always as identity primary key,
  order_id bigint not null references public.orders(id),
  method text not null check (method in ('cash','mmg','card','pay_at_counter')),
  status text not null default 'pending' check (status in ('pending','paid','failed','refunded','partially_refunded')),
  amount numeric(12,2) not null check (amount >= 0),
  external_reference text,
  processed_by uuid references auth.users(id) on delete set null,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.deliveries (
  id bigint generated always as identity primary key,
  order_id bigint not null unique references public.orders(id) on delete cascade,
  driver_id uuid references public.profiles(id) on delete set null,
  status text not null default 'unassigned' check (status in ('unassigned','assigned','collected','en_route','delivered','failed')),
  address text not null,
  instructions text,
  assigned_at timestamptz,
  collected_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.inventory_movements (
  id bigint generated always as identity primary key,
  inventory_item_id bigint not null references public.inventory_items(id),
  store_id bigint not null references public.stores(id),
  movement_type text not null check (movement_type in ('receive','sale','waste','count_adjustment','return','manual_adjustment')),
  quantity_change numeric(14,3) not null check (quantity_change <> 0),
  quantity_after numeric(14,3) not null,
  order_id bigint references public.orders(id) on delete set null,
  reference text,
  note text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.menu_price_history (
  id bigint generated always as identity primary key,
  menu_item_id bigint not null references public.menu_items(id) on delete cascade,
  old_price numeric(12,2) not null,
  new_price numeric(12,2) not null,
  changed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  store_id bigint references public.stores(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index staff_roles_store_id_idx on public.staff_roles (store_id);
create index menu_categories_store_sort_idx on public.menu_categories (store_id, sort_order) where is_active;
create index menu_items_store_category_idx on public.menu_items (store_id, category_id) where is_available;
create index modifier_options_group_sort_idx on public.modifier_options (group_id, sort_order) where is_available;
create index menu_item_modifier_groups_group_idx on public.menu_item_modifier_groups (modifier_group_id);
create index inventory_items_store_active_idx on public.inventory_items (store_id, name) where is_active;
create index supplier_items_inventory_item_idx on public.supplier_items (inventory_item_id, effective_from desc);
create index supplier_items_supplier_id_idx on public.supplier_items (supplier_id);
create index recipe_lines_inventory_item_idx on public.menu_item_recipe_lines (inventory_item_id);
create index modifier_recipe_option_idx on public.menu_item_modifier_recipe_lines (modifier_option_id);
create index modifier_recipe_inventory_idx on public.menu_item_modifier_recipe_lines (inventory_item_id);
create index orders_customer_created_idx on public.orders (customer_id, created_at desc) where customer_id is not null;
create index orders_store_status_created_idx on public.orders (store_id, status, created_at desc);
create index orders_open_queue_idx on public.orders (store_id, promised_at) where status in ('new','accepted','preparing','ready','out_for_delivery');
create index order_items_order_id_idx on public.order_items (order_id);
create index order_items_menu_item_idx on public.order_items (menu_item_id);
create index order_item_modifiers_order_item_idx on public.order_item_modifiers (order_item_id);
create index order_item_modifiers_option_idx on public.order_item_modifiers (modifier_option_id);
create index order_status_history_order_created_idx on public.order_status_history (order_id, created_at);
create index payments_order_id_idx on public.payments (order_id);
create index deliveries_driver_status_idx on public.deliveries (driver_id, status) where driver_id is not null;
create index inventory_movements_item_created_idx on public.inventory_movements (inventory_item_id, created_at desc);
create index inventory_movements_store_created_idx on public.inventory_movements (store_id, created_at desc);
create index inventory_movements_order_id_idx on public.inventory_movements (order_id) where order_id is not null;
create index menu_price_history_item_created_idx on public.menu_price_history (menu_item_id, created_at desc);
create index audit_log_store_created_idx on public.audit_log (store_id, created_at desc);
create index audit_log_actor_idx on public.audit_log (actor_id) where actor_id is not null;
create index inventory_movements_created_by_idx on public.inventory_movements (created_by) where created_by is not null;
create index menu_items_category_id_idx on public.menu_items (category_id);
create index menu_price_history_changed_by_idx on public.menu_price_history (changed_by) where changed_by is not null;
create index order_status_history_changed_by_idx on public.order_status_history (changed_by) where changed_by is not null;
create index orders_created_by_idx on public.orders (created_by) where created_by is not null;
create index payments_processed_by_idx on public.payments (processed_by) where processed_by is not null;
create index suppliers_store_id_idx on public.suppliers (store_id);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'), new.phone)
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function private.has_staff_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1
    from public.staff_roles sr
    where sr.user_id = (select auth.uid())
      and sr.is_active
      and sr.role = any(required_roles)
  );
$$;

create or replace function private.is_assigned_driver(p_order_id bigint)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.deliveries d
    where d.order_id = p_order_id and d.driver_id = (select auth.uid())
  );
$$;

create or replace function private.log_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status is distinct from new.status then
    insert into public.order_status_history (order_id, from_status, to_status, changed_by)
    values (new.id, old.status, new.status, (select auth.uid()));
    if new.status = 'completed' and new.completed_at is null then
      new.completed_at = now();
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.log_menu_price_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.base_price is distinct from new.base_price then
    insert into public.menu_price_history (menu_item_id, old_price, new_price, changed_by)
    values (new.id, old.base_price, new.base_price, (select auth.uid()));
  end if;
  return new;
end;
$$;

create or replace function public.record_inventory_movement(
  p_inventory_item_id bigint,
  p_action text,
  p_quantity numeric,
  p_reference text default null,
  p_note text default null
)
returns public.inventory_items
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.inventory_items;
  v_change numeric(14,3);
begin
  if not private.has_staff_role(array['owner','manager','cashier','barista','kitchen']) then
    raise exception 'Not authorized to update inventory';
  end if;
  if p_quantity < 0 then
    raise exception 'Quantity cannot be negative';
  end if;

  select * into v_item from public.inventory_items where id = p_inventory_item_id and is_active for update;
  if not found then raise exception 'Inventory item not found'; end if;

  if p_action = 'receive' then
    if p_quantity <= 0 then raise exception 'Received quantity must be greater than zero'; end if;
    v_change := p_quantity;
  elsif p_action = 'waste' then
    if p_quantity <= 0 or p_quantity > v_item.quantity_on_hand then raise exception 'Invalid waste quantity'; end if;
    v_change := -p_quantity;
  elsif p_action = 'count' then
    v_change := p_quantity - v_item.quantity_on_hand;
    if v_change = 0 then return v_item; end if;
  else
    raise exception 'Unsupported inventory action';
  end if;

  update public.inventory_items
  set quantity_on_hand = quantity_on_hand + v_change
  where id = v_item.id
  returning * into v_item;

  insert into public.inventory_movements (inventory_item_id, store_id, movement_type, quantity_change, quantity_after, reference, note, created_by)
  values (v_item.id, v_item.store_id, case p_action when 'receive' then 'receive' when 'waste' then 'waste' else 'count_adjustment' end, v_change, v_item.quantity_on_hand, nullif(trim(p_reference),''), nullif(trim(p_note),''), (select auth.uid()));

  insert into public.audit_log (store_id, actor_id, action, entity_type, entity_id, details)
  values (v_item.store_id, (select auth.uid()), 'inventory_' || p_action, 'inventory_item', v_item.id::text, jsonb_build_object('quantity_change',v_change,'quantity_after',v_item.quantity_on_hand));

  return v_item;
end;
$$;

create or replace function public.place_order(
  p_store_id bigint,
  p_customer_name text,
  p_customer_phone text,
  p_channel text,
  p_payment_method text,
  p_items jsonb,
  p_delivery_address text default null,
  p_customer_notes text default null
)
returns table (order_id bigint, order_number text, total numeric)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_order_id bigint;
  v_order_number text;
  v_subtotal numeric(12,2) := 0;
  v_delivery_fee numeric(12,2) := 0;
  v_item jsonb;
  v_menu public.menu_items;
  v_quantity integer;
  v_unit_price numeric(12,2);
  v_order_item_id bigint;
  v_option_id bigint;
  v_option record;
  v_inventory record;
  v_quantity_after numeric(14,3);
begin
  if length(trim(coalesce(p_customer_name,''))) < 2 then raise exception 'Customer name is required'; end if;
  if p_channel not in ('pickup','dine_in','delivery','counter') then raise exception 'Invalid order channel'; end if;
  if p_payment_method not in ('cash','mmg','card','pay_at_counter') then raise exception 'Invalid payment method'; end if;
  if p_channel = 'delivery' and length(trim(coalesce(p_delivery_address,''))) < 5 then raise exception 'Delivery address is required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 50 then raise exception 'Order must contain between 1 and 50 lines'; end if;
  if not exists (select 1 from public.stores where id = p_store_id and is_active) then raise exception 'Store is unavailable'; end if;

  if p_channel = 'delivery' then v_delivery_fee := 650; end if;

  insert into public.orders (store_id, customer_id, customer_name, customer_phone, channel, payment_method, delivery_fee, delivery_address, customer_notes, promised_at, created_by)
  values (p_store_id, (select auth.uid()), trim(p_customer_name), nullif(trim(coalesce(p_customer_phone,'')),''), p_channel, p_payment_method, v_delivery_fee, nullif(trim(coalesce(p_delivery_address,'')),''), nullif(trim(coalesce(p_customer_notes,'')),''), now() + interval '14 minutes', (select auth.uid()))
  returning id into v_order_id;

  v_order_number := 'TB-' || lpad(v_order_id::text, 6, '0');
  update public.orders set order_number = v_order_number where id = v_order_id;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_quantity := coalesce((v_item ->> 'quantity')::integer, 0);
    if v_quantity < 1 or v_quantity > 20 then raise exception 'Invalid item quantity'; end if;

    select * into v_menu
    from public.menu_items
    where id = (v_item ->> 'menu_item_id')::bigint
      and store_id = p_store_id
      and is_available;
    if not found then raise exception 'Menu item is unavailable'; end if;

    if jsonb_typeof(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb)) <> 'array' then
      raise exception 'Modifier selections must be an array';
    end if;
    if (select count(*) from jsonb_array_elements_text(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb))) <>
       (select count(distinct value) from jsonb_array_elements_text(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb))) then
      raise exception 'Duplicate modifier options are not allowed';
    end if;
    if exists (
      select 1
      from public.menu_item_modifier_groups mmg
      join public.modifier_groups mg on mg.id = mmg.modifier_group_id and mg.is_active
      left join lateral (
        select count(*)::integer as selection_count
        from jsonb_array_elements_text(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb)) selected(value)
        join public.modifier_options mo on mo.id = selected.value::bigint and mo.group_id = mg.id and mo.is_available
      ) selections on true
      where mmg.menu_item_id = v_menu.id
        and (selections.selection_count < mg.minimum_selections or selections.selection_count > mg.maximum_selections)
    ) then
      raise exception 'Required modifier selections are incomplete or exceed the allowed maximum';
    end if;

    v_unit_price := v_menu.base_price;
    for v_option_id in select value::bigint from jsonb_array_elements_text(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb))
    loop
      select mo.id, mo.name option_name, mo.price_delta, mg.name group_name
      into v_option
      from public.modifier_options mo
      join public.modifier_groups mg on mg.id = mo.group_id
      join public.menu_item_modifier_groups mmg on mmg.modifier_group_id = mg.id
      where mo.id = v_option_id and mmg.menu_item_id = v_menu.id and mo.is_available and mg.is_active;
      if not found then raise exception 'Invalid modifier option'; end if;
      v_unit_price := v_unit_price + v_option.price_delta;
    end loop;

    insert into public.order_items (order_id, menu_item_id, item_name, quantity, unit_price, line_total, special_instructions)
    values (v_order_id, v_menu.id, v_menu.name, v_quantity, v_unit_price, v_unit_price * v_quantity, nullif(trim(coalesce(v_item ->> 'special_instructions','')),''))
    returning id into v_order_item_id;

    for v_option_id in select value::bigint from jsonb_array_elements_text(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb))
    loop
      select mo.id, mo.name option_name, mo.price_delta, mg.name group_name
      into v_option
      from public.modifier_options mo join public.modifier_groups mg on mg.id = mo.group_id
      where mo.id = v_option_id;
      insert into public.order_item_modifiers (order_item_id, modifier_option_id, group_name, option_name, price_delta)
      values (v_order_item_id, v_option.id, v_option.group_name, v_option.option_name, v_option.price_delta);
    end loop;

    for v_inventory in
      select rl.inventory_item_id, rl.quantity * v_quantity quantity_change
      from public.menu_item_recipe_lines rl where rl.menu_item_id = v_menu.id
      union all
      select mrl.inventory_item_id, mrl.quantity_delta * v_quantity
      from public.menu_item_modifier_recipe_lines mrl
      where mrl.menu_item_id = v_menu.id
        and mrl.modifier_option_id in (select value::bigint from jsonb_array_elements_text(coalesce(v_item -> 'modifier_option_ids','[]'::jsonb)))
    loop
      update public.inventory_items
      set quantity_on_hand = quantity_on_hand - v_inventory.quantity_change
      where id = v_inventory.inventory_item_id
      returning quantity_on_hand into v_quantity_after;
      insert into public.inventory_movements (inventory_item_id, store_id, movement_type, quantity_change, quantity_after, order_id, reference)
      values (v_inventory.inventory_item_id, p_store_id, 'sale', -v_inventory.quantity_change, v_quantity_after, v_order_id, v_order_number);
    end loop;

    v_subtotal := v_subtotal + (v_unit_price * v_quantity);
  end loop;

  select coalesce(sum(oi.line_total),0) into v_subtotal from public.order_items oi where oi.order_id = v_order_id;
  update public.orders set subtotal = v_subtotal, total = v_subtotal + v_delivery_fee where id = v_order_id;
  insert into public.payments (order_id, method, status, amount) values (v_order_id, p_payment_method, 'pending', v_subtotal + v_delivery_fee);
  if p_channel = 'delivery' then
    insert into public.deliveries (order_id, address, instructions) values (v_order_id, trim(p_delivery_address), nullif(trim(coalesce(p_customer_notes,'')),''));
  end if;
  insert into public.order_status_history (order_id, to_status, changed_by, note) values (v_order_id, 'new', (select auth.uid()), 'Order placed');

  return query select v_order_id, v_order_number, v_subtotal + v_delivery_fee;
end;
$$;

create trigger profiles_updated_at before update on public.profiles for each row execute function private.set_updated_at();
create trigger stores_updated_at before update on public.stores for each row execute function private.set_updated_at();
create trigger staff_roles_updated_at before update on public.staff_roles for each row execute function private.set_updated_at();
create trigger menu_categories_updated_at before update on public.menu_categories for each row execute function private.set_updated_at();
create trigger menu_items_updated_at before update on public.menu_items for each row execute function private.set_updated_at();
create trigger inventory_items_updated_at before update on public.inventory_items for each row execute function private.set_updated_at();
create trigger suppliers_updated_at before update on public.suppliers for each row execute function private.set_updated_at();
create trigger orders_status_audit before update on public.orders for each row execute function private.log_order_status_change();
create trigger orders_updated_at before update on public.orders for each row execute function private.set_updated_at();
create trigger deliveries_updated_at before update on public.deliveries for each row execute function private.set_updated_at();
create trigger menu_price_audit after update of base_price on public.menu_items for each row execute function private.log_menu_price_change();
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

alter table public.stores enable row level security;
alter table public.profiles enable row level security;
alter table public.staff_roles enable row level security;
alter table public.menu_categories enable row level security;
alter table public.menu_items enable row level security;
alter table public.modifier_groups enable row level security;
alter table public.modifier_options enable row level security;
alter table public.menu_item_modifier_groups enable row level security;
alter table public.inventory_items enable row level security;
alter table public.suppliers enable row level security;
alter table public.supplier_items enable row level security;
alter table public.menu_item_recipe_lines enable row level security;
alter table public.menu_item_modifier_recipe_lines enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_item_modifiers enable row level security;
alter table public.order_status_history enable row level security;
alter table public.payments enable row level security;
alter table public.deliveries enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.menu_price_history enable row level security;
alter table public.audit_log enable row level security;

revoke all on public.stores, public.profiles, public.staff_roles, public.menu_categories, public.menu_items, public.modifier_groups, public.modifier_options, public.menu_item_modifier_groups, public.inventory_items, public.suppliers, public.supplier_items, public.menu_item_recipe_lines, public.menu_item_modifier_recipe_lines, public.orders, public.order_items, public.order_item_modifiers, public.order_status_history, public.payments, public.deliveries, public.inventory_movements, public.menu_price_history, public.audit_log from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
grant usage on schema public to anon, authenticated;
grant usage on schema private to authenticated;
grant select on public.stores, public.menu_categories, public.menu_items, public.modifier_groups, public.modifier_options, public.menu_item_modifier_groups to anon, authenticated;
grant select on public.profiles, public.staff_roles, public.inventory_items, public.suppliers, public.supplier_items, public.menu_item_recipe_lines, public.menu_item_modifier_recipe_lines, public.orders, public.order_items, public.order_item_modifiers, public.order_status_history, public.payments, public.deliveries, public.inventory_movements, public.menu_price_history, public.audit_log to authenticated;
grant insert, update on public.profiles to authenticated;
grant update on public.stores to authenticated;
grant insert, update, delete on public.staff_roles, public.menu_categories, public.menu_items, public.modifier_groups, public.modifier_options, public.menu_item_modifier_groups, public.inventory_items, public.suppliers, public.supplier_items, public.menu_item_recipe_lines, public.menu_item_modifier_recipe_lines to authenticated;
grant update on public.orders, public.payments, public.deliveries to authenticated;
grant usage, select on all sequences in schema public to authenticated;
revoke all on function private.set_updated_at() from public, anon, authenticated;
revoke all on function private.has_staff_role(text[]) from public, anon;
revoke all on function private.is_assigned_driver(bigint) from public, anon;
grant execute on function private.has_staff_role(text[]) to authenticated;
grant execute on function private.is_assigned_driver(bigint) to authenticated;
revoke all on function public.record_inventory_movement(bigint,text,numeric,text,text) from public, anon;
grant execute on function public.record_inventory_movement(bigint,text,numeric,text,text) to authenticated;
revoke all on function public.place_order(bigint,text,text,text,text,jsonb,text,text) from public;
grant execute on function public.place_order(bigint,text,text,text,text,jsonb,text,text) to anon, authenticated;
revoke all on function private.handle_new_user() from public, anon, authenticated;
revoke all on function private.log_order_status_change() from public, anon, authenticated;
revoke all on function private.log_menu_price_change() from public, anon, authenticated;

create policy stores_anon_read on public.stores for select to anon using (is_active);
create policy stores_authenticated_read on public.stores for select to authenticated using (is_active or (select private.has_staff_role(array['owner','manager'])));
create policy stores_manager_update on public.stores for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy profiles_self_or_manager_read on public.profiles for select to authenticated using ((select auth.uid()) = id or (select private.has_staff_role(array['owner','manager'])));
create policy profiles_self_insert on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_self_update on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy staff_roles_self_or_manager_read on public.staff_roles for select to authenticated using ((select auth.uid()) = user_id or (select private.has_staff_role(array['owner','manager'])));
create policy staff_roles_manager_insert on public.staff_roles for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy staff_roles_manager_update on public.staff_roles for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy staff_roles_manager_delete on public.staff_roles for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy categories_anon_read on public.menu_categories for select to anon using (is_active);
create policy categories_authenticated_read on public.menu_categories for select to authenticated using (is_active or (select private.has_staff_role(array['owner','manager'])));
create policy categories_manager_insert on public.menu_categories for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy categories_manager_update on public.menu_categories for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy categories_manager_delete on public.menu_categories for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy menu_anon_read on public.menu_items for select to anon using (is_available);
create policy menu_authenticated_read on public.menu_items for select to authenticated using (is_available or (select private.has_staff_role(array['owner','manager','cashier','barista','kitchen'])));
create policy menu_manager_insert on public.menu_items for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy menu_manager_update on public.menu_items for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy menu_manager_delete on public.menu_items for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_groups_anon_read on public.modifier_groups for select to anon using (is_active);
create policy modifier_groups_authenticated_read on public.modifier_groups for select to authenticated using (is_active or (select private.has_staff_role(array['owner','manager'])));
create policy modifier_groups_manager_insert on public.modifier_groups for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_groups_manager_update on public.modifier_groups for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_groups_manager_delete on public.modifier_groups for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_options_anon_read on public.modifier_options for select to anon using (is_available);
create policy modifier_options_authenticated_read on public.modifier_options for select to authenticated using (is_available or (select private.has_staff_role(array['owner','manager'])));
create policy modifier_options_manager_insert on public.modifier_options for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_options_manager_update on public.modifier_options for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_options_manager_delete on public.modifier_options for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy menu_modifier_map_public_read on public.menu_item_modifier_groups for select to anon, authenticated using (true);
create policy menu_modifier_map_manager_insert on public.menu_item_modifier_groups for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy menu_modifier_map_manager_update on public.menu_item_modifier_groups for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy menu_modifier_map_manager_delete on public.menu_item_modifier_groups for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy inventory_staff_read on public.inventory_items for select to authenticated using ((select private.has_staff_role(array['owner','manager','cashier','barista','kitchen'])));
create policy inventory_manager_insert on public.inventory_items for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy inventory_manager_update on public.inventory_items for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy inventory_manager_delete on public.inventory_items for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy suppliers_manager_only on public.suppliers for all to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy supplier_items_manager_only on public.supplier_items for all to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy recipes_manager_read on public.menu_item_recipe_lines for select to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy recipes_manager_insert on public.menu_item_recipe_lines for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy recipes_manager_update on public.menu_item_recipe_lines for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy recipes_manager_delete on public.menu_item_recipe_lines for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_recipes_manager_read on public.menu_item_modifier_recipe_lines for select to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_recipes_manager_insert on public.menu_item_modifier_recipe_lines for insert to authenticated with check ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_recipes_manager_update on public.menu_item_modifier_recipe_lines for update to authenticated using ((select private.has_staff_role(array['owner','manager']))) with check ((select private.has_staff_role(array['owner','manager'])));
create policy modifier_recipes_manager_delete on public.menu_item_modifier_recipe_lines for delete to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy orders_customer_or_staff_read on public.orders for select to authenticated using ((select auth.uid()) = customer_id or (select private.has_staff_role(array['owner','manager','cashier','barista','kitchen'])) or (select private.is_assigned_driver(id)));
create policy orders_staff_update on public.orders for update to authenticated using ((select private.has_staff_role(array['owner','manager','cashier','barista','kitchen']))) with check ((select private.has_staff_role(array['owner','manager','cashier','barista','kitchen'])));
create policy order_items_visible_with_order on public.order_items for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id));
create policy order_modifiers_visible_with_order on public.order_item_modifiers for select to authenticated using (exists (select 1 from public.order_items oi join public.orders o on o.id = oi.order_id where oi.id = order_item_id));
create policy order_history_visible_with_order on public.order_status_history for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id));
create policy payments_customer_or_staff_read on public.payments for select to authenticated using (exists (select 1 from public.orders o where o.id = order_id));
create policy payments_staff_update on public.payments for update to authenticated using ((select private.has_staff_role(array['owner','manager','cashier']))) with check ((select private.has_staff_role(array['owner','manager','cashier'])));
create policy deliveries_customer_staff_driver_read on public.deliveries for select to authenticated using (driver_id = (select auth.uid()) or exists (select 1 from public.orders o where o.id = order_id and o.customer_id = (select auth.uid())) or (select private.has_staff_role(array['owner','manager','cashier','barista','kitchen'])));
create policy deliveries_staff_driver_update on public.deliveries for update to authenticated using (driver_id = (select auth.uid()) or (select private.has_staff_role(array['owner','manager','cashier']))) with check (driver_id = (select auth.uid()) or (select private.has_staff_role(array['owner','manager','cashier'])));
create policy inventory_movements_staff_read on public.inventory_movements for select to authenticated using ((select private.has_staff_role(array['owner','manager','cashier','barista','kitchen'])));
create policy price_history_manager_read on public.menu_price_history for select to authenticated using ((select private.has_staff_role(array['owner','manager'])));
create policy audit_log_manager_read on public.audit_log for select to authenticated using ((select private.has_staff_role(array['owner','manager'])));

insert into public.stores (name, slug, address) values ('Troy''s Brewery - Ogle','ogle','Ogle, East Coast Demerara, Guyana');

with s as (select id from public.stores where slug='ogle')
insert into public.menu_categories (store_id,name,slug,sort_order) select id,'Espresso','espresso',10 from s union all select id,'Cold bar','cold-bar',20 from s union all select id,'Kitchen','kitchen',30 from s;

with s as (select id from public.stores where slug='ogle'), c as (select id,slug from public.menu_categories)
insert into public.menu_items (store_id,category_id,slug,name,short_description,description,base_price,image_key,is_available,is_popular,supports_customization)
select s.id,c.id,v.slug,v.name,v.short_description,v.description,v.price,v.image_key,v.available,v.popular,v.customizable
from s cross join (values
('flat-white','Flat White','Velvety & balanced','Double ristretto, silky microfoam and a naturally sweet finish.',1100::numeric,'coffee',true,true,true,'espresso'),
('signature-latte','Troy''s Signature Latte','House favourite','House espresso, brown-sugar syrup and cinnamon cream.',1250,'coffee',true,true,true,'espresso'),
('americano','Long Black','Bold & clean','Double espresso poured over filtered hot water.',800,'coffee',true,false,true,'espresso'),
('mocha','Dark Chocolate Mocha','Deep & indulgent','Espresso, 70% dark cocoa and steamed milk.',1350,'coffee',true,false,true,'espresso'),
('cold-brew','18-Hour Cold Brew','Smooth & bright','Slow-steeped house beans served over clear ice.',1150,'cold',true,true,true,'cold-bar'),
('matcha','Iced Matcha Cloud','Fresh & creamy','Ceremonial matcha with a soft vanilla cold foam.',1400,'cold',false,false,true,'cold-bar'),
('croissant','Butter Croissant','Baked this morning','Layered cultured-butter pastry with a crisp shell.',850,'food',true,false,false,'kitchen'),
('turkey-croissant','Smoked Turkey Croissant','Savoury breakfast','Smoked turkey, cheddar, greens and pepper relish.',1850,'food',true,false,false,'kitchen')
) v(slug,name,short_description,description,price,image_key,available,popular,customizable,category_slug)
join c on c.slug=v.category_slug;

with s as (select id from public.stores where slug='ogle')
insert into public.modifier_groups (store_id,name,slug,minimum_selections,maximum_selections,sort_order)
select id,'Size','size',1,1,10 from s union all select id,'Temperature','temperature',1,1,20 from s union all select id,'Milk','milk',1,1,30 from s union all select id,'Sweetness','sweetness',1,1,40 from s union all select id,'Espresso shots','shots',1,1,50 from s union all select id,'Flavour','flavour',1,1,60 from s;

insert into public.modifier_options (group_id,name,slug,price_delta,sort_order,is_default)
select g.id,v.name,v.slug,v.price,v.sort_order,v.is_default from public.modifier_groups g join (values
('size','8 oz','8-oz',-150::numeric,10,false),('size','12 oz','12-oz',0,20,true),('size','16 oz','16-oz',300,30,false),
('temperature','Hot','hot',0,10,true),('temperature','Iced','iced',0,20,false),
('milk','Whole milk','whole-milk',0,10,true),('milk','Oat milk','oat-milk',180,20,false),('milk','Almond milk','almond-milk',180,30,false),('milk','Coconut milk','coconut-milk',180,40,false),
('sweetness','0%','0',0,10,false),('sweetness','25%','25',0,20,false),('sweetness','50%','50',0,30,true),('sweetness','75%','75',0,40,false),('sweetness','100%','100',0,50,false),
('shots','1 shot','1',0,10,false),('shots','2 shots','2',0,20,true),('shots','3 shots','3',300,30,false),('shots','4 shots','4',600,40,false),
('flavour','None','none',0,10,true),('flavour','Vanilla','vanilla',150,20,false),('flavour','Caramel','caramel',150,30,false),('flavour','Hazelnut','hazelnut',150,40,false)
) v(group_slug,name,slug,price,sort_order,is_default) on g.slug=v.group_slug;

insert into public.menu_item_modifier_groups (menu_item_id,modifier_group_id,sort_order)
select mi.id,mg.id,mg.sort_order from public.menu_items mi cross join public.modifier_groups mg where mi.supports_customization;

with s as (select id from public.stores where slug='ogle')
insert into public.inventory_items (store_id,slug,name,category,stock_unit,quantity_on_hand,par_level,reorder_level)
select id,v.slug,v.name,v.category,v.unit,v.qty,v.par,v.reorder from s cross join (values
('espresso-beans','House espresso beans','Coffee','g',2600::numeric,8000::numeric,4800::numeric),
('whole-milk','Whole milk','Dairy','ml',18000,12000,7200),('oat-milk','Oat milk','Alt milk','ml',4000,16000,9600),
('almond-milk','Almond milk','Alt milk','ml',6000,12000,7200),('coconut-milk','Coconut milk','Alt milk','ml',6000,12000,7200),
('brown-sugar','Brown-sugar syrup','Syrup','ml',1500,3000,1200),('dark-cocoa','Dark cocoa','Dry goods','g',1000,1500,600),
('matcha','Ceremonial matcha','Dry goods','g',250,500,200),('cup-lid','Cup and lid','Packaging','unit',32,90,54),
('croissant','Butter croissants','Kitchen','unit',22,18,10),('turkey-filling','Turkey, cheese and garnish','Kitchen','g',1200,2000,800),('food-box','Food box','Packaging','unit',50,80,30)
) v(slug,name,category,unit,qty,par,reorder);

insert into public.menu_item_recipe_lines (menu_item_id,inventory_item_id,quantity)
select mi.id,ii.id,v.qty from (values
('flat-white','espresso-beans',18::numeric),('flat-white','whole-milk',220),('flat-white','cup-lid',1),
('signature-latte','espresso-beans',18),('signature-latte','whole-milk',200),('signature-latte','brown-sugar',20),('signature-latte','cup-lid',1),
('americano','espresso-beans',18),('americano','cup-lid',1),('mocha','espresso-beans',18),('mocha','whole-milk',190),('mocha','dark-cocoa',20),('mocha','cup-lid',1),
('cold-brew','espresso-beans',45),('cold-brew','cup-lid',1),('matcha','matcha',4),('matcha','oat-milk',200),('matcha','cup-lid',1),
('croissant','croissant',1),('croissant','food-box',1),('turkey-croissant','croissant',1),('turkey-croissant','turkey-filling',90),('turkey-croissant','food-box',1)
) v(menu_slug,inventory_slug,qty) join public.menu_items mi on mi.slug=v.menu_slug join public.inventory_items ii on ii.slug=v.inventory_slug;

-- Customizations change the inventory ledger as well as the selling price.
-- Milk substitutions reverse the base milk recipe and consume the selected milk.
insert into public.menu_item_modifier_recipe_lines (menu_item_id,modifier_option_id,inventory_item_id,quantity_delta)
select rl.menu_item_id, mo.id, rl.inventory_item_id, -rl.quantity
from public.menu_item_recipe_lines rl
join public.inventory_items base_milk on base_milk.id=rl.inventory_item_id and base_milk.slug='whole-milk'
join public.modifier_options mo on mo.slug in ('oat-milk','almond-milk','coconut-milk')
join public.modifier_groups mg on mg.id=mo.group_id and mg.slug='milk'
union all
select rl.menu_item_id, mo.id, selected_milk.id, rl.quantity
from public.menu_item_recipe_lines rl
join public.inventory_items base_milk on base_milk.id=rl.inventory_item_id and base_milk.slug='whole-milk'
join public.modifier_options mo on mo.slug in ('oat-milk','almond-milk','coconut-milk')
join public.modifier_groups mg on mg.id=mo.group_id and mg.slug='milk'
join public.inventory_items selected_milk on selected_milk.slug=mo.slug;

-- Espresso drinks are based on two shots (18 g); one, three and four shots adjust beans accordingly.
insert into public.menu_item_modifier_recipe_lines (menu_item_id,modifier_option_id,inventory_item_id,quantity_delta)
select mi.id, mo.id, beans.id, values_by_shot.quantity_delta
from public.menu_items mi
join public.inventory_items beans on beans.slug='espresso-beans'
join public.modifier_groups mg on mg.slug='shots'
join public.modifier_options mo on mo.group_id=mg.id
join (values ('1',-9::numeric),('3',9::numeric),('4',18::numeric)) values_by_shot(option_slug,quantity_delta) on values_by_shot.option_slug=mo.slug
where mi.slug in ('flat-white','signature-latte','americano','mocha');

with s as (select id from public.stores where slug='ogle'), sup as (
insert into public.suppliers (store_id,name) select id,'Sample supplier — replace with verified vendor' from s returning id)
insert into public.supplier_items (supplier_id,inventory_item_id,pack_quantity,pack_cost,waste_percentage,is_preferred)
select sup.id,ii.id,v.pack_qty,v.pack_cost,v.waste,true from sup cross join (values
('espresso-beans',1000::numeric,5000::numeric,5::numeric),('whole-milk',1000,700,3),('oat-milk',1000,1300,3),('brown-sugar',750,2600,2),('dark-cocoa',500,2300,3),('matcha',250,4000,4),('cup-lid',50,4000,0),('croissant',12,6000,5),('turkey-filling',1000,6000,5),('food-box',50,5000,0)
) v(slug,pack_qty,pack_cost,waste) join public.inventory_items ii on ii.slug=v.slug;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='orders') then
    alter publication supabase_realtime add table public.orders;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='inventory_items') then
    alter publication supabase_realtime add table public.inventory_items;
  end if;
end $$;

commit;
