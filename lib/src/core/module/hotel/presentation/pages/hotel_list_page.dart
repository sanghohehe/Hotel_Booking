import 'dart:async';

import 'package:booking_app/src/core/module/hotel/domain/entities/hotel_entity.dart';
import 'package:booking_app/src/core/module/hotel/presentation/cubit/HotelState.dart';
import 'package:booking_app/src/core/module/hotel/presentation/cubit/hotel_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/city_api.dart';
import '../../data/models/city_model.dart';

import 'hotel_detail_page.dart';

class HotelListPage extends StatefulWidget {
  const HotelListPage({super.key});

  @override
  State<HotelListPage> createState() => _HotelListPageState();
}

class _HotelListPageState extends State<HotelListPage> {
  final _cityApi = CityApi();

  double? _selectedMinRating;
  final List<double?> _ratingFilters = [null, 4.0, 4.5, 5.0];
  String? _selectedCity;

  String? _searchKeyword;
  Timer? _debounce;

  bool _loadingCities = false;
  List<CityModel> _cities = [];

  @override
  void initState() {
    super.initState();
    _loadCities();
    context.read<HotelCubit>().fetchHotels();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCities() async {
    setState(() => _loadingCities = true);
    try {
      final data = await _cityApi.getCities();
      if (!mounted) return;
      setState(() => _cities = data);
    } catch (e) {
      debugPrint("Error loading cities: $e");
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  void _reload() {
    context.read<HotelCubit>().fetchHotels(
      minRating: _selectedMinRating,
      city: _selectedCity,
      keyword: _searchKeyword,
    );
  }

  void _onSearchChanged(String value) {
    _searchKeyword = value;

    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _reload();
    });
  }

  void _clearSearch() {
    _searchKeyword = null;
    _reload();
    setState(() {});
  }

  Widget _buildAmenity(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.teal),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.teal)),
      ],
    );
  }

  void _openCityFilter() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select City',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._cities.map(
                (city) => ListTile(
                  title: Text(city.name),
                  leading: const Icon(Icons.location_city),
                  onTap: () {
                    setState(() => _selectedCity = city.name);
                    _reload();
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // APP BAR (GIỮ NGUYÊN)
          SliverAppBar(
            expandedHeight: 120.0,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              centerTitle: false,
              title: Text(
                'Explore Hotels',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),

          // 🔥 FILTER (CHỈ GỘP SEARCH + CITY)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ GỘP 2 Ô TẠI ĐÂY
                  GestureDetector(
                    onTap: _openCityFilter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, color: primaryColor),
                          const SizedBox(width: 12),

                          Expanded(
                            child: TextField(
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText:
                                    _selectedCity != null
                                        ? '$_selectedCity - Search hotel...'
                                        : 'Where are you going?',
                              ),
                            ),
                          ),

                          if (_searchKeyword != null &&
                              _searchKeyword!.isNotEmpty)
                            GestureDetector(
                              onTap: _clearSearch,
                              child: const Icon(Icons.clear),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ⭐ RATING FILTER (GIỮ NGUYÊN)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children:
                          _ratingFilters.map((value) {
                            final isSelected = value == _selectedMinRating;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(
                                  value == null ? 'All' : '$value+ ⭐',
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(
                                    () =>
                                        _selectedMinRating =
                                            isSelected ? null : value,
                                  );
                                  _reload();
                                },
                                selectedColor: primaryColor.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color:
                                      isSelected
                                          ? primaryColor
                                          : Colors.grey[700],
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color:
                                        isSelected
                                            ? primaryColor
                                            : Colors.grey[300]!,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LIST (GIỮ NGUYÊN 100%)
          BlocBuilder<HotelCubit, HotelState>(
            builder: (context, state) {
              if (state is HotelLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (state is HotelError) {
                return SliverFillRemaining(
                  child: Center(child: Text(state.message)),
                );
              }

              if (state is HotelLoaded) {
                final hotels = state.hotels;

                if (hotels.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(child: Text('No hotels found 🏨')),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildHotelCard(hotels[index], primaryColor),
                      childCount: hotels.length,
                    ),
                  ),
                );
              }

              return const SliverToBoxAdapter();
            },
          ),
        ],
      ),
    );
  }

  // 🔥 GIỮ NGUYÊN UI HOTEL 100%
  Widget _buildHotelCard(HotelEntity hotel, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HotelDetailPage(hotel: hotel)),
            ),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Image.network(
                    hotel.thumbnailUrl ?? '',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          color: Colors.grey[200],
                          height: 180,
                          child: const Icon(Icons.hotel),
                        ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          hotel.starRating.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$200',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${hotel.city}, ${hotel.address}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildAmenity(Icons.wifi, "Free Wifi"),
                      const SizedBox(width: 12),
                      _buildAmenity(Icons.pool, "Pool"),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
