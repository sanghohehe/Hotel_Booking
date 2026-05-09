import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4?target=denonext";

// ─── Types ─────────────────────────────────────────────────────────────────────
type Role = "user" | "assistant";

type ChatReq = {
  message: string;
  history?: Array<{ role: Role; content: string }>;
  context?: {
    city?: string;
    hotel_id?: string;
    room_type_id?: string;
    booking_id?: string;
    check_in?: string;   // YYYY-MM-DD
    check_out?: string;  // YYYY-MM-DD
    guests?: number;
    min_rating?: number;
  };
};

// ─── Intent enum ────────────────────────────────────────────────────────────────
type Intent =
  | "hotel_search"
  | "check_availability"
  | "create_booking"
  | "list_bookings"
  | "cancel_booking"
  | "reschedule_booking"
  | "general_chat"
  | "out_of_scope";

// ─── Helpers ────────────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function money(v: unknown): string {
  const n = Number(v ?? 0);
  if (Number.isNaN(n)) return String(v ?? "0");
  return n.toLocaleString("vi-VN") + "đ";
}

function daysBetween(checkIn: string, checkOut: string): number {
  const a = new Date(checkIn + "T00:00:00Z").getTime();
  const b = new Date(checkOut + "T00:00:00Z").getTime();
  return Math.max(1, Math.round(Math.max(0, b - a) / 86_400_000));
}

function extractDates(text: string): { check_in?: string; check_out?: string } {
  const matches = (text || "").match(/\d{4}-\d{2}-\d{2}/g) ?? [];
  if (matches.length >= 2) return { check_in: matches[0], check_out: matches[1] };
  if (matches.length === 1) return { check_in: matches[0] };
  return {};
}

function extractCity(text: string): string | null {
  const m = text.match(/(?:ở|tại|tìm|khách sạn)\s+([^\n,.;!?0-9]{2,30})/i);
  return m?.[1]?.trim() ?? null;
}

// ─── Intent Detection ────────────────────────────────────────────────────────────
/**
 * Phát hiện intent từ tin nhắn người dùng (không cần gọi AI thêm).
 * Trả về intent với độ chính xác cao để route xử lý đúng.
 */
function detectIntent(message: string, ctx: ChatReq["context"]): Intent {
  const t = message.toLowerCase().trim();

  // Exact command shortcuts
  if (t === "list_bookings") return "list_bookings";
  if (t === "cancel_booking") return "cancel_booking";
  if (t === "reschedule_booking") return "reschedule_booking";
  if (t === "book") return "create_booking";

  // Cancel patterns
  if (/hủy\s*(booking|đặt phòng|đơn)|cancel\s*booking/.test(t)) return "cancel_booking";

  // Reschedule patterns
  if (/đổi\s*ngày|dời\s*ngày|reschedule|thay đổi\s*ngày/.test(t)) return "reschedule_booking";

  // Booking creation
  if (/đặt\s*phòng|đặt\s*ngay|tạo\s*booking|book\s*now|xác\s*nhận\s*đặt/.test(t)) return "create_booking";

  // My bookings
  if (
    /booking\s*của\s*tôi|đơn\s*đặt|lịch\s*sử\s*đặt|my\s*booking|đặt\s*phòng\s*của\s*tôi/.test(t)
  ) return "list_bookings";

  // Availability
  if (/còn\s*phòng|available|phòng\s*trống|kiểm\s*tra\s*phòng|check\s*phòng|xem\s*phòng/.test(t)) {
    return "check_availability";
  }

  // Hotel search
  if (
    /tìm\s*khách\s*sạn|khách\s*sạn\s*(ở|tại)|hotel\s*(ở|tại)|tìm\s*hotel|gợi\s*ý\s*khách\s*sạn/.test(t)
  ) return "hotel_search";

  // Out of scope check
  const hotelKeywords = [
    "hotel","khách sạn","phòng","room","đặt phòng","booking",
    "check.?in","check.?out","thanh toán","payment","hủy","cancel",
    "đổi ngày","giá","price","rating","sao","thành phố","city",
    "còn phòng","available","trống","đêm","night",
  ];
  const inScope = hotelKeywords.some((k) => new RegExp(k, "i").test(t));
  if (!inScope) return "out_of_scope";

  return "general_chat";
}

