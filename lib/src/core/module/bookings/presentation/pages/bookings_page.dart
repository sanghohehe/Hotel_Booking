import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/booking_api.dart';
import '../../data/models/booking_model.dart';
import '../../../hotel/data/hotel_api.dart';
import '../../../hotel/presentation/pages/hotel_detail_page.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  final _api = BookingApi();
  late Future<List<BookingModel>> _future;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  /// bookingId đang xử lý payment
  final Set<String> _payingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _api.getMyBookings();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _api.getMyBookings();
    });
  }

  String _formatDate(DateTime d) => _dateFormat.format(d.toLocal());

  String _paymentLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'pending':
      case 'unpaid': // phòng trường hợp backend bạn trả về unpaid
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'canceled':
      case 'cancelled': // phòng trường hợp backend bạn trả về cancelled
        return 'Canceled';
      case 'refunded':
        return 'Refunded';
      default:
        return status;
    }
  }

  Color _paymentChipBg(BuildContext context, String status) {
    switch (status) {
      case 'paid':
        return Colors.green.withOpacity(0.15);
      case 'failed':
        return Colors.red.withOpacity(0.15);
      case 'pending':
      case 'unpaid':
        return Colors.orange.withOpacity(0.15);
      case 'canceled':
      case 'cancelled':
        return Colors.grey.withOpacity(0.15);
      case 'refunded':
        return Colors.blueGrey.withOpacity(0.15);
      default:
        return Theme.of(context).colorScheme.surfaceVariant;
    }
  }

  Color _paymentChipTextColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green[800]!;
      case 'failed':
        return Colors.red[800]!;
      case 'pending':
      case 'unpaid':
        return Colors.orange[800]!;
      case 'canceled':
      case 'cancelled':
        return Colors.grey[800]!;
      case 'refunded':
        return Colors.blueGrey[800]!;
      default:
        return Colors.black87;
    }
  }

  Color _statusChipBg(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.withOpacity(0.15);
      case 'confirmed':
        return Colors.green.withOpacity(0.15);
      case 'done':
        return Colors.blue.withOpacity(0.15);
      case 'cancelled':
        return Colors.red.withOpacity(0.15);
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  Color _statusChipText(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange[800]!;
      case 'confirmed':
        return Colors.green[800]!;
      case 'done':
        return Colors.blue[800]!;
      case 'cancelled':
        return Colors.red[800]!;
      default:
        return Colors.grey[800]!;
    }
  }

  Future<String?> _pickPaymentMethod() async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Chọn phương thức thanh toán (Mock)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Không trừ tiền thật.'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('MoMo (Mock)'),
                onTap: () => Navigator.pop(ctx, 'momo'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2_outlined),
                title: const Text('VNPay (Mock)'),
                onTap: () => Navigator.pop(ctx, 'vnpay'),
              ),
              ListTile(
                leading: const Icon(Icons.credit_card),
                title: const Text('Visa/Master (Mock)'),
                onTap: () => Navigator.pop(ctx, 'visa'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onPayMock(BookingModel booking) async {
    if (_payingIds.contains(booking.id)) return;

    final method = await _pickPaymentMethod();
    if (method == null) return;

    setState(() {
      _payingIds.add(booking.id);
    });

    try {
      await Future.delayed(const Duration(seconds: 1));

      await _api.payMock(bookingId: booking.id, method: method, success: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanh toán thành công (mock)!')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Thanh toán lỗi: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _payingIds.remove(booking.id);
        });
      }
    }
  }

  Future<void> _onCancel(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Cancel booking'),
            content: const Text('Bạn có chắc muốn hủy booking này không?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, cancel'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _api.cancelBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã hủy booking')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi hủy booking: $e')));
    }
  }

  Future<void> _onMarkDone(BookingModel booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Mark as done'),
            content: const Text(
              'Đánh dấu booking này là đã hoàn thành? Sau đó bạn sẽ có thể review khách sạn.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes, mark done'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      // ✅ Flow chuẩn: chỉ confirmed -> done (BookingApi đã chặn)
      await _api.markBookingDone(booking.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking đã chuyển sang trạng thái done')),
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật booking: $e')));
    }
  }

  Future<void> _openReview(BookingModel b) async {
    final hotelId = b.hotelId;
    if (hotelId == null || hotelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy hotelId để review')),
      );
      return;
    }

    try {
      final hotelApi = HotelApi();
      final hotel = await hotelApi.getHotelDetail(hotelId);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => HotelDetailPage(hotel: hotel, openReviewOnStart: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được trang review: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My bookings')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<BookingModel>>(
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
                      'Lỗi tải bookings:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text(
                      'Bạn chưa có booking nào.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }

            final now = DateTime.now();

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final b = bookings[index];

                final dateRange =
                    '${_formatDate(b.checkIn)} → ${_formatDate(b.checkOut)}';
                final guestsText =
                    '${b.guestsAdults} adult(s)'
                    '${b.guestsChildren > 0 ? ' · ${b.guestsChildren} child(ren)' : ''}';

                // ✅ Flow chuẩn
                final isPending = b.status == 'pending';
                final isConfirmed = b.status == 'confirmed';
                final isDone = b.status == 'done';

                // ✅ Cancel: chỉ khi chưa check-in
                final canCancel =
                    (isPending || isConfirmed) && b.checkIn.isAfter(now);

                // ✅ Mark done: chỉ confirmed + đã qua checkOut
                final canMarkDone = isConfirmed && !b.checkOut.isAfter(now);

                // Payment
                final isPaid = b.paymentStatus == 'paid';
                final canPay =
                    (isPending || isConfirmed) &&
                    !isPaid &&
                    b.paymentStatus != 'canceled' &&
                    b.paymentStatus != 'cancelled';

                final isPaying = _payingIds.contains(b.id);

                final showReviewButton = isDone;

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.hotelName ?? 'Unknown hotel',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (b.roomTypeName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            b.roomTypeName!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(guestsText),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.date_range, size: 16),
                            const SizedBox(width: 4),
                            Text(dateRange),
                          ],
                        ),
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Text(
                              '\$${b.totalPrice.toStringAsFixed(0)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const Spacer(),

                            // ✅ Status chip (pending/confirmed/done/cancelled)
                            Chip(
                              label: Text(b.status),
                              backgroundColor: _statusChipBg(b.status),
                              labelStyle: TextStyle(
                                color: _statusChipText(b.status),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // ✅ Payment chip luôn hiển thị
                            Chip(
                              label: Text(_paymentLabel(b.paymentStatus)),
                              backgroundColor: _paymentChipBg(
                                context,
                                b.paymentStatus,
                              ),
                              labelStyle: TextStyle(
                                color: _paymentChipTextColor(b.paymentStatus),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ✅ DONE => show Review chip
                        if (showReviewButton) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: ActionChip(
                              label: const Text('Review'),
                              avatar: const Icon(
                                Icons.rate_review_outlined,
                                size: 18,
                              ),
                              onPressed: () => _openReview(b),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],

                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          alignment: WrapAlignment.end,
                          children: [
                            if (canPay)
                              ElevatedButton.icon(
                                onPressed:
                                    isPaying ? null : () => _onPayMock(b),
                                icon:
                                    isPaying
                                        ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.payments_outlined),
                                label: Text(
                                  isPaying ? 'Paying...' : 'Pay (Mock)',
                                ),
                              ),

                            if (b.paymentStatus == 'failed' &&
                                (isPending || isConfirmed))
                              OutlinedButton(
                                onPressed:
                                    isPaying ? null : () => _onPayMock(b),
                                child: const Text('Retry'),
                              ),

                            if (canCancel)
                              TextButton(
                                onPressed: () => _onCancel(b),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),

                            if (canMarkDone)
                              TextButton(
                                onPressed: () => _onMarkDone(b),
                                child: const Text(
                                  'Mark done',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                          ],
                        ),

                        // ✅ Hint cho user khi pending
                        if (isPending) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Booking đang chờ admin xác nhận (confirmed).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[700],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
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
