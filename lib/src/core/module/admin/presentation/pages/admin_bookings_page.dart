import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:postgrest/postgrest.dart';

import '../../../../supabase/supabase_manager.dart';

class AdminBookingsPage extends StatefulWidget {
  const AdminBookingsPage({super.key});

  @override
  State<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  final _client = SupabaseManager.client;
  late Future<List<_AdminBookingItem>> _future;

  String _statusFilter = 'all';
  final Set<String> _confirmingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadBookings();
  }

  DateTime _parseDate(Map<String, dynamic> row, String k1, String k2) {
    final v = row[k1] ?? row[k2];
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    if (v is DateTime) return v;
    return DateTime.now();
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'done':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<List<_AdminBookingItem>> _loadBookings() async {
    // ✅ Filter trước, order sau
    dynamic q = _client.from('bookings').select(); // SELECT * (không generic)

    if (_statusFilter != 'all') {
      q = q.eq('status', _statusFilter);
    }

    final raw = await q.order('created_at', ascending: false);

    final rows = (raw as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return [];

    final hotelIds =
        rows.map((e) => e['hotel_id']).whereType<String>().toSet().toList();

    final roomIds =
        rows.map((e) => e['room_type_id']).whereType<String>().toSet().toList();

    final userIds =
        rows.map((e) => e['user_id']).whereType<String>().toSet().toList();

    final hotelsData = await _client
        .from('hotels')
        .select('id, name, city')
        .inFilter('id', hotelIds);

    final roomsData = await _client
        .from('room_types')
        .select('id, name')
        .inFilter('id', roomIds);

    // bạn đang dùng user_profiles
    final usersData = await _client
        .from('user_profiles')
        .select()
        .inFilter('user_id', userIds);

    final hotelMap = <String, Map<String, dynamic>>{};
    for (final h in (hotelsData as List)) {
      final m = (h as Map).cast<String, dynamic>();
      final id = m['id']?.toString();
      if (id != null) hotelMap[id] = m;
    }

    final roomMap = <String, Map<String, dynamic>>{};
    for (final r in (roomsData as List)) {
      final m = (r as Map).cast<String, dynamic>();
      final id = m['id']?.toString();
      if (id != null) roomMap[id] = m;
    }

    final userMap = <String, Map<String, dynamic>>{};
    for (final u in (usersData as List)) {
      final m = (u as Map).cast<String, dynamic>();
      final id = m['user_id']?.toString();
      if (id != null) userMap[id] = m;
    }

    return rows.map((b) {
      final hotelId = b['hotel_id']?.toString();
      final roomTypeId = b['room_type_id']?.toString();
      final userId = b['user_id']?.toString() ?? '';

      final hotel = hotelId == null ? null : hotelMap[hotelId];
      final room = roomTypeId == null ? null : roomMap[roomTypeId];
      final user = userId.isEmpty ? null : userMap[userId];

      final checkIn = _parseDate(b, 'check_in_date', 'check_in');
      final checkOut = _parseDate(b, 'check_out_date', 'check_out');
      final createdAt = _parseDate(b, 'created_at', 'createdAt');

      final totalPriceRaw = b['total_price'];
      final totalPrice = totalPriceRaw is num ? totalPriceRaw.toDouble() : 0.0;

      final adults =
          (b['guests_adults'] as num?)?.toInt() ??
          (b['adults'] as num?)?.toInt() ??
          0;

      final children =
          (b['guests_children'] as num?)?.toInt() ??
          (b['children'] as num?)?.toInt() ??
          0;

      return _AdminBookingItem(
        id: b['id']?.toString() ?? '',
        userId: userId,
        status: (b['status']?.toString() ?? 'pending'),
        checkIn: checkIn,
        checkOut: checkOut,
        createdAt: createdAt,
        totalPrice: totalPrice,
        adults: adults,
        children: children,
        hotelName: hotel?['name']?.toString() ?? 'Unknown hotel',
        hotelCity: hotel?['city']?.toString() ?? '',
        roomName: room?['name']?.toString() ?? '',
        userName: user?['full_name']?.toString() ?? 'Unknown user',
        userEmail: user?['email']?.toString() ?? '',
      );
    }).toList();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadBookings();
    });
  }

  Future<void> _confirmBooking(_AdminBookingItem b) async {
    if (_confirmingIds.contains(b.id)) return;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Confirm booking'),
            content: Text('Xác nhận booking này?\n\nID: ${b.id}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, confirm'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    setState(() => _confirmingIds.add(b.id));

    try {
      // ✅ Update + trả về list rows (an toàn, không 406)
      final raw = await _client
          .from('bookings')
          .update({'status': 'confirmed'})
          .eq('id', b.id)
          .eq('status', 'pending') // chỉ pending -> confirmed
          .select('id, status');

      final rows = (raw as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không confirm được: booking không còn pending HOẶC bạn chưa có quyền admin (RLS).',
            ),
          ),
        );
        await _reload();
        return;
      }

      // ✅ Thử tạo notification cho user (nếu RLS notifications đã cho admin insert)
      try {
        await _client.from('notifications').insert({
          'user_id': b.userId,
          'type': 'booking_confirmed',
          'title': 'Booking đã được xác nhận',
          'body': 'Booking ${b.id} tại ${b.hotelName} đã được admin xác nhận.',
        });
      } catch (_) {
        // Nếu chưa set policy admin cho notifications thì ignore, không làm fail confirm
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã confirm booking (pending → confirmed)'),
        ),
      );

      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Confirm lỗi: $e')));
    } finally {
      if (mounted) setState(() => _confirmingIds.remove(b.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin bookings')),
      body: FutureBuilder<List<_AdminBookingItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading bookings:\n${snapshot.error}'),
            );
          }

          final bookings = snapshot.data ?? [];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('pending')),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('confirmed'),
                    ),
                    DropdownMenuItem(value: 'done', child: Text('done')),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('cancelled'),
                    ),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _statusFilter = v);
                    await _reload();
                  },
                ),
              ),
              Expanded(
                child:
                    bookings.isEmpty
                        ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                _statusFilter == 'all'
                                    ? 'Chưa có booking nào.'
                                    : 'Không có booking với status = $_statusFilter',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                        : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: bookings.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final b = bookings[index];
                              final dateRange =
                                  '${dateFmt.format(b.checkIn)} → ${dateFmt.format(b.checkOut)}';

                              final statusColor = _statusColor(b.status);
                              final canConfirm = b.status == 'pending';
                              final confirming = _confirmingIds.contains(b.id);

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            b.hotelName,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            b.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${b.hotelCity} • ${b.roomName}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey[700]),
                                    ),
                                    const SizedBox(height: 8),

                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(b.userName)),
                                      ],
                                    ),
                                    if (b.userEmail.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 20,
                                        ),
                                        child: Text(
                                          b.userEmail,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.date_range, size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(dateRange)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.group, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${b.adults} adults'
                                          '${b.children > 0 ? ' • ${b.children} children' : ''}',
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '\$${b.totalPrice.toStringAsFixed(0)}',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        Text(
                                          'Created: ${dateFmt.format(b.createdAt)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                      ],
                                    ),

                                    if (canConfirm) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              confirming
                                                  ? null
                                                  : () => _confirmBooking(b),
                                          icon:
                                              confirming
                                                  ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : const Icon(
                                                    Icons.verified_outlined,
                                                  ),
                                          label: Text(
                                            confirming
                                                ? 'Confirming...'
                                                : 'Confirm',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminBookingItem {
  final String id;
  final String userId;
  final String status;
  final DateTime checkIn;
  final DateTime checkOut;
  final DateTime createdAt;
  final double totalPrice;
  final int adults;
  final int children;
  final String hotelName;
  final String hotelCity;
  final String roomName;
  final String userName;
  final String userEmail;

  _AdminBookingItem({
    required this.id,
    required this.userId,
    required this.status,
    required this.checkIn,
    required this.checkOut,
    required this.createdAt,
    required this.totalPrice,
    required this.adults,
    required this.children,
    required this.hotelName,
    required this.hotelCity,
    required this.roomName,
    required this.userName,
    required this.userEmail,
  });
}
