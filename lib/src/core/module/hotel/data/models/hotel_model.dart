import 'package:booking_app/src/core/module/hotel/domain/entities/hotel_entity.dart';

// Hàm hỗ trợ parse List an toàn dùng chung cho cả 2 Model
List<String> _parseList(dynamic data) {
  if (data == null) return [];
  if (data is List) return data.map((e) => e.toString()).toList();
  if (data is String) return [data];
  return [];
}

class RoomTypeModel {
  final String id;
  final String name;
  final String? description;
  final int capacity;
  final String? bedType;
  final double pricePerNight;
  final bool isActive;
  final int inventory;
  final List<String> imageUrl; // Danh sách ảnh phòng
  final List<String> amenities;

  RoomTypeModel({
    required this.id,
    required this.name,
    this.description,
    required this.capacity,
    this.bedType,
    required this.pricePerNight,
    required this.isActive,
    required this.inventory,
    this.imageUrl = const [],
    this.amenities = const [],
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
      inventory: (json['inventory'] as int?) ?? 1,
      imageUrl: _parseList(json['image_url']),
      amenities: _parseList(json['amenities']),
    );
  }

  factory RoomTypeModel.empty() {
    return RoomTypeModel(
      id: '',
      name: '',
      description: '',
      capacity: 2,
      bedType: 'Double',
      pricePerNight: 0,
      isActive: true,
      inventory: 1,
      imageUrl: [],
      amenities: [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'capacity': capacity,
    'bed_type': bedType,
    'price_per_night': pricePerNight,
    'is_active': isActive,
    'inventory': inventory,
    'image_url': imageUrl,
    'amenities': amenities,
  };
}

class HotelModel {
  final String id;
  final String name;
  final String city;
  final String address;
  final String? description;
  final double starRating;
  // THAY ĐỔI: Chuyển sang danh sách ảnh để lướt qua lướt về
  final List<String> images;
  final List<RoomTypeModel> roomTypes;

  HotelModel({
    required this.id,
    required this.name,
    required this.city,
    required this.address,
    this.description,
    required this.starRating,
    this.images = const [],
    this.roomTypes = const [],
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) {
    return HotelModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String,
      address: json['address'] as String,
      description: json['description'] as String?,
      starRating: (json['star_rating'] as num?)?.toDouble() ?? 0,
      // Dùng hàm parse list an toàn để lấy danh sách ảnh khách sạn
      images: _parseList(json['images'] ?? json['thumbnail_url']),
      roomTypes:
          ((json['room_types'] as List?) ?? [])
              .map((e) => RoomTypeModel.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  String? get thumbnailUrl => images.isNotEmpty ? images.first : null;

  HotelEntity toEntity() {
    return HotelEntity(
      id: id,
      name: name,
      city: city,
      address: address,
      starRating: starRating,
      // Ảnh thumbnail cho danh sách
      thumbnailUrl: images.isNotEmpty ? images.first : null,
      description: description,
      // Đảm bảo danh sách RoomTypeModel được giữ nguyên (vì nó đã có imageUrl riêng)
      roomTypes: roomTypes,
      // Mảng ảnh dùng cho Banner lướt qua lướt về
      images: images,
    );
  }
}
