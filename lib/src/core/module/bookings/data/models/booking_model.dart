class BookingModel {
  final String id;
  final String? userId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalPrice;
  final String status;
  final String paymentStatus;
  final int guestsAdults;
  final int guestsChildren;
  final String? hotelName;
  final String? hotelCity;
  final String? roomTypeName;
  final String? paymentMethod;
  final DateTime? paidAt;
  final String? hotelId;

  BookingModel({
    required this.id,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
    required this.status,
    required this.paymentStatus,
    required this.guestsAdults,
    required this.guestsChildren,
    this.userId,
    this.hotelName,
    this.hotelCity,
    this.roomTypeName,
    this.paymentMethod,
    this.paidAt,
    this.hotelId,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final hotelJson = json['hotels'] as Map<String, dynamic>?;
    final roomJson = json['room_types'] as Map<String, dynamic>?;

    return BookingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      checkIn: DateTime.parse(json['check_in'] as String),
      checkOut: DateTime.parse(json['check_out'] as String),
      totalPrice: (json['total_price'] as num).toDouble(),
      status: json['status'] as String,
      paymentStatus: json['payment_status'] as String,
      guestsAdults: (json['guests_adults'] as int?) ?? 1,
      guestsChildren: (json['guests_children'] as int?) ?? 0,
      hotelName: hotelJson?['name'] as String?,
      hotelCity: hotelJson?['city'] as String?,
      roomTypeName: roomJson?['name'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paidAt:
          json['paid_at'] != null
              ? DateTime.parse(json['paid_at'] as String)
              : null,
      hotelId: json['hotel_id'] as String?,
    );
  }
}
