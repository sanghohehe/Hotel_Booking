import 'package:booking_app/src/core/module/hotel/data/hotel_api.dart';
import 'package:booking_app/src/core/module/hotel/data/models/hotel_model.dart';
import 'package:booking_app/src/core/module/hotel/domain/entities/hotel_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import tất cả các Interface cần thiết
import 'package:booking_app/src/core/module/hotel/domain/repositories/hotel_repository.dart';
import 'package:booking_app/src/core/module/hotel/domain/repositories/hotel_detail_repository.dart';
import 'package:booking_app/src/core/module/admin/domain/repositories/i_hotel_repository.dart';

import '../../../favorites/data/favorite_api.dart';
import '../../../reviews/data/review_api.dart';
import '../../../bookings/data/booking_api.dart';
import '../../../reviews/data/models/review_model.dart';

class HotelRepositoryImpl
    implements HotelRepository, HotelDetailRepository, IHotelRepository {
  // Đảm bảo implements cả 3 Interface

  final HotelApi _api;
  final _supabase = Supabase.instance.client;

  final FavoriteApi _favoriteApi = FavoriteApi();
  final ReviewApi _reviewApi = ReviewApi();
  final BookingApi _bookingApi = BookingApi();

  HotelRepositoryImpl(this._api);

  // --- PHẦN DÀNH CHO USER (HIỂN THỊ) ---

  @override
  Future<List<HotelEntity>> getHotels({double? minRating, String? city,String? keyword,}) async {
    final models = await _api.getHotels(minRating: minRating, keyword: keyword);
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<HotelEntity> getHotelDetail(String id) async {
    // 1. Lấy dữ liệu model từ API
    final model = await _api.getHotelDetail(id);

    // 2. Trả về Entity (Sử dụng hàm toEntity đã có sẵn logic hoặc map thủ công để an toàn)
    return HotelEntity(
      id: model.id,
      name: model.name,
      address: model.address,
      city: model.city,
      starRating: model.starRating,
      description: model.description,
      thumbnailUrl: model.thumbnailUrl, // Ảnh đại diện đầu tiên
      images: model.images, // Danh sách ảnh Banner khách sạn
      roomTypes: model.roomTypes, // Giữ nguyên List<RoomTypeModel>
    );
  }

  @override
  Future<List<ReviewModel>> getReviews(String hotelId) async {
    return await _reviewApi.getReviewsForHotel(hotelId);
  }

  // --- PHẦN DÀNH CHO ADMIN (QUẢN LÝ) ---

  @override
  Future<List<RoomTypeModel>> getRoomTypes(String hotelId) =>
      _api.getRoomTypesForHotel(hotelId);

  @override
  Future<void> deleteRoomType(String roomId) => _api.deleteRoomType(roomId);

  @override
  Future<List<String>> saveHotel({
    required HotelModel? existingHotel,
    required String name,
    required String city,
    required String address,
    String? description,
    required double starRating,
    required List<XFile> multipleImages,
    required List<String> existingImages, 
  }) async {
    // 1. Lấy danh sách ảnh hiện tại đang hiển thị trên UI làm gốc
    // Thay vì lấy từ existingHotel.images, ta dùng existingImages truyền từ Cubit xuống
    List<String> finalImageUrls = List<String>.from(existingImages);

    // 2. Upload các ảnh mới chọn (nếu có)
    for (var file in multipleImages) {
      try {
        final bytes = await file.readAsBytes();
        // Tạo tên file duy nhất để tránh trùng lặp
        final fileName = 'hotel_${DateTime.now().microsecondsSinceEpoch}.jpg';

        await _supabase.storage
            .from('hotel-images')
            .uploadBinary(fileName, bytes);

        final url = _supabase.storage
            .from('hotel-images')
            .getPublicUrl(fileName);

        // Thêm URL mới vào danh sách tổng
        finalImageUrls.add(url);
      } catch (e) {
        debugPrint('Lỗi upload ảnh: $e');
        // Tùy chọn: có thể quăng lỗi hoặc bỏ qua ảnh lỗi
      }
    }

    // 3. Cập nhật Database với danh sách ảnh ĐÃ GỘP (finalImageUrls)
    if (existingHotel == null) {
      await _api.createHotel(
        name: name,
        city: city,
        address: address,
        description: description,
        starRating: starRating,
        images: finalImageUrls,
      );
    } else {
      await _api.updateHotel(
        id: existingHotel.id,
        name: name,
        city: city,
        address: address,
        description: description,
        starRating: starRating,
        images: finalImageUrls,
      );
    }

    // 4. Trả về danh sách cuối cùng để Cubit cập nhật lại state.existingImages
    return finalImageUrls;
  }

  @override
  Future<void> saveRoomType({
    required String hotelId,
    required RoomTypeModel room,
    required List<XFile> newImages,
  }) async {
    List<String> imageUrls = List<String>.from(room.imageUrl);

    for (var image in newImages) {
      final bytes = await image.readAsBytes();
      final fileName = 'room_${DateTime.now().microsecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('hotel-images')
          .uploadBinary(fileName, bytes);
      imageUrls.add(
        _supabase.storage.from('hotel-images').getPublicUrl(fileName),
      );
    }

    // Logic gọi API lưu RoomType tùy theo HotelApi của bạn
  }

  // --- PHẦN TƯƠNG TÁC (FAVORITE, REVIEW) ---

  @override
  Future<bool> isFavorite(String hotelId) => _favoriteApi.isFavorite(hotelId);

  @override
  Future<void> toggleFavorite(String hotelId, bool isFavorite) async {
    isFavorite
        ? await _favoriteApi.addFavorite(hotelId)
        : await _favoriteApi.removeFavorite(hotelId);
  }

  @override
  Future<bool> checkCanReview(String hotelId) =>
      _bookingApi.hasBookingForHotel(hotelId);
}
