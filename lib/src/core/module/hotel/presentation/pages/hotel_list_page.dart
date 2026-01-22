import 'package:flutter/material.dart';

import '../../data/hotel_api.dart';
import '../../data/city_api.dart';
import '../../data/models/hotel_model.dart';
import '../../data/models/city_model.dart';
import 'hotel_detail_page.dart';

class HotelListPage extends StatefulWidget {
  const HotelListPage({super.key});

  @override
  State<HotelListPage> createState() => _HotelListPageState();
}

class _HotelListPageState extends State<HotelListPage> {
  final _hotelApi = HotelApi();
  final _cityApi = CityApi();

  late Future<List<HotelModel>> _future;

  // null = all, còn lại là min rating
  double? _selectedMinRating;
  final List<double?> _ratingFilters = [null, 4.0, 4.5, 5.0];

  // filter theo city
  String? _selectedCity; // null = All cities
  bool _loadingCities = false;
  List<CityModel> _cities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
    _future = _hotelApi.getHotels();
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      final data = await _cityApi.getCities();
      if (!mounted) return;
      setState(() {
        _cities = data;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải danh sách thành phố: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingCities = false);
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _future = _hotelApi.getHotels(
        minRating: _selectedMinRating,
        city: _selectedCity,
      );
    });
  }

  String _ratingFilterLabel(double? value) {
    if (value == null) return 'All';
    if (value == 4.0) return '4.0+';
    if (value == 4.5) return '4.5+';
    if (value == 5.0) return '5.0';
    return '${value.toStringAsFixed(1)}+';
  }

  Future<void> _openCityFilter() async {
    // chưa load xong city thì thôi
    if (_loadingCities && _cities.isEmpty) return;

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String search = '';
        final theme = Theme.of(ctx);

        List<CityModel> filtered() {
          if (search.trim().isEmpty) return _cities;
          final q = search.toLowerCase();
          return _cities
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final items = filtered();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Text(
                    'Chọn thành phố',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm thành phố...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setModalState(() => search = v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Tất cả thành phố'),
                    onTap: () => Navigator.of(ctx).pop(null),
                    selected: _selectedCity == null,
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (ctx, index) {
                        final c = items[index];
                        return ListTile(
                          title: Text(c.name),
                          onTap: () => Navigator.of(ctx).pop(c.name),
                          selected: c.name == _selectedCity,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (result == _selectedCity) return;

    setState(() {
      _selectedCity = result;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Discover hotels')),
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
                      'Lỗi tải khách sạn:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final hotels = snapshot.data ?? [];

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: hotels.length + 1, // +1 cho phần filter header
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Header filter (city + rating)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // City filter
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter by city',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                _cities.isEmpty && _loadingCities
                                    ? null
                                    : _openCityFilter,
                            icon: const Icon(Icons.location_on, size: 18),
                            label: Text(
                              _selectedCity ?? 'All cities',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Rating filter
                      Text(
                        'Filter by rating',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              _ratingFilters.map((value) {
                                final selected = value == _selectedMinRating;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    right: 8.0,
                                    bottom: 8,
                                  ),
                                  child: ChoiceChip(
                                    label: Text(_ratingFilterLabel(value)),
                                    selected: selected,
                                    onSelected: (_) {
                                      setState(() {
                                        _selectedMinRating =
                                            value == _selectedMinRating
                                                ? null
                                                : value;
                                        _future = _hotelApi.getHotels(
                                          minRating: _selectedMinRating,
                                          city: _selectedCity,
                                        );
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (hotels.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text('Không có khách sạn nào phù hợp'),
                          ),
                        ),
                    ],
                  );
                }

                final hotel = hotels[index - 1];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HotelDetailPage(hotel: hotel),
                        ),
                      );
                    },
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(16),
                            ),
                            child: SizedBox(
                              width: 120,
                              height: double.infinity,
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
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.hotel,
                                          size: 32,
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${hotel.city} • ${hotel.address}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        hotel.starRating.toString(),
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
