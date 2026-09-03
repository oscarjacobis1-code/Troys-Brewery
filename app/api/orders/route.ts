import { apiError, supabaseRequest } from "../_supabase";

type OrderPayload = {
  storeId: number;
  customerName: string;
  customerPhone: string;
  channel: "pickup" | "dine_in" | "delivery";
  paymentMethod: "cash" | "mmg" | "card" | "pay_at_counter";
  items: Array<{ menu_item_id: number; quantity: number; modifier_option_ids: number[]; special_instructions?: string | null }>;
  deliveryAddress?: string | null;
  customerNotes?: string | null;
};

export async function POST(request: Request) {
  try {
    const input = await request.json() as OrderPayload;
    if (!Number.isInteger(input.storeId) || !Array.isArray(input.items) || !input.items.length) {
      return Response.json({ message: "The order details are incomplete." }, { status: 400 });
    }
    const rows = await supabaseRequest<Array<{ order_id: number; order_number: string; total: number | string }>>("rpc/place_order", {
      method: "POST",
      body: JSON.stringify({
        p_store_id: input.storeId,
        p_customer_name: input.customerName,
        p_customer_phone: input.customerPhone,
        p_channel: input.channel,
        p_payment_method: input.paymentMethod,
        p_items: input.items,
        p_delivery_address: input.deliveryAddress || null,
        p_customer_notes: input.customerNotes || null,
      }),
    });
    return Response.json(rows);
  } catch (error) {
    return apiError(error);
  }
}
