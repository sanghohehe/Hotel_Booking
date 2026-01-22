import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase/supabase_manager.dart';
import 'models/hotel_model.dart';

class HotelApi {
  final SupabaseClient _client = SupabaseManager.client;

  // Dùng chung cho mọi select hotel
  static const String _hotelSelect = '''
    id,
    name,
    city,
    address,
    description,
    star_rating,
    thumbnail_url,
    room_types(
      id,
      hotel_id,
      name,
      price_per_night,
      capacity,
      bed_type,
      description
    )
  ''';

  /// Lấy danh sách khách sạn, có thể filter theo minRating
  Future<List<HotelModel>> getHotels({double? minRating, String? city}) async {
    var query = _client.from('hotels').select(_hotelSelect);

    if (minRating != null) {
      query = query.gte('star_rating', minRating);
    }

    if (city != null && city.isNotEmpty) {
      query = query.eq('city', city);
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

  /// Lấy chi tiết 1 khách sạn (HotelDetailPage / Admin edit)
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
  }) async {
    final insertPayload = <String, dynamic>{
      'name': name,
      'city': city,
      'address': address,
      'star_rating': starRating,
    };

    if (description != null) {
      insertPayload['description'] = description;
    }
    if (thumbnailUrl != null) {
      insertPayload['thumbnail_url'] = thumbnailUrl;
    }

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
  }) async {
    final payload = <String, dynamic>{};

    if (name != null) payload['name'] = name;
    if (city != null) payload['city'] = city;
    if (address != null) payload['address'] = address;
    if (description != null) payload['description'] = description;
    if (starRating != null) payload['star_rating'] = starRating;
    if (thumbnailUrl != null) payload['thumbnail_url'] = thumbnailUrl;

    if (payload.isEmpty) {
      return getHotelDetail(id);
    }

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

  // ================== ADMIN: ROOM TYPE CRUD ==================

  /// Lấy danh sách room_types cho 1 hotel
  Future<List<RoomTypeModel>> getRoomTypesForHotel(String hotelId) async {
    final data = await _client
        .from('room_types')
        .select(
          'id, hotel_id, name, price_per_night, capacity, bed_type, description',
        )
        .eq('hotel_id', hotelId)
        .order('price_per_night', ascending: true);

    return (data as List)
        .map((e) => RoomTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Tạo room type mới
  Future<RoomTypeModel> createRoomType({
    required String hotelId,
    required String name,
    required double pricePerNight,
    required int capacity,
    String? bedType,
    String? description,
  }) async {
    final payload = <String, dynamic>{
      'hotel_id': hotelId,
      'name': name,
      'price_per_night': pricePerNight,
      'capacity': capacity,
    };
    if (bedType != null) payload['bed_type'] = bedType;
    if (description != null) payload['description'] = description;

    final data =
        await _client
            .from('room_types')
            .insert(payload)
            .select(
              'id, hotel_id, name, price_per_night, capacity, bed_type, description',
            )
            .single();

    return RoomTypeModel.fromJson(data as Map<String, dynamic>);
  }

  /// Cập nhật room type
  Future<RoomTypeModel> updateRoomType({
    required String id,
    String? name,
    double? pricePerNight,
    int? capacity,
    String? bedType,
    String? description,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (pricePerNight != null) payload['price_per_night'] = pricePerNight;
    if (capacity != null) payload['capacity'] = capacity;
    if (bedType != null) payload['bed_type'] = bedType;
    if (description != null) payload['description'] = description;

    final data =
        await _client
            .from('room_types')
            .update(payload)
            .eq('id', id)
            .select(
              'id, hotel_id, name, price_per_night, capacity, bed_type, description',
            )
            .single();

    return RoomTypeModel.fromJson(data as Map<String, dynamic>);
  }

  /// Xoá room type
  Future<void> deleteRoomType(String id) async {
    await _client.from('room_types').delete().eq('id', id);
  }
}
