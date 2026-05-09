import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/chat_message_entity.dart';
import 'chatbot_state.dart';

class ChatbotCubit extends Cubit<ChatbotState> {
  final dynamic chatbotUseCase;

  final String _edgeFunctionUrl =
      'https://vangrwbliciqgrkwgmou.supabase.co/functions/v1/chatbot';

  // 2. Sửa Constructor để nhận tham số này
  ChatbotCubit(this.chatbotUseCase) : super(ChatbotState());

  // ─── Reset ────────────────────────────────────────────────────────────────
  void reset() => emit(ChatbotState());

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void updateGuests(int count) {
    emit(state.copyWith(guests: count));
    updateBotContext({'guests': count});
  }

  void onDateRangeSelected(DateTimeRange range) {
    final ci = _fmtDate(range.start);
    final co = _fmtDate(range.end);
    send(
      'còn phòng ($ci → $co)',
      contextOverride: {'check_in': ci, 'check_out': co},
    );
  }

  // ─── Flow Đặt Phòng ───────────────────────────────────────────────────────
  void selectHotel(dynamic hotel) {
    updateBotContext({'hotel_id': hotel['id'], 'hotel_name': hotel['name']});
    send(
      "Tôi đã chọn khách sạn **${hotel['name']}**, cho mình xem phòng trống nhé",
      addUserBubble: false,
    );
  }

  void bookRoom(dynamic room) {
    final roomId = room['id'] ?? room['room_type_id'];
    send(
      'đặt phòng',
      contextOverride: {
        'room_type_id': roomId,
        'hotel_id': state.botContext['hotel_id'],
      },
    );
  }

  void updateBotContext(Map<String, dynamic> updates) {
    final newCtx = Map<String, dynamic>.from(state.botContext)..addAll(updates);
    emit(state.copyWith(botContext: newCtx));
  }

  // ─── Send Message ─────────────────────────────────────────────────────────
  Future<void> send(
    String text, {
    bool addUserBubble = true,
    Map<String, dynamic>? contextOverride,
  }) async {
    if (text.isEmpty || state.isSending) return;

    final activeContext = Map<String, dynamic>.from(state.botContext);
    if (contextOverride != null) {
      activeContext.addAll(contextOverride);
      emit(state.copyWith(botContext: activeContext));
    }

    var currentMessages = List<ChatMessageEntity>.from(state.messages);
    if (addUserBubble) {
      currentMessages.add(ChatMessageEntity(role: 'user', content: text));
      emit(state.copyWith(messages: currentMessages, isSending: true));
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _appendError('Phiên đăng nhập không hợp lệ.');
      return;
    }

    final history =
        state.messages
            .map((m) => {'role': m.role, 'content': m.content})
            .toList();

    try {
      await _sendStream(
        text: text,
        history: history,
        context: activeContext,
        token: session.accessToken,
      );
    } catch (e) {
      _appendError('Lỗi kết nối: $e');
    }
  }

  Future<void> loadHistory() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) return;

      emit(state.copyWith(isSending: true));

      final res = await Supabase.instance.client
          .from('chat_messages')
          .select()
          .eq('user_id', user.id)
          .order('created_at');

      final messages =
          (res as List).map((e) {
            final metadata = e['metadata'];

            return ChatMessageEntity(
              role: e['role'] ?? 'assistant',
              content: e['message'] ?? '',
              type: metadata?['type'],
              hotels: metadata?['hotels'],
              availability: metadata?['availability'],
              bookings: metadata?['bookings'],
              booking: metadata?['booking'],
            );
          }).toList();

      emit(state.copyWith(isSending: false, messages: messages));
    } catch (e) {
      emit(state.copyWith(isSending: false));
    }
  }

  // ─── Streaming via SSE ────────────────────────────────────────────────────
  Future<void> _sendStream({
    required String text,
    required List<Map<String, dynamic>> history,
    required Map<String, dynamic> context,
    required String token,
  }) async {
    final uri = Uri.parse(_edgeFunctionUrl);
    final body = jsonEncode({
      'message': text,
      'history': history,
      'context': context,
      'stream': true,
    });

    final client = http.Client();
    try {
      final request =
          http.Request('POST', uri)
            ..headers.addAll({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            })
            ..body = body;

      final streamed = await client.send(request);

      if (streamed.statusCode != 200) {
        final errBody = await streamed.stream.bytesToString();
        _appendError('Server lỗi ${streamed.statusCode}: $errBody');
        return;
      }

      final contentType = streamed.headers['content-type'] ?? '';

      if (contentType.contains('text/event-stream')) {
        await _consumeSse(streamed.stream);
      } else {
        final raw = await streamed.stream.bytesToString();
        _handleJsonResponse(raw);
      }
    } finally {
      client.close();
    }
  }

  Future<void> _consumeSse(Stream<List<int>> byteStream) async {
    final buffer = StringBuffer();
    String accumulated = '';

    await for (final bytes in byteStream) {
      buffer.write(utf8.decode(bytes, allowMalformed: true));
      final raw = buffer.toString();
      buffer.clear();

      final lines = raw.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final payload = trimmed.substring(5).trim();

        if (payload == '[DONE]') {
          _flushStreamingText(accumulated);
          return;
        }

        try {
          final decoded = jsonDecode(payload);
          if (decoded is String) {
            accumulated += decoded;
            emit(state.copyWith(isSending: true, streamingText: accumulated));
          } else if (decoded is Map && decoded.containsKey('error')) {
            _appendError(decoded['error'].toString());
            return;
          }
        } catch (_) {}
      }
    }

    if (accumulated.isNotEmpty) _flushStreamingText(accumulated);
  }

  void _flushStreamingText(String text) {
    final finalMessages = List<ChatMessageEntity>.from(state.messages)
      ..add(ChatMessageEntity(role: 'assistant', content: text));
    emit(
      state.copyWith(
        messages: finalMessages,
        isSending: false,
        streamingText: '',
      ),
    );
  }

  // ─── Xử lý JSON Response (Cập nhật đầy đủ) ───────────────────────────────
  void _handleJsonResponse(String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? '';
      final type = data['type'] as String?;

      final msg = ChatMessageEntity(
        role: 'assistant',
        content: reply,
        type: type,
        hotels: data['hotels'] as List<dynamic>?,
        availability: data['availability'] as List<dynamic>?,
        bookings: data['bookings'] as List<dynamic>?,
      );

      final finalMessages = List<ChatMessageEntity>.from(state.messages)
        ..add(msg);

      emit(
        state.copyWith(
          messages: finalMessages,
          isSending: false,
          streamingText: '',
        ),
      );
    } catch (e) {
      _appendError('Không thể đọc phản hồi từ server.');
    }
  }

  void _appendError(String msg) {
    final finalMessages = List<ChatMessageEntity>.from(state.messages)
      ..add(ChatMessageEntity(role: 'assistant', content: '⚠️ $msg'));
    emit(
      state.copyWith(
        messages: finalMessages,
        isSending: false,
        streamingText: '',
      ),
    );
  }
}
