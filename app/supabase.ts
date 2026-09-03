export type BackendMenuItem = {
  dbId: number;
  id: string;
  name: string;
  short: string;
  description: string;
  price: number;
  category: string;
  image: "coffee" | "cold" | "food";
  available: boolean;
  popular: boolean;
  coffee: boolean;
};

export type BackendOrderLine = {
  menuItemId: number;
  quantity: number;
  customizable: boolean;
  modifiers: {
    size: string;
    temperature: string;
    milk: string;
    sweetness: string;
    shots: number;
    flavour: string;
    note: string;
  };
};

type Catalog = {
  storeId: number;
  menu: BackendMenuItem[];
  modifierIds: Record<string, number>;
};

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, { ...init, headers: { "Content-Type": "application/json", ...(init?.headers || {}) } });
  if (!response.ok) {
    const body = await response.json().catch(() => ({}));
    throw new Error(body.message || body.error_description || "The order service could not complete that request.");
  }
  return response.json() as Promise<T>;
}

const modifierKey = (group: string, option: string) => `${group.trim().toLowerCase()}:${option.trim().toLowerCase()}`;

export async function loadPublicCatalog(): Promise<Catalog> {
  return request<Catalog>("/api/catalog");
}

function selectedModifierIds(line: BackendOrderLine, modifierIds: Record<string, number>) {
  if (!line.customizable) return [];
  const selections: Array<[string, string]> = [
    ["size", line.modifiers.size],
    ["temperature", line.modifiers.temperature],
    ["milk", line.modifiers.milk],
    ["sweetness", line.modifiers.sweetness],
    ["shots", `${line.modifiers.shots} ${line.modifiers.shots === 1 ? "shot" : "shots"}`],
    ["flavour", line.modifiers.flavour],
  ];
  return selections.map(([group, option]) => modifierIds[modifierKey(group, option)]).filter((id): id is number => Boolean(id));
}

export async function placeCustomerOrder(input: {
  storeId: number;
  modifierIds: Record<string, number>;
  customerName: string;
  customerPhone: string;
  channel: "pickup" | "dine_in" | "delivery";
  paymentMethod: "cash" | "mmg" | "card" | "pay_at_counter";
  deliveryAddress?: string;
  notes?: string;
  lines: BackendOrderLine[];
}) {
  const rows = await request<Array<{ order_id: number; order_number: string; total: number | string }>>("/api/orders", {
    method: "POST",
    body: JSON.stringify({
      storeId: input.storeId,
      customerName: input.customerName,
      customerPhone: input.customerPhone,
      channel: input.channel,
      paymentMethod: input.paymentMethod,
      items: input.lines.map(line => ({
        menu_item_id: line.menuItemId,
        quantity: line.quantity,
        modifier_option_ids: selectedModifierIds(line, input.modifierIds),
        special_instructions: line.modifiers.note || null,
      })),
      deliveryAddress: input.deliveryAddress || null,
      customerNotes: input.notes || null,
    }),
  });
  if (!rows[0]) throw new Error("The order service returned no confirmation.");
  return { id: rows[0].order_number, total: Number(rows[0].total) };
}