// ─── Groq caller ─────────────────────────────────────────────────────────────────
async function callGroq(args: {
  apiKey: string;
  model: string;
  systemPrompt: string;
  userMessage: string;
  history?: Array<{ role: Role; content: string }>;
  dataContext?: unknown;
  maxTokens?: number;
}): Promise<string> {
  const { apiKey, model, systemPrompt, userMessage, history, dataContext, maxTokens = 800 } = args;

  const messages: Array<{ role: string; content: string }> = [
    { role: "system", content: systemPrompt },
  ];

  // Inject last N turns of history (tránh token bloat)
  if (history?.length) {
    for (const h of history.slice(-8)) {
      messages.push({ role: h.role, content: h.content });
    }
  }

  // Inject data context ngay trước tin nhắn user
  if (dataContext !== undefined) {
    messages.push({
      role: "system",
      content: `[DỮ LIỆU THỰC TỪ DATABASE]\n${JSON.stringify(dataContext, null, 2)}\n[TUYỆT ĐỐI không bịa dữ liệu ngoài phần trên]`,
    });
  }

  messages.push({ role: "user", content: userMessage });

  const resp = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      temperature: 0.3,          // Tăng nhẹ để trả lời tự nhiên hơn
      max_tokens: maxTokens,
      top_p: 0.9,
      frequency_penalty: 0.2,    // Giảm lặp từ
      messages,
    }),
  });

  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Groq ${resp.status}: ${txt}`);
  }

  const j = await resp.json();
  return (j?.choices?.[0]?.message?.content ?? "").trim();
}

// ─── System Prompts ───────────────────────────────────────────────────────────────
function buildSystemPrompt(userEmail: string): string {
  return `Bạn là **Travel AI Assistant** — trợ lý thông minh của ứng dụng booking khách sạn.

## VAI TRÒ
- Giúp người dùng tìm khách sạn, kiểm tra phòng trống, đặt phòng, xem/hủy/đổi booking.
- CHỈ trả lời về lĩnh vực: khách sạn, đặt phòng, du lịch, thanh toán, hướng dẫn dùng app.

## QUY TẮC QUAN TRỌNG
1. KHÔNG bịa dữ liệu. Nếu thiếu thông tin thực → hỏi lại người dùng.
2. Nếu dữ liệu DB rỗng/null → nói rõ "không có kết quả" thay vì bịa.
3. Trả lời tiếng Việt, thân thiện, ngắn gọn (tối đa 3-4 câu trừ khi cần liệt kê).
4. Dùng emoji hợp lý để thân thiện hơn (không lạm dụng).
5. Nếu người dùng hỏi ngoài phạm vi → nhẹ nhàng từ chối và hướng về chủ đề đặt phòng.

## HÀNH ĐỘNG CỤ THỂ
- Tìm khách sạn: Tóm tắt kết quả, gợi ý chọn khách sạn phù hợp.
- Kiểm tra phòng: Liệt kê loại phòng, giá, số lượng còn.
- Đặt phòng: Xác nhận thông tin trước khi đặt (khách sạn, ngày, số khách, giá).
- Hủy/đổi ngày: Giải thích rõ tác động (refund, tổng tiền mới).

## THÔNG TIN NGƯỜI DÙNG
Email: ${userEmail}

