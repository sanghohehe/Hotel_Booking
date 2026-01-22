import 'package:flutter/material.dart';

import '../../data/booking_api.dart';
import '../../data/models/booking_model.dart';

class PaymentPage extends StatefulWidget {
  final BookingModel booking;

  const PaymentPage({super.key, required this.booking});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _api = BookingApi();

  bool _isPaying = false;
  String _method = 'momo'; // default

  Future<void> _pay({required bool success}) async {
    if (_isPaying) return;

    setState(() => _isPaying = true);

    try {
      // giả lập xử lý thanh toán
      await Future.delayed(const Duration(seconds: 2));

      await _api.payMock(
        bookingId: widget.booking.id,
        method: _method,
        success: success,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Thanh toán thành công (mock)!'
                : 'Thanh toán thất bại (mock)!',
          ),
        ),
      );

      // trả kết quả về BookingConfirmPage
      Navigator.of(context).pop<bool>(success);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi thanh toán: $e')));
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              b.hotelName ?? 'Unknown hotel',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (b.roomTypeName != null) Text(b.roomTypeName!),
            const SizedBox(height: 8),
            Text('Booking ID: ${b.id}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            Text(
              'Total: \$${b.totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text(
              'Choose payment method (Mock)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            RadioListTile<String>(
              value: 'momo',
              groupValue: _method,
              onChanged: _isPaying ? null : (v) => setState(() => _method = v!),
              title: const Text('MoMo (Mock)'),
            ),
            RadioListTile<String>(
              value: 'vnpay',
              groupValue: _method,
              onChanged: _isPaying ? null : (v) => setState(() => _method = v!),
              title: const Text('VNPay (Mock)'),
            ),
            RadioListTile<String>(
              value: 'visa',
              groupValue: _method,
              onChanged: _isPaying ? null : (v) => setState(() => _method = v!),
              title: const Text('Visa/Master (Mock)'),
            ),

            const Spacer(),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isPaying ? null : () => _pay(success: false),
                    child:
                        _isPaying
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Fail (Test)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isPaying ? null : () => _pay(success: true),
                    child:
                        _isPaying
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Pay now (Mock)'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Center(
              child: Text(
                '⚠️ Đây là thanh toán giả lập, không trừ tiền thật.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
