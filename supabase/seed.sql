-- Development-only seed. Replace contact details, prices and recipes after owner approval.
do $$
declare s uuid; c uuid; i uuid; v uuid; beans uuid; cups uuid;
begin
  insert into public.stores(name,slug) values('Troy''s Brewery','troys-brewery') returning id into s;
  insert into public.menu_categories(store_id,name,sort_order) values(s,'Espresso & Coffee',1) returning id into c;
  insert into public.inventory_items(store_id,name,unit,on_hand,reorder_level) values(s,'Colombia Huila beans','g',8000,1000) returning id into beans;
  insert into public.inventory_items(store_id,name,unit,on_hand,reorder_level) values(s,'12 oz cups','each',200,40) returning id into cups;
  insert into public.menu_items(category_id,name,description,sort_order) values(c,'Colombia Espresso','Caramel sweetness, bright citrus and a clean finish.',1) returning id into i;
  insert into public.item_variants(item_id,name,price,is_default) values(i,'Regular',750,true) returning id into v;
  insert into public.variant_recipes(variant_id,inventory_item_id,quantity) values(v,beans,18),(v,cups,1);
  raise notice 'Development store id: %',s;
end $$;
