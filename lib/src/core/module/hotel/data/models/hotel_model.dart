class RoomTypeModel {
  final String id;
  final String name;
  final String? description;
  final int capacity;
  final String? bedType;
  final double pricePerNight;
  final bool isActive;

  RoomTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.capacity,
    this.bedType,
    required this.pricePerNight,
    required this.isActive,
  });

  factory RoomTypeModel.fromJson(Map<String, dynamic> json) {
    return RoomTypeModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      capacity: json['capacity'] as int,
      bedType: json['bed_type'] as String?,
      pricePerNight: (json['price_per_night'] as num).toDouble(),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}

class HotelModel {
  final String id;
  final String name;
  final String city;
  final String address;
  final String? description;
  final double starRating;
  final String? thumbnailUrl;
  final List<RoomTypeModel> roomTypes;

  HotelModel({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.description,
    required this.starRating,
    this.thumbnailUrl,
    this.roomTypes = const [],
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) {
    final roomTypesJson = (json['room_types'] as List?) ?? [];

    return HotelModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      address: json['address'] as String,
      description: json['description'] as String?,
      starRating: (json['star_rating'] as num?)?.toDouble() ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
      roomTypes:
          roomTypesJson
              .map((e) => RoomTypeModel.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}
