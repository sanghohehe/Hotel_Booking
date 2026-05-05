class ChatMessageEntity {
  final String role;
  final String content;
  final List<dynamic>? hotels;
  final List<dynamic>? availability;
  final List<dynamic>? bookings;

  ChatMessageEntity({
    required this.role,
    required this.content,
    this.hotels,
    this.availability,
    this.bookings,
  });
}