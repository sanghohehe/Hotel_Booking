import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../hotel/data/models/hotel_model.dart';
import '../../data/booking_api.dart';
import '../../data/models/booking_model.dart';
import 'payment_page.dart';

class BookingConfirmPage extends StatefulWidget {
  final HotelModel hotel;
  final RoomTypeModel roomType;

  const BookingConfirmPage({
    super.key,
    required this.hotel,
    required this.roomType,
  });

  @override
  State<BookingConfirmPage> createState() => _BookingConfirmPageState();
}

class _BookingConfirmPageState extends State<BookingConfirmPage> {
  final _api = BookingApi();
  final _noteController = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  DateTime _checkIn = DateTime.now().add(const Duration(days: 1));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 2));
  int _adults = 2;
  int _children = 0;
  bool _isLoading = false;

  int get _nights => _checkOut.difference(_checkIn).inDays;

  double get _totalPrice =>
      (_nights > 0 ? _nights : 0) * widget.roomType.pricePerNight;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCheckIn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _checkIn = picked;
        if (_checkOut.isBefore(_checkIn.add(const Duration(days: 1)))) {
          _checkOut = _checkIn.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickCheckOut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkOut,
      firstDate: _checkIn.add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _checkOut = picked;
      });
    }
  }

  String _formatDate(DateTime d) => _dateFormat.format(d.toLocal());

  Future<void> _onConfirm() async {
    if (_nights <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-out phải sau check-in ít nhất 1 đêm'),
        ),
      );
      return;
    }

    if (_adults <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phải có ít nhất 1 người lớn')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final booking = await _api.createBooking(
        hotel: widget.hotel,
        roomType: widget.roomType,
        checkIn: _checkIn,
        checkOut: _checkOut,
        guestsAdults: _adults,
        guestsChildren: _children,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;

      // chuyển sang thanh toán
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => PaymentPage(booking: booking)),
      );

      if (!mounted) return;

      if (paid == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt phòng & thanh toán thành công!')),
        );
        Navigator.of(context).pop<BookingModel>(booking);
      } else {
        // thanh toán fail hoặc user back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bạn chưa thanh toán. Booking vẫn ở trạng thái pending.',
            ),
          ),
        );
        // vẫn pop booking để bookings_page thấy booking pending
        Navigator.of(context).pop<BookingModel>(booking);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi đặt phòng: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _incAdults() {
    setState(() {
      _adults++;
    });
  }

  void _decAdults() {
    if (_adults <= 1) return;
    setState(() {
      _adults--;
    });
  }

  void _incChildren() {
    setState(() {
      _children++;
    });
  }

  void _decChildren() {
    if (_children <= 0) return;
    setState(() {
      _children--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hotel = widget.hotel;
    final room = widget.roomType;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm booking')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hotel.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('${hotel.city} • ${hotel.address}'),
            const SizedBox(height: 16),
            Text(
              room.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text('Max ${room.capacity} guests'),
            if (room.bedType != null) ...[
              const SizedBox(height: 4),
              Text('Bed: ${room.bedType!}'),
            ],
            const SizedBox(height: 8),
            Text(
              '\$${room.pricePerNight.toStringAsFixed(0)} / night',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 24),

            // Chọn ngày
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickCheckIn,
                    child: Column(
                      children: [
                        const Text('Check-in'),
                        const SizedBox(height: 4),
                        Text(_formatDate(_checkIn)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickCheckOut,
                    child: Column(
                      children: [
                        const Text('Check-out'),
                        const SizedBox(height: 4),
                        Text(_formatDate(_checkOut)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$_nights night(s)'),

            const SizedBox(height: 16),

            // Guests (adults / children)
            Text(
              'Guests',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _GuestCounter(
                    label: 'Adults',
                    value: _adults,
                    onDecrement: _decAdults,
                    onIncrement: _incAdults,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GuestCounter(
                    label: 'Children',
                    value: _children,
                    onDecrement: _decChildren,
                    onIncrement: _incChildren,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total:', style: theme.textTheme.titleMedium),
                Text(
                  _nights > 0 ? '\$${_totalPrice.toStringAsFixed(0)}' : '--',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onConfirm,
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Confirm booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestCounter extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _GuestCounter({
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onDecrement,
          ),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}
