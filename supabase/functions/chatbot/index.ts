import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4?target=denonext";

type ChatReq = {
  message: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
  context?: {
    city?: string;
    hotel_id?: string;
    room_type_id?: string;

    booking_id?: string;

    check_in?: string; // YYYY-MM-DD
    check_out?: string; // YYYY-MM-DD
    guests?: number;

    min_rating?: number;
  };
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function inScope(text: string): boolean {
  const t = (text || "").toLowerCase();
  const keywords = [
    "hotel",
    "khách sạn",
    "phòng",
    "room",
    "room type",
    "đặt phòng",
    "booking",
    "check in",
    "check-in",
    "check out",
    "check-out",
    "thanh toán",
    "payment",
    "hủy",
    "cancel",
    "đổi ngày",
    "reschedule",
    "giá",
    "price",
    "rating",
    "sao",
    "địa chỉ",
    "city",
    "thành phố",
    "còn phòng",
    "available",
  ];
  return keywords.some((k) => t.includes(k));
}

function wantsMyBookings(text: string): boolean {
  const t = (text || "").toLowerCase();
  return (
    t.includes("booking của tôi") ||
    t.includes("đơn đặt") ||
    t.includes("đặt phòng của tôi") ||
    t.includes("lịch sử đặt") ||
    t.includes("my booking") ||
    t === "list_bookings"
  );
}

function wantsAvailability(text: string): boolean {
  const t = (text || "").toLowerCase();
  return (
    t.includes("còn phòng") ||
    t.includes("available") ||
    t.includes("trống") ||
    t.includes("kiểm tra phòng") ||
    t.includes("check phòng")
  );
}

function wantsHotelSearch(text: string): boolean {
  const t = (text || "").toLowerCase();
  return (
    t.includes("tìm khách sạn") ||
    t.includes("khách sạn ở") ||
    t.includes("khách sạn tại") ||
    t.includes("hotel ở") ||
    t.includes("hotel tại")
  );
}

function wantsCreateBooking(text: string): boolean {
  const t = (text || "").toLowerCase();
  return (
    t.includes("đặt phòng") ||
    t.includes("đặt ngay") ||
    t.includes("tạo booking") ||
    t.includes("book now") ||
    t === "book"
  );
}

function wantsCancelBooking(text: string): boolean {
  const t = (text || "").toLowerCase();
  return t === "cancel_booking";
}

function wantsRescheduleBooking(text: string): boolean {
  const t = (text || "").toLowerCase();
  return t === "reschedule_booking";
}

function extractCity(text: string): string | null {
  const t = (text || "").trim();
  const m = t.match(/(?:ở|tại)\s+([^\n,.;!?]+)/i);
  if (m && m[1]) return m[1].trim();
  return null;
}

function extractDates(text: string): { check_in?: string; check_out?: string } {
  const matches = (text || "").match(/\d{4}-\d{2}-\d{2}/g) || [];
  if (matches.length >= 2) return { check_in: matches[0], check_out: matches[1] };
  if (matches.length === 1) return { check_in: matches[0] };
  return {};
}

function money(v: unknown): string {
  const n = Number(v ?? 0);
  if (Number.isNaN(n)) return String(v ?? "0");
  return n.toLocaleString("vi-VN") + "đ";
}

function daysBetween(checkIn: string, checkOut: string): number {
  const a = new Date(checkIn + "T00:00:00Z").getTime();
  const b = new Date(checkOut + "T00:00:00Z").getTime();
  const diff = Math.max(0, b - a);
  return Math.max(1, Math.round(diff / (1000 * 60 * 60 * 24)));
}

async function callGroq(args: {
  apiKey: string;
  model: string;
  system: string;
  user: string;
  history?: Array<{ role: "user" | "assistant"; content: string }>;
  dataContext: unknown;
}) {
  const { apiKey, model, system, user, history, dataContext } = args;

  const messages: Array<{ role: string; content: string }> = [
    { role: "system", content: system },
  ];

  if (history?.length) {
    for (const h of history.slice(-10)) {
      messages.push({ role: h.role, content: h.content });
    }
  }

  messages.push({
    role: "system",
    content:
      "Dữ liệu hệ thống (DB/RPC) để bạn dựa vào khi trả lời. Nếu mảng rỗng / null => coi như KHÔNG có dữ liệu. TUYỆT ĐỐI không bịa.\n" +
      JSON.stringify(dataContext),
  });

  messages.push({ role: "user", content: user });

  const resp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.2,
      messages,
    }),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Groq error ${resp.status}: ${txt}`);
  }

  const j = await resp.json();
  const content = j?.choices?.[0]?.message?.content ?? "";
  return content.trim();
}

serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true }, 200);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const groqKey = Deno.env.get("GROQ_API_KEY")!;
    const groqModel = Deno.env.get("GROQ_MODEL") ?? "llama-3.1-8b-instant";

    const authHeader = req.headers.get("Authorization") || "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return json({ reply: "Bạn cần đăng nhập trước khi dùng chatbot." }, 401);
    }

    const body = (await req.json()) as ChatReq;
    const message = body?.message?.trim() ?? "";
    const history = body?.history ?? [];
    const ctx = body?.context ?? {};

    if (!message) return json({ reply: "Bạn hãy nhập câu hỏi nhé." }, 400);

    if (!inScope(message) && !wantsMyBookings(message) && !wantsCancelBooking(message) && !wantsRescheduleBooking(message)) {
      return json({
        reply:
          "Mình chỉ hỗ trợ các câu hỏi liên quan đến booking_app và đặt phòng/khách sạn.",
      });
    }

    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ reply: "Phiên đăng nhập không hợp lệ, hãy đăng nhập lại." }, 401);
    }
    const user = userData.user;

    const datesFromMsg = extractDates(message);
    const check_in = ctx.check_in ?? datesFromMsg.check_in;
    const check_out = ctx.check_out ?? datesFromMsg.check_out;
    const guests = Number(ctx.guests ?? 1);

    const hotelId = ctx.hotel_id ?? null;
    const roomTypeId = ctx.room_type_id ?? null;
    const bookingId = ctx.booking_id ?? null;

    // ========= CANCEL BOOKING =========
    if (wantsCancelBooking(message)) {
      if (!bookingId) return json({ reply: "Thiếu booking_id." }, 400);

      // load booking to validate ownership + status
      const b = await supabase
        .from("bookings")
        .select("id, user_id, status, payment_status, hotel_id, room_type_id, check_in, check_out, total_price")
        .eq("id", bookingId)
        .maybeSingle();

      if (b.error || !b.data) return json({ reply: "Không tìm thấy booking." }, 404);
      if (b.data.user_id !== user.id) return json({ reply: "Bạn không có quyền hủy booking này." }, 403);
      if (String(b.data.status) === "cancelled") return json({ reply: "Booking này đã được hủy rồi." });

      const newPayment =
        String(b.data.payment_status) === "paid" ? "refunded" : "canceled";

      const up = await supabase
        .from("bookings")
        .update({
          status: "cancelled",
          payment_status: newPayment,
        })
        .eq("id", bookingId)
        .select("id, status, payment_status")
        .maybeSingle();

      if (up.error) {
        return json({ reply: `Hủy booking bị lỗi: ${up.error.message}` }, 500);
      }

      return json({
        type: "booking_cancelled",
        reply: `✅ Đã hủy booking thành công.\n• Status: cancelled\n• Payment: ${newPayment}`,
        booking: up.data,
      });
    }

    // ========= RESCHEDULE BOOKING =========
    if (wantsRescheduleBooking(message)) {
      if (!bookingId) return json({ reply: "Thiếu booking_id." }, 400);
      if (!check_in || !check_out) return json({ reply: "Thiếu ngày check-in/check-out." }, 400);

      const b = await supabase
        .from("bookings")
        .select("id, user_id, status, payment_status, hotel_id, room_type_id, guests_adults, guests_children")
        .eq("id", bookingId)
        .maybeSingle();

      if (b.error || !b.data) return json({ reply: "Không tìm thấy booking." }, 404);
      if (b.data.user_id !== user.id) return json({ reply: "Bạn không có quyền đổi ngày booking này." }, 403);
      if (String(b.data.status) === "cancelled") return json({ reply: "Booking đã hủy nên không thể đổi ngày." }, 400);

      const hId = b.data.hotel_id;
      const rtId = b.data.room_type_id;
      const g = Number(ctx.guests ?? b.data.guests_adults ?? 1);

      // check availability (prefer v3)
      let avail: any[] = [];
      const v3 = await supabase.rpc("get_available_room_types_v3", {
        p_hotel_id: hId,
        p_check_in: check_in,
        p_check_out: check_out,
        p_guests: g,
        p_exclude_booking_id: bookingId,
      });

      if (!v3.error) {
        avail = v3.data ?? [];
      } else {
        // fallback v2
        const v2 = await supabase.rpc("get_available_room_types_v2", {
          p_hotel_id: hId,
          p_check_in: check_in,
          p_check_out: check_out,
          p_guests: g,
        });
        if (v2.error) return json({ reply: `Lỗi kiểm tra phòng: ${v2.error.message}` }, 500);
        avail = v2.data ?? [];
      }

      const row = avail.find((r: any) => String(r.room_type_id ?? r.id) === String(rtId));
      if (!row) {
        return json({ reply: "Không tìm thấy loại phòng phù hợp cho ngày mới." }, 400);
      }
      if (Number(row.available_rooms ?? 0) <= 0) {
        return json({ reply: "Ngày bạn chọn hiện không còn phòng cho loại phòng này." }, 400);
      }

      // recompute total price
      let pricePerNight = row.price_per_night;
      if (pricePerNight == null) {
        const rt = await supabase
          .from("room_types")
          .select("price_per_night")
          .eq("id", rtId)
          .maybeSingle();
        if (!rt.error) pricePerNight = rt.data?.price_per_night;
      }

      const nights = daysBetween(check_in, check_out);
      const totalPrice = Number(pricePerNight ?? 0) * nights;

      const up = await supabase
        .from("bookings")
        .update({
          check_in,
          check_out,
          total_price: totalPrice,
        })
        .eq("id", bookingId)
        .select("id, check_in, check_out, total_price")
        .maybeSingle();

      if (up.error) return json({ reply: `Đổi ngày bị lỗi: ${up.error.message}` }, 500);

      return json({
        type: "booking_rescheduled",
        reply:
          `✅ Đã đổi ngày booking.\n` +
          `• Ngày mới: ${check_in} → ${check_out} (${nights} đêm)\n` +
          `• Tổng tiền: ${money(totalPrice)}`,
        booking: up.data,
      });
    }

    // ---------- CREATE BOOKING ----------
    if (wantsCreateBooking(message)) {
      if (!hotelId) return json({ reply: "Thiếu hotel_id (hãy chọn khách sạn)." }, 400);
      if (!roomTypeId) return json({ reply: "Thiếu room_type_id (hãy chọn phòng)." }, 400);
      if (!check_in || !check_out) return json({ reply: "Thiếu ngày check-in/check-out." }, 400);

      const v2 = await supabase.rpc("get_available_room_types_v2", {
        p_hotel_id: hotelId,
        p_check_in: check_in,
        p_check_out: check_out,
        p_guests: guests,
      });

      let avail: any[] = [];
      if (!v2.error) {
        avail = v2.data ?? [];
      } else {
        const v1 = await supabase.rpc("get_available_room_types", {
          p_hotel_id: hotelId,
          p_check_in: check_in,
          p_check_out: check_out,
          p_guests: guests,
        });
        if (v1.error) return json({ reply: `Lỗi kiểm tra phòng: ${v1.error.message}` }, 500);
        avail = v1.data ?? [];
      }

      const row = avail.find((r: any) => String(r.room_type_id ?? r.id) === String(roomTypeId));
      if (!row) return json({ reply: "Loại phòng không hợp lệ." }, 400);
      if (Number(row.available_rooms ?? 0) <= 0) return json({ reply: "Loại phòng này đã hết phòng." }, 400);

      let pricePerNight = row.price_per_night;
      if (pricePerNight == null) {
        const rt = await supabase
          .from("room_types")
          .select("price_per_night")
          .eq("id", roomTypeId)
          .maybeSingle();
        if (!rt.error) pricePerNight = rt.data?.price_per_night;
      }

      const nights = daysBetween(check_in, check_out);
      const totalPrice = Number(pricePerNight ?? 0) * nights;

      const ins = await supabase
        .from("bookings")
        .insert({
          user_id: user.id,
          hotel_id: hotelId,
          room_type_id: roomTypeId,
          check_in,
          check_out,
          total_price: totalPrice,
          status: "pending",
          payment_status: "unpaid",
          guests_adults: guests,
          guests_children: 0,
        })
        .select("id, check_in, check_out, total_price, status, payment_status, created_at")
        .maybeSingle();

      if (ins.error) {
        return json({ reply: "Tạo booking lỗi: " + ins.error.message }, 500);
      }

      return json({
        type: "booking_created",
        reply:
          `✅ Đã tạo booking!\n` +
          `• ID: ${ins.data?.id}\n` +
          `• Ngày: ${check_in} → ${check_out} (${nights} đêm)\n` +
          `• Tổng: ${money(ins.data?.total_price)}\n` +
          `• Status: ${String(ins.data?.status)} | Payment: ${String(ins.data?.payment_status)}`,
        booking: ins.data,
      });
    }

    // ---------- LIST BOOKINGS (return bookings array for UI) ----------
    if (wantsMyBookings(message)) {
      const { data, error } = await supabase
        .from("bookings")
        .select(`
          id, hotel_id, room_type_id, check_in, check_out, total_price, status, payment_status, created_at,
          guests_adults, guests_children,
          hotels(name, city),
          room_types(name, price_per_night)
        `)
        .order("created_at", { ascending: false })
        .limit(20);

      if (error) return json({ reply: `Không lấy được booking. (${error.message})` }, 500);

      const rows = data ?? [];
      if (rows.length === 0) return json({ reply: "Bạn chưa có booking nào." });

      const replyLines = rows.slice(0, 8).map((b: any, i: number) => {
        const hName = b.hotels?.name ?? "Hotel";
        const rName = b.room_types?.name ?? "Room";
        return `${i + 1}. ${hName} — ${rName}\n   ${b.check_in} → ${b.check_out} | ${money(b.total_price)} | ${String(b.status)}`;
      });

      return json({
        type: "bookings_list",
        reply: "Danh sách booking của bạn:\n\n" + replyLines.join("\n\n"),
        bookings: rows.map((b: any) => ({
          id: b.id,
          hotel_id: b.hotel_id,
          room_type_id: b.room_type_id,
          check_in: b.check_in,
          check_out: b.check_out,
          total_price: b.total_price,
          status: b.status,
          payment_status: b.payment_status,
          created_at: b.created_at,
          guests_adults: b.guests_adults,
          guests_children: b.guests_children,
          hotel_name: b.hotels?.name ?? null,
          hotel_city: b.hotels?.city ?? null,
          room_name: b.room_types?.name ?? null,
          price_per_night: b.room_types?.price_per_night ?? null,
        })),
      });
    }

    // ---------- AVAILABILITY ----------
    if (wantsAvailability(message)) {
      if (!hotelId) return json({ reply: "Bạn cần chọn khách sạn trước." });
      if (!check_in || !check_out) return json({ reply: "Thiếu ngày check-in/check-out." });

      const v2 = await supabase.rpc("get_available_room_types_v2", {
        p_hotel_id: hotelId,
        p_check_in: check_in,
        p_check_out: check_out,
        p_guests: guests,
      });

      let avail: any[] = [];
      if (!v2.error) {
        avail = v2.data ?? [];
      } else {
        const v1 = await supabase.rpc("get_available_room_types", {
          p_hotel_id: hotelId,
          p_check_in: check_in,
          p_check_out: check_out,
          p_guests: guests,
        });
        if (v1.error) return json({ reply: `Lỗi kiểm tra phòng: ${v1.error.message}` }, 500);
        avail = v1.data ?? [];
      }

      if (avail.length === 0) return json({ reply: "Không có loại phòng phù hợp." });

      const lines = avail.map((r: any, i: number) => {
        const price = r.price_per_night != null ? ` | ${money(r.price_per_night)}/đêm` : "";
        return `${i + 1}. ${r.name} — còn ${r.available_rooms}/${r.inventory}${price}`;
      });

      return json({
        type: "availability",
        reply:
          `Kết quả còn phòng (${check_in} → ${check_out}, ${guests} khách):\n\n` +
          lines.join("\n") +
          `\n\nBạn có thể bấm **Chọn phòng** bên dưới.`,
        availability: avail,
      });
    }

    // ---------- HOTEL SEARCH ----------
    if (wantsHotelSearch(message)) {
      const city = ctx.city ?? extractCity(message);

      let q = supabase
        .from("hotels")
        .select("id, name, city, address, star_rating, thumbnail_url, image_url")
        .order("star_rating", { ascending: false })
        .limit(10);

      if (city) q = q.ilike("city", `%${city}%`);

      const { data, error } = await q;
      if (error) return json({ reply: `Lỗi tìm khách sạn: ${error.message}` }, 500);

      const hotels = data ?? [];
      if (hotels.length === 0) {
        return json({
          reply: city
            ? `Chưa có khách sạn ở **${city}**.`
            : "Bạn muốn tìm khách sạn ở thành phố nào?",
        });
      }

      const lines = hotels.map((h: any, i: number) => {
        const rating = h.star_rating != null ? `${h.star_rating}★` : "N/A";
        const addr = (h.address ?? "").toString().trim();
        return `${i + 1}. ${h.name} (${rating}) — ${h.city ?? ""}` + (addr ? `\n   ${addr}` : "");
      });

      return json({
        type: "hotel_search",
        reply:
          `Mình tìm thấy **${hotels.length}** khách sạn` +
          (city ? ` ở **${city}**` : "") +
          `:\n\n` +
          lines.join("\n\n") +
          `\n\nBạn có thể bấm **Chọn** để chọn ngày.`,
        hotels: hotels,
      });
    }

    // ---------- OTHER -> Groq ----------
    const dataContext = {
      user: { id: user.id, email: user.email },
      request_context: { ...ctx, check_in, check_out, guests, hotel_id: hotelId, room_type_id: roomTypeId, booking_id: bookingId },
    };

    const systemPrompt =
      "Bạn là trợ lý của ứng dụng booking_app.\n" +
      "CHỈ trả lời về khách sạn/đặt phòng/thanh toán/hướng dẫn dùng app.\n" +
      "KHÔNG bịa dữ liệu. Nếu thiếu dữ liệu thật thì hỏi lại.\n" +
      "Trả lời tiếng Việt, ngắn gọn.";

    const reply = await callGroq({
      apiKey: groqKey,
      model: groqModel,
      system: systemPrompt,
      user: message,
      history,
      dataContext,
    });

    return json({ reply });
  } catch (e) {
    return json(
      {
        reply: "Chatbot lỗi xử lý. Bạn gửi mình log để sửa tiếp nhé.",
        error: String((e as any)?.message ?? e),
      },
      500,
    );
  }
});
