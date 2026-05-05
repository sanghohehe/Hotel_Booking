import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/hotel_entity.dart';
import '../cubit/hotel_detail_cubit.dart';
import '../cubit/hotel_detail_state.dart';
import 'widgets/favorite_button.dart';
import 'widgets/hotel_image_header.dart';
import 'widgets/review_list_section.dart';
import 'widgets/room_card.dart';

class HotelDetailPage extends StatelessWidget {
  final HotelEntity hotel;
  final bool openReviewOnStart;

  const HotelDetailPage({
    super.key,
    required this.hotel,
    this.openReviewOnStart = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create:
          (context) =>
              HotelDetailCubit(context.read())..loadHotelDetail(hotel.id),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: BlocBuilder<HotelDetailCubit, HotelDetailState>(
          builder: (context, state) {
            final displayHotel = state.hotel ?? hotel;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    background: HotelImageHeader(
                      images: displayHotel.images, // Danh sách nhiều ảnh
                      url: displayHotel.thumbnailUrl, // Ảnh đại diện dự phòng
                    ),
                  ),
                  // Nút back bo tròn
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.5),
                      child: BackButton(color: Colors.black87),
                    ),
                  ),
                  actions: const [FavoriteButton()],
                ),

                // 2. Nội dung chi tiết
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tiêu đề & Rating
                        _buildHeroSection(theme, displayHotel),

                        const SizedBox(height: 24),

                        // Mô tả (Hàm mình đã viết ở trên)
                        _buildDescription(theme, displayHotel),

                        const SizedBox(height: 24),

                        // Danh sách phòng (Dùng RoomCard của bạn)
                        _buildSectionHeader(
                          theme,
                          'Available Rooms',
                          Icons.bed_outlined,
                        ),
                        const SizedBox(height: 12),
                        ...displayHotel.roomTypes.map(
                          (room) => RoomCard(hotel: displayHotel, room: room),
                        ),

                        const SizedBox(height: 24),

                        // Review (Dùng ReviewListSection của bạn)
                        ReviewListSection(onAddReview: () {}),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection(ThemeData theme, HotelEntity hotel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hotel.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on, size: 16, color: theme.primaryColor),
            const SizedBox(width: 4),
            Text(
              '${hotel.city} • ${hotel.address}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const Spacer(),
            const Icon(Icons.star, color: Colors.amber, size: 20),
            Text(
              ' ${hotel.starRating}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription(ThemeData theme, HotelEntity hotel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme, 'Description', Icons.info_outline),
        const SizedBox(height: 8),
        Text(
          hotel.description ?? 'No description.',
          style: const TextStyle(color: Colors.black54, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