## FORMAT
- Dùng bullet points (•) khi liệt kê nhiều mục.
- In đậm **tên khách sạn**, **tổng tiền**, **ngày** quan trọng.
- Kết thúc bằng câu hỏi gợi ý hành động tiếp theo nếu phù hợp.`;
}

// ─── Main Handler ─────────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") return json({ ok: true });

  try {
    // ── Env ──
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const groqKey = Deno.env.get("GROQ_API_KEY")!;
    // Dùng model mạnh hơn (llama-3.3-70b) nếu có, fallback về 8b
    const groqModel = Deno.env.get("GROQ_MODEL") ?? "llama-3.3-70b-versatile";

    // ── Auth ──
    const authHeader = req.headers.get("Authorization") ?? "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return json({ reply: "🔒 Bạn cần đăng nhập trước khi dùng chatbot." }, 401);
    }

    // ── Parse body ──
    const body = (await req.json()) as ChatReq;
    const message = body?.message?.trim() ?? "";
    const history = body?.history ?? [];
    const ctx = body?.context ?? {};

    if (!message) return json({ reply: "Bạn hãy nhập câu hỏi nhé 😊" }, 400);

    // ── Supabase client (user-scoped) ──
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabase.auth.getUser();
    if (userErr || !userData?.user) {
      return json({ reply: "Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại." }, 401);
    }
    const user = userData.user;

    // ── Resolve context params ──
    const datesFromMsg = extractDates(message);
    const check_in  = ctx.check_in  ?? datesFromMsg.check_in;
    const check_out = ctx.check_out ?? datesFromMsg.check_out;
    const guests    = Math.max(1, Number(ctx.guests ?? 1));
    const hotelId   = ctx.hotel_id ?? null;
    const roomTypeId = ctx.room_type_id ?? null;
    const bookingId  = ctx.booking_id ?? null;

    // ── Detect intent ──
    const intent = detectIntent(message, ctx);

    // ─────────────────────────────────────────────────────────────────────────────
    // OUT OF SCOPE
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "out_of_scope") {
      return json({
        reply: "😊 Mình chỉ hỗ trợ các câu hỏi về **khách sạn, đặt phòng và du lịch**. Bạn muốn tìm khách sạn ở đâu không?",
      });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // CANCEL BOOKING
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "cancel_booking") {
      if (!bookingId) {
        return json({ reply: "Bạn muốn hủy booking nào? Vui lòng cung cấp mã booking." });
      }

      const { data: b, error: bErr } = await supabase
        .from("bookings")
        .select("id, user_id, status, payment_status, check_in, check_out, total_price")
        .eq("id", bookingId)
        .maybeSingle();

      if (bErr || !b) return json({ reply: "❌ Không tìm thấy booking này." }, 404);
      if (b.user_id !== user.id) return json({ reply: "🚫 Bạn không có quyền hủy booking này." }, 403);
      if (String(b.status) === "cancelled") return json({ reply: "ℹ️ Booking này đã được hủy trước đó rồi." });

      const newPaymentStatus = String(b.payment_status) === "paid" ? "refunded" : "canceled";

      const { data: updated, error: upErr } = await supabase
        .from("bookings")
        .update({ status: "cancelled", payment_status: newPaymentStatus })
        .eq("id", bookingId)
        .select("id, status, payment_status")
        .maybeSingle();

      if (upErr) return json({ reply: `❌ Hủy booking thất bại: ${upErr.message}` }, 500);

      return json({
        type: "booking_cancelled",
        reply:
          `✅ **Đã hủy booking thành công!**\n\n` +
          `• Mã booking: ${bookingId}\n` +
          `• Ngày: ${b.check_in} → ${b.check_out}\n` +
          `• Trạng thái: Đã hủy\n` +
          `• Thanh toán: ${newPaymentStatus === "refunded" ? "Sẽ hoàn tiền" : "Không phát sinh phí"}\n\n` +
          `Bạn có muốn tìm đặt khách sạn khác không?`,
        booking: updated,
      });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // RESCHEDULE BOOKING
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "reschedule_booking") {
      if (!bookingId) return json({ reply: "Bạn muốn đổi ngày booking nào? Vui lòng cung cấp mã booking." });
      if (!check_in || !check_out) {
        return json({ reply: "📅 Bạn muốn đổi sang ngày nào? Vui lòng cung cấp ngày check-in và check-out mới." });
      }

      const { data: b, error: bErr } = await supabase
        .from("bookings")
        .select("id, user_id, status, payment_status, hotel_id, room_type_id, guests_adults")
        .eq("id", bookingId)
        .maybeSingle();

      if (bErr || !b) return json({ reply: "❌ Không tìm thấy booking này." }, 404);
      if (b.user_id !== user.id) return json({ reply: "🚫 Bạn không có quyền chỉnh sửa booking này." }, 403);
      if (String(b.status) === "cancelled") return json({ reply: "❌ Booking đã hủy, không thể đổi ngày." });

      const g = Number(ctx.guests ?? b.guests_adults ?? 1);

      // Kiểm tra phòng còn không cho ngày mới (v3 → v2 fallback)
      let avail: any[] = [];
      const { data: v3Data, error: v3Err } = await supabase.rpc("get_available_room_types_v3", {
        p_hotel_id: b.hotel_id,
        p_check_in: check_in,
        p_check_out: check_out,
        p_guests: g,
        p_exclude_booking_id: bookingId,
      });

      if (!v3Err) {
        avail = v3Data ?? [];
      } else {
        const { data: v2Data, error: v2Err } = await supabase.rpc("get_available_room_types_v2", {
          p_hotel_id: b.hotel_id,
          p_check_in: check_in,
          p_check_out: check_out,
          p_guests: g,
        });
        if (v2Err) return json({ reply: `❌ Lỗi kiểm tra phòng: ${v2Err.message}` }, 500);
        avail = v2Data ?? [];
      }

      const row = avail.find((r: any) => String(r.room_type_id ?? r.id) === String(b.room_type_id));
      if (!row) return json({ reply: "😔 Loại phòng bạn đặt không khả dụng cho ngày mới này." });
      if (Number(row.available_rooms ?? 0) <= 0) {
        return json({ reply: "😔 Rất tiếc, loại phòng này đã hết chỗ cho ngày bạn chọn." });
      }

      // Tính lại giá
      let pricePerNight = row.price_per_night;
      if (pricePerNight == null) {
        const { data: rt } = await supabase
          .from("room_types")
          .select("price_per_night")
          .eq("id", b.room_type_id)
          .maybeSingle();
        pricePerNight = rt?.price_per_night;
      }

      const nights = daysBetween(check_in, check_out);
      const totalPrice = Number(pricePerNight ?? 0) * nights;

      const { data: updated, error: upErr } = await supabase
        .from("bookings")
        .update({ check_in, check_out, total_price: totalPrice })
        .eq("id", bookingId)
        .select("id, check_in, check_out, total_price")
        .maybeSingle();

      if (upErr) return json({ reply: `❌ Đổi ngày thất bại: ${upErr.message}` }, 500);

      return json({
        type: "booking_rescheduled",
        reply:
          `✅ **Đã đổi ngày thành công!**\n\n` +
          `• Ngày mới: **${check_in} → ${check_out}** (${nights} đêm)\n` +
          `• Tổng tiền mới: **${money(totalPrice)}**\n\n` +
          `Nếu cần thay đổi gì thêm, mình luôn sẵn sàng hỗ trợ! 😊`,
        booking: updated,
      });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // CREATE BOOKING
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "create_booking") {
      // Validate đủ thông tin trước khi tạo
      const missing: string[] = [];
      if (!hotelId) missing.push("khách sạn");
      if (!roomTypeId) missing.push("loại phòng");
      if (!check_in || !check_out) missing.push("ngày check-in/check-out");

      if (missing.length > 0) {
        return json({
          reply: `Để đặt phòng, bạn cần cung cấp thêm: **${missing.join(", ")}**. Bạn muốn mình giúp tìm không? 😊`,
        });
      }

      // Kiểm tra phòng còn không
      let avail: any[] = [];
      const { data: v2Data, error: v2Err } = await supabase.rpc("get_available_room_types_v2", {
        p_hotel_id: hotelId,
        p_check_in: check_in,
        p_check_out: check_out,
        p_guests: guests,
      });

      if (!v2Err) {
        avail = v2Data ?? [];
      } else {
        const { data: v1Data, error: v1Err } = await supabase.rpc("get_available_room_types", {
          p_hotel_id: hotelId,
          p_check_in: check_in,
          p_check_out: check_out,
          p_guests: guests,
        });
        if (v1Err) return json({ reply: `❌ Lỗi kiểm tra phòng: ${v1Err.message}` }, 500);
        avail = v1Data ?? [];
      }

      const row = avail.find((r: any) => String(r.room_type_id ?? r.id) === String(roomTypeId));
      if (!row) return json({ reply: "❌ Loại phòng không hợp lệ hoặc không còn trống." });
      if (Number(row.available_rooms ?? 0) <= 0) {
        return json({ reply: "😔 Rất tiếc, loại phòng này đã hết chỗ cho khoảng thời gian bạn chọn." });
      }

      // Lấy giá
      let pricePerNight = row.price_per_night;
      if (pricePerNight == null) {
        const { data: rt } = await supabase
          .from("room_types")
          .select("price_per_night")
          .eq("id", roomTypeId)
          .maybeSingle();
        pricePerNight = rt?.price_per_night;
      }

      const nights = daysBetween(check_in, check_out);
      const totalPrice = Number(pricePerNight ?? 0) * nights;

      const { data: booking, error: insErr } = await supabase
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

      if (insErr) return json({ reply: `❌ Tạo booking thất bại: ${insErr.message}` }, 500);

      return json({
        type: "booking_created",
        reply:
          `🎉 **Đặt phòng thành công!**\n\n` +
          `• Mã booking: \`${booking?.id}\`\n` +
          `• Check-in: **${check_in}**\n` +
          `• Check-out: **${check_out}** (${nights} đêm)\n` +
          `• Số khách: ${guests} người\n` +
          `• Tổng tiền: **${money(totalPrice)}**\n` +
          `• Trạng thái: Chờ thanh toán\n\n` +
          `Bạn có thể xem chi tiết trong **"Booking của tôi"**. Chúc bạn có chuyến đi vui vẻ! ✈️`,
        booking,
      });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // LIST BOOKINGS
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "list_bookings") {
      const { data, error } = await supabase
        .from("bookings")
        .select(`
          id, hotel_id, room_type_id, check_in, check_out, total_price,
          status, payment_status, created_at, guests_adults, guests_children,
          hotels(name, city),
          room_types(name, price_per_night)
        `)
        .order("created_at", { ascending: false })
        .limit(20);

      if (error) return json({ reply: `❌ Không thể lấy danh sách booking: ${error.message}` }, 500);

      const rows = data ?? [];
      if (rows.length === 0) {
        return json({
          reply: "📋 Bạn chưa có booking nào.\n\nBạn muốn tìm khách sạn để đặt phòng không? 😊",
        });
      }

      const statusEmoji: Record<string, string> = {
        confirmed: "✅",
        pending: "⏳",
        cancelled: "❌",
        completed: "🏁",
      };

      const replyLines = rows.slice(0, 6).map((b: any, i: number) => {
        const emoji = statusEmoji[String(b.status)] ?? "📌";
        return (
          `${i + 1}. ${emoji} **${b.hotels?.name ?? "Hotel"}** — ${b.room_types?.name ?? "Phòng"}\n` +
          `   📅 ${b.check_in} → ${b.check_out} | 💰 ${money(b.total_price)}`
        );
      });

      const moreText = rows.length > 6 ? `\n\n...và ${rows.length - 6} booking khác.` : "";

      return json({
        type: "bookings_list",
        reply: `📋 **Booking của bạn** (${rows.length} đơn):\n\n` + replyLines.join("\n\n") + moreText,
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

    // ─────────────────────────────────────────────────────────────────────────────
    // CHECK AVAILABILITY
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "check_availability") {
      if (!hotelId) {
        return json({ reply: "Bạn muốn kiểm tra phòng trống của khách sạn nào? Hãy chọn khách sạn trước nhé." });
      }
      if (!check_in || !check_out) {
        return json({ reply: "📅 Bạn muốn ở từ ngày nào đến ngày nào? Vui lòng cung cấp ngày check-in và check-out." });
      }

      let avail: any[] = [];
      const { data: v2Data, error: v2Err } = await supabase.rpc("get_available_room_types_v2", {
        p_hotel_id: hotelId,
        p_check_in: check_in,
        p_check_out: check_out,
        p_guests: guests,
      });

      if (!v2Err) {
        avail = v2Data ?? [];
      } else {
        const { data: v1Data, error: v1Err } = await supabase.rpc("get_available_room_types", {
          p_hotel_id: hotelId,
          p_check_in: check_in,
          p_check_out: check_out,
          p_guests: guests,
        });
        if (v1Err) return json({ reply: `❌ Lỗi kiểm tra phòng: ${v1Err.message}` }, 500);
        avail = v1Data ?? [];
      }

      if (avail.length === 0) {
        return json({
          reply: `😔 Không có phòng trống cho **${guests} khách** trong khoảng **${check_in} → ${check_out}**.\n\nBạn thử đổi ngày hoặc chọn khách sạn khác nhé?`,
          availability: [],
        });
      }

      const nights = daysBetween(check_in, check_out);
      const lines = avail.map((r: any) => {
        const total = r.price_per_night ? money(Number(r.price_per_night) * nights) : "";
        return `• **${r.name}** — ${r.available_rooms}/${r.inventory} phòng còn | ${money(r.price_per_night)}/đêm${total ? ` (${nights} đêm = ${total})` : ""}`;
      });

      return json({
        type: "availability",
        reply:
          `🛏 **Phòng trống** (${check_in} → ${check_out}, ${nights} đêm, ${guests} khách):\n\n` +
          lines.join("\n") +
          `\n\nBấm **Đặt ngay** để xác nhận phòng bạn muốn! 😊`,
        availability: avail,
      });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // HOTEL SEARCH
    // ─────────────────────────────────────────────────────────────────────────────
    if (intent === "hotel_search") {
      const city = ctx.city ?? extractCity(message);

      let query = supabase
        .from("hotels")
        .select("id, name, city, address, star_rating, thumbnail_url, image_url")
        .order("star_rating", { ascending: false })
        .limit(10);

      if (city) query = query.ilike("city", `%${city}%`);
      if (ctx.min_rating) query = query.gte("star_rating", ctx.min_rating);

      const { data, error } = await query;
      if (error) return json({ reply: `❌ Lỗi tìm kiếm: ${error.message}` }, 500);

      const hotels = data ?? [];
      if (hotels.length === 0) {
        return json({
          reply: city
            ? `😔 Hiện chưa có khách sạn nào ở **${city}** trong hệ thống.\n\nBạn thử tìm ở Hà Nội, Đà Nẵng hoặc TP.HCM nhé?`
            : "Bạn muốn tìm khách sạn ở thành phố nào? Mình hỗ trợ Hà Nội, Đà Nẵng, TP.HCM và nhiều nơi khác.",
        });
      }

      const lines = hotels.map((h: any) => {
        const stars = h.star_rating ? "⭐".repeat(Math.min(5, h.star_rating)) : "";
        return `• **${h.name}** ${stars}\n  📍 ${h.city ?? ""}${h.address ? " — " + h.address : ""}`;
      });

      return json({
        type: "hotel_search",
        reply:
          `🏨 Tìm thấy **${hotels.length} khách sạn**${city ? ` ở **${city}**` : ""}:\n\n` +
          lines.join("\n\n") +
          `\n\nBấm vào khách sạn để chọn ngày và kiểm tra phòng trống! 📅`,
        hotels,
      });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // GENERAL CHAT → Groq
    // ─────────────────────────────────────────────────────────────────────────────
    const dataContext = {
      current_context: {
        hotel_id: hotelId,
        room_type_id: roomTypeId,
        booking_id: bookingId,
        check_in,
        check_out,
        guests,
        city: ctx.city ?? null,
      },
    };

    const reply = await callGroq({
      apiKey: groqKey,
      model: groqModel,
      systemPrompt: buildSystemPrompt(user.email ?? ""),
      userMessage: message,
      history,
      dataContext,
      maxTokens: 600,
    });

    return json({ reply });

  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error("[chatbot-error]", msg);
    return json(
      {
        reply: "⚠️ Có lỗi xảy ra, vui lòng thử lại sau. Nếu lỗi tiếp diễn, hãy liên hệ hỗ trợ.",
        error: msg,
      },
      500,
    );
  }
});