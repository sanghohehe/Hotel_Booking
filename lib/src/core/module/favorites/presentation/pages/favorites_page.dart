import 'package:flutter/material.dart';

import '../../../hotel/data/hotel_api.dart';
import '../../../hotel/data/models/hotel_model.dart';
import '../../data/favorite_api.dart';
import '../../../hotel/presentation/pages/hotel_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _favoriteApi = FavoriteApi();
  final _hotelApi = HotelApi();

  late Future<List<HotelModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadFavoriteHotels();
  }

  Future<List<HotelModel>> _loadFavoriteHotels() async {
    final favIds = await _favoriteApi.getMyFavoriteHotelIds();
    if (favIds.isEmpty) return [];
    return _hotelApi.getHotelsByIds(favIds.toList());
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadFavoriteHotels();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<HotelModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Lỗi tải favorites:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final hotels = snapshot.data ?? [];

            if (hotels.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Bạn chưa yêu thích khách sạn nào.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: hotels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final hotel = hotels[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => HotelDetailPage(hotel: hotel),
                          ),
                        )
                        .then((_) => _reload());
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: 120,
                      child: Row(
                        children: [
                          AspectRatio(
                            aspectRatio: 4 / 3,
                            child:
                                hotel.thumbnailUrl != null
                                    ? Image.network(
                                      hotel.thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                            color: Colors.grey[300],
                                          ),
                                    )
                                    : Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.hotel, size: 40),
                                    ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hotel.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${hotel.city} • ${hotel.address}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 18,
                                        color: Colors.amber[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hotel.starRating.toStringAsFixed(1),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
