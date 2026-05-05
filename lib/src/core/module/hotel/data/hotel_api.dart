import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:diacritic/diacritic.dart';
import '../../../supabase/supabase_manager.dart';
import 'models/hotel_model.dart';

class HotelApi {
  final SupabaseClient _client = SupabaseManager.client;
  String _normalize(String input) {
    return removeDiacritics(input).toLowerCase().trim();
  }

  // Cập nhật chuỗi select để lấy thêm cột amenities
  static const String _hotelSelect = '''
    id,
    name,
    city,
    address,
    description,
    star_rating,
    thumbnail_url,
    images,
    room_types(
      id,
      hotel_id,
      name,
      price_per_night,
      capacity,
      bed_type,
      description,
      image_url,
      amenities,
      inventory
    )
  ''';

  /// Lấy danh sách khách sạn
  Future<List<HotelModel>> getHotels({
    double? minRating,
    String? keyword,
  }) async {
    var query = _client.from('hotels').select(_hotelSelect);

    if (minRating != null) {
      query = query.gte('star_rating', minRating);
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      final normalized = _normalize(keyword);

      // 🔥 SEARCH NHIỀU FIELD
      query = query.or(
        'name_unsigned.ilike.%$normalized%,city.ilike.%${keyword.trim()}%,address.ilike.%${keyword.trim()}%',
      );
    }

    final data = await query.order('star_rating', ascending: false);

    return (data as List)
        .map((e) => HotelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy danh sách khách sạn theo list id (Favorites)
  Future<List<HotelModel>> getHotelsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final data = await _client
        .from('hotels')
        .select(_hotelSelect)
        .inFilter('id', ids)
        .order('star_rating', ascending: false);

    return (data as List)
        .map((e) => HotelModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Lấy chi tiết 1 khách sạn
  Future<HotelModel> getHotelDetail(String hotelId) async {
    final data =
        await _client
            .from('hotels')
            .select(_hotelSelect)
            .eq('id', hotelId)
            .single();
    return HotelModel.fromJson(data as Map<String, dynamic>);
  }

  // ================== ADMIN: HOTEL CRUD ==================

  Future<HotelModel> createHotel({
    required String name,
    required String city,
    required String address,
    String? description,
    double starRating = 4.0,
    String? thumbnailUrl,
    List<String>? images,
  }) async {
    final insertPayload = <String, dynamic>{
      'name': name,
      'city': city,
      'address': address,
      'star_rating': starRating,
      'images': images ?? [],
    };
    if (description != null) insertPayload['description'] = description;
    if (thumbnailUrl != null) insertPayload['thumbnail_url'] = thumbnailUrl;

    final data =
        await _client
            .from('hotels')
            .insert(insertPayload)
            .select(_hotelSelect)
            .single();
    return HotelModel.fromJson(data as Map<String, dynamic>);
  }

  Future<HotelModel> updateHotel({
    required String id,
    String? name,
    String? city,
    String? address,
    String? description,
    double? starRating,
    String? thumbnailUrl,
    List<String>? images,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (city != null) payload['city'] = city;
    if (address != null) payload['address'] = address;
    if (description != null) payload['description'] = description;
    if (starRating != null) payload['star_rating'] = starRating;
    if (thumbnailUrl != null) payload['thumbnail_url'] = thumbnailUrl;
    if (images != null) payload['images'] = images;

    if (payload.isEmpty) return getHotelDetail(id);

    final data =
        await _client
            .from('hotels')
            .update(payload)
            .eq('id', id)
            .select(_hotelSelect)
            .single();
    return HotelModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteHotel(String id) async {
    await _client.from('hotels').delete().eq('id', id);
  }

  Future<void> deleteRoomType(String id) async {
    await _client.from('room_types').delete().eq('id', id);
  }

  // ================== ADMIN: ROOM TYPE CRUD ==================

  Future<List<RoomTypeModel>> getRoomTypesForHotel(String hotelId) async {
    final data = await _client
        .from('room_types')
        .select(
          'id, hotel_id, name, price_per_night, capacity, bed_type, description, image_url, amenities, inventory',
        )
        .eq('hotel_id', hotelId)
        .order('price_per_night', ascending: true);

    return (data as List)
        .map((e) => RoomTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// TẠO MỚI PHÒNG: Cập nhật thêm imageUrl và amenities
  Future<RoomTypeModel> createRoomType({
    required String hotelId,
    required String name,
    required double pricePerNight,
    required int capacity,
    String? bedType,
    String? description,
    List<String>? imageUrl, // Đã thêm
    List<String>? amenities, // Đã thêm
  }) async {
    final payload = <String, dynamic>{
      'hotel_id': hotelId,
      'name': name,
      'price_per_night': pricePerNight,
      'capacity': capacity,
      'image_url': imageUrl ?? [],
      'amenities': amenities ?? [],
    };
    if (bedType != null) payload['bed_type'] = bedType;
    if (description != null) payload['description'] = description;

    final data =
        await _client
            .from('room_types')
            .insert(payload)
            .select(
              'id, hotel_id, name, price_per_night, capacity, bed_type, description, image_url, amenities, inventory',
            )
            .single();

    return RoomTypeModel.fromJson(data as Map<String, dynamic>);
  }

  /// CẬP NHẬT PHÒNG: Cập nhật thêm imageUrl và amenities
  Future<RoomTypeModel> updateRoomType({
    required String id,
    String? name,
    double? pricePerNight,
    int? capacity,
    String? bedType,
    String? description,
    List<String>? imageUrl, // Đã thêm
    List<String>? amenities, // Đã thêm
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (pricePerNight != null) payload['price_per_night'] = pricePerNight;
    if (capacity != null) payload['capacity'] = capacity;
    if (bedType != null) payload['bed_type'] = bedType;
    if (description != null) payload['description'] = description;
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (amenities != null) payload['amenities'] = amenities;

    final data =
        await _client
            .from('room_types')
            .update(payload)
            .eq('id', id)
            .select(
              'id, hotel_id, name, price_per_night, capacity, bed_type, description, image_url, amenities, inventory',
            )
            .single();

    return RoomTypeModel.fromJson(data as Map<String, dynamic>);
  }
}
