import '../../domain/entities/chat_message_entity.dart';

class ChatbotState {
  final List<ChatMessageEntity> messages;
  final bool isSending;
  final Map<String, dynamic> botContext;
  final int guests;

  /// Văn bản đang stream từng chữ từ bot (chưa hoàn thành).
  /// Khi stream kết thúc sẽ được flush vào [messages] và reset về ''.
  final String streamingText;

  ChatbotState({
    this.messages = const [],
    this.isSending = false,
    this.botContext = const {},
    this.guests = 2,
    this.streamingText = '',
  });

  /// Bot đang stream khi [streamingText] không rỗng
  bool get isStreaming => streamingText.isNotEmpty;

  String formatVnd(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '';
    final s = n.toStringAsFixed(0);
    return '${s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}đ';
  }

  ChatbotState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isSending,
    Map<String, dynamic>? botContext,
    int? guests,
    String? streamingText,
  }) {
    return ChatbotState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      botContext: botContext ?? this.botContext,
      guests: guests ?? this.guests,
      streamingText: streamingText ?? this.streamingText,
    );
  }
}
