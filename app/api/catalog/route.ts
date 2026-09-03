import { apiError, supabaseRequest } from "../_supabase";

export async function GET() {
  try {
    const [stores, items, groups, options] = await Promise.all([
      supabaseRequest<Array<{ id: number }>>("stores?select=id&slug=eq.ogle&is_active=eq.true&limit=1"),
      supabaseRequest<Array<{
        id: number; slug: string; name: string; short_description: string | null; description: string | null;
        base_price: number | string; image_key: "coffee" | "cold" | "food"; is_available: boolean;
        is_popular: boolean; supports_customization: boolean; menu_categories: { name: string } | null;
      }>>("menu_items?select=id,slug,name,short_description,description,base_price,image_key,is_available,is_popular,supports_customization,menu_categories(name)&order=name.asc"),
      supabaseRequest<Array<{ id: number; slug: string }>>("modifier_groups?select=id,slug&is_active=eq.true"),
      supabaseRequest<Array<{ id: number; group_id: number; name: string }>>("modifier_options?select=id,group_id,name&is_available=eq.true"),
    ]);
    if (!stores[0]) return Response.json({ message: "The Ogle store is not available." }, { status: 503 });
    const groupSlugs = new Map(groups.map(group => [group.id, group.slug]));
    const modifierIds = Object.fromEntries(options.flatMap(option => {
      const group = groupSlugs.get(option.group_id);
      return group ? [[`${group}:${option.name.trim().toLowerCase()}`, option.id]] : [];
    }));
    return Response.json({
      storeId: stores[0].id,
      modifierIds,
      menu: items.map(item => ({
        dbId: item.id,
        id: item.slug,
        name: item.name,
        short: item.short_description || "",
        description: item.description || "",
        price: Number(item.base_price),
        category: item.menu_categories?.name || "Menu",
        image: item.image_key,
        available: item.is_available,
        popular: item.is_popular,
        coffee: item.supports_customization,
      })),
    });
  } catch (error) {
    return apiError(error);
  }
}
