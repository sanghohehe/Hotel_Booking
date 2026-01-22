// lib/src/core/module/admin/presentation/pages/admin_hotels_page.dart

import 'package:flutter/material.dart';

import '../../../hotel/data/hotel_api.dart';
import '../../../hotel/data/models/hotel_model.dart';
import 'admin_hotel_edit_page.dart';

class AdminHotelsPage extends StatefulWidget {
  const AdminHotelsPage({super.key});

  @override
  State<AdminHotelsPage> createState() => _AdminHotelsPageState();
}

class _AdminHotelsPageState extends State<AdminHotelsPage> {
  final _api = HotelApi();
  late Future<List<HotelModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getHotels();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getHotels();
    });
  }

  Future<void> _openEditPage({HotelModel? hotel}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminHotelEditPage(hotel: hotel),
      ),
    );
    if (result == true) {
      _reload();
    }
  }

  Future<void> _deleteHotel(HotelModel hotel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete hotel'),
        content: Text('Xoá khách sạn "${hotel.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.deleteHotel(hotel.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotel deleted')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting hotel: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<List<HotelModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading hotels:\n${snapshot.error}'),
            );
          }

          final hotels = snapshot.data ?? [];

          if (hotels.isEmpty) {
            return const Center(child: Text('No hotels yet'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: hotels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final h = hotels[index];
                return ListTile(
                  tileColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: CircleAvatar(
                    backgroundImage: h.thumbnailUrl != null
                        ? NetworkImage(h.thumbnailUrl!)
                        : null,
                    child: h.thumbnailUrl == null
                        ? const Icon(Icons.hotel)
                        : null,
                  ),
                  title: Text(h.name),
                  subtitle: Text('${h.city} • ${h.starRating}★'),
                  onTap: () => _openEditPage(hotel: h),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteHotel(h),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditPage(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
