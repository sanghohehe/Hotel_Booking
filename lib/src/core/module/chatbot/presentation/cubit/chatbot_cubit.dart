import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/usecases/chatbot_usecase.dart';
import 'chatbot_state.dart';

class ChatbotCubit extends Cubit<ChatbotState> {
  final ChatbotUseCase useCase;

  ChatbotCubit(this.useCase) : super(ChatbotState());

  void reset() => emit(ChatbotState());

  // Logic 1: Định dạng ngày (Thay thế _fmt ở UI)
  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // Logic 2: Cập nhật số khách và đẩy vào context
  void updateGuests(int count) {
    emit(state.copyWith(guests: count));
    updateBotContext({'guests': count});
  }

  // Logic 3: Xử lý khi chọn ngày hoàn tất
  void onDateRangeSelected(DateTimeRange range) {
    final ci = _fmtDate(range.start);
    final co = _fmtDate(range.end);
    send(
      'còn phòng ($ci → $co)',
      contextOverride: {
        'check_in': ci,
        'check_out': co,
        'room_type_id': null, // Reset phòng cũ để tránh lỗi 400
      },
    );
  }

  // Logic 4: Xử lý chọn phòng (Thay thế logic bóc tách ID ở UI)
  void bookRoom(dynamic room) {
    final roomId = room['id'] ?? room['room_type_id'];
    send('đặt phòng', contextOverride: {'room_type_id': roomId});
  }

  void updateBotContext(Map<String, dynamic> updates) {
    final newCtx = Map<String, dynamic>.from(state.botContext)..addAll(updates);
    emit(state.copyWith(botContext: newCtx));
  }

  Future<void> send(
    String text, {
    bool addUserBubble = true,
    Map<String, dynamic>? contextOverride,
  }) async {
    if (text.isEmpty || state.isSending) return;

    Map<String, dynamic> activeContext = Map<String, dynamic>.from(
      state.botContext,
    );
    if (contextOverride != null) {
      activeContext.addAll(contextOverride);
      emit(state.copyWith(botContext: activeContext));
    }

    List<ChatMessageEntity> currentMessages = List.from(state.messages);
    if (addUserBubble) {
      currentMessages.add(ChatMessageEntity(role: 'user', content: text));
      emit(state.copyWith(messages: currentMessages, isSending: true));
    }

    try {
      final history =
          state.messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList();
      final reply = await useCase.execute(
        message: text,
        history: history,
        context: activeContext,
      );
      emit(
        state.copyWith(
          messages: List.from(state.messages)..add(reply),
          isSending: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isSending: false,
          messages: List.from(state.messages)
            ..add(ChatMessageEntity(role: 'assistant', content: 'Lỗi: $e')),
        ),
      );
    }
  }
}
