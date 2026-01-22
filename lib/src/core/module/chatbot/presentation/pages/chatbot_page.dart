import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _sending = false;

  final Map<String, dynamic> _context = {};
  final List<Map<String, dynamic>> _messages = [];

  String? _selectedHotelName;
  String? _selectedRoomName;
  DateTimeRange? _dateRange;
  int _guests = 2;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _formatVnd(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (n == null) return '';
    final s = n.toStringAsFixed(0);
    final withDots = s.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => '.',
    );
    return '${withDots}đ';
  }

  Future<void> _send({String? overrideText, bool addUserBubble = true}) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn cần đăng nhập trước khi dùng chatbot.'),
        ),
      );
      return;
    }

    setState(() {
      _sending = true;
      if (addUserBubble) {
        _messages.add({'role': 'user', 'content': text});
      }
      if (overrideText == null) _controller.clear();
    });
    _scrollToBottom();

    try {
      final history =
          _messages
              .where((m) => m['role'] != null && m['content'] != null)
              .take(10)
              .map((m) => {'role': m['role'], 'content': m['content']})
              .toList();

      final res = await Supabase.instance.client.functions.invoke(
        'chatbot',
        body: {'message': text, 'history': history, 'context': _context},
      );

      final data = res.data;
      final reply =
          (data is Map && data['reply'] != null)
              ? data['reply'].toString()
              : 'Chatbot không trả về dữ liệu hợp lệ.';

      List<dynamic>? hotels;
      if (data is Map && data['hotels'] is List)
        hotels = data['hotels'] as List;

      List<dynamic>? availability;
      if (data is Map && data['availability'] is List) {
        availability = data['availability'] as List;
      }

      List<dynamic>? bookings;
      if (data is Map && data['bookings'] is List)
        bookings = data['bookings'] as List;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': reply,
          if (hotels != null) 'hotels': hotels,
          if (availability != null) 'availability': availability,
          if (bookings != null) 'bookings': bookings,
        });
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Mình gặp lỗi khi gọi chatbot.\n\nChi tiết: $e',
        });
      });
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickGuests() async {
    final g = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        int temp = _guests;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Số khách',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed:
                          temp <= 1
                              ? null
                              : () {
                                temp--;
                                (ctx as Element).markNeedsBuild();
                              },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text(
                      '$temp',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        temp++;
                        (ctx as Element).markNeedsBuild();
                      },
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: const Text('Xong'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (g == null) return;
    setState(() {
      _guests = g;
      _context['guests'] = _guests;
    });
  }

  Future<void> _pickDateRangeAndAutoCheck() async {
    final hotelId = _context['hotel_id']?.toString();
    if (hotelId == null || hotelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần chọn khách sạn trước.')),
      );
      return;
    }

    final now = DateTime.now();
    final initialStart = _dateRange?.start ?? now.add(const Duration(days: 1));
    final initialEnd = _dateRange?.end ?? now.add(const Duration(days: 2));

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      helpText: 'Chọn ngày check-in / check-out',
    );

    if (picked == null) return;

    setState(() {
      _dateRange = picked;
      _context['check_in'] = _fmt(picked.start);
      _context['check_out'] = _fmt(picked.end);

      // đổi ngày => reset room đã chọn
      _context.remove('room_type_id');
      _selectedRoomName = null;
    });

    await _send(
      overrideText:
          'còn phòng (${_context['check_in']} → ${_context['check_out']}, $_guests khách)',
      addUserBubble: true,
    );
  }

  Future<void> _chooseHotel(Map<String, dynamic> hotel) async {
    final hotelId = hotel['id']?.toString();
    final name = hotel['name']?.toString() ?? 'Khách sạn';

    if (hotelId == null || hotelId.isEmpty) return;

    setState(() {
      _context['hotel_id'] = hotelId;
      _context['city'] = hotel['city'];
      _selectedHotelName = name;

      _dateRange = null;
      _context.remove('check_in');
      _context.remove('check_out');

      _context.remove('room_type_id');
      _selectedRoomName = null;
    });

    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': 'Đã chọn **$name** ✅ Bây giờ bạn chỉ cần chọn ngày.',
      });
    });
    _scrollToBottom();

    await _pickDateRangeAndAutoCheck();
  }

  void _chooseRoom(Map<String, dynamic> room) {
    final id = (room['room_type_id'] ?? room['id'])?.toString();
    final name = room['name']?.toString() ?? 'Room';

    if (id == null || id.isEmpty) return;

    setState(() {
      _context['room_type_id'] = id;
      _selectedRoomName = name;

      _messages.add({
        'role': 'assistant',
        'content': '✅ Đã chọn phòng **$name**. Giờ bạn bấm **Đặt phòng**.',
      });
    });
    _scrollToBottom();
  }

  Future<void> _createBooking() async {
    final hotelId = _context['hotel_id']?.toString();
    final roomId = _context['room_type_id']?.toString();
    final checkIn = _context['check_in']?.toString();
    final checkOut = _context['check_out']?.toString();

    if (hotelId == null ||
        roomId == null ||
        checkIn == null ||
        checkOut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiếu thông tin (hotel/phòng/ngày).')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Xác nhận đặt phòng'),
            content: Text(
              'Khách sạn: ${_selectedHotelName ?? ''}\n'
              'Phòng: ${_selectedRoomName ?? ''}\n'
              'Ngày: $checkIn → $checkOut\n'
              'Khách: $_guests',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Đặt phòng'),
              ),
            ],
          ),
    );

    if (ok != true) return;

    await _send(overrideText: 'đặt phòng', addUserBubble: true);
  }

  // ======= Booking actions (no typing) =======
  Future<void> _showMyBookings() async {
    await _send(overrideText: 'list_bookings', addUserBubble: true);
  }

  Future<void> _cancelBooking(Map<String, dynamic> b) async {
    final id = b['id']?.toString();
    if (id == null || id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Hủy booking?'),
            content: Text('Bạn chắc chắn muốn hủy booking này?\nID: $id'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Không'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hủy'),
              ),
            ],
          ),
    );
    if (ok != true) return;

    setState(() {
      _context['booking_id'] = id;
    });

    await _send(overrideText: 'cancel_booking', addUserBubble: true);

    // refresh list (no user bubble)
    await _send(overrideText: 'list_bookings', addUserBubble: false);
  }

  Future<void> _rescheduleBooking(Map<String, dynamic> b) async {
    final id = b['id']?.toString();
    if (id == null || id.isEmpty) return;

    final status = (b['status'] ?? '').toString();
    if (status == 'cancelled') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking đã hủy, không thể đổi ngày.')),
      );
      return;
    }

    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Chọn ngày mới',
    );
    if (picked == null) return;

    // set context để backend check + update
    setState(() {
      _context['booking_id'] = id;
      _context['hotel_id'] = b['hotel_id'];
      _context['room_type_id'] = b['room_type_id'];
      _context['check_in'] = _fmt(picked.start);
      _context['check_out'] = _fmt(picked.end);

      final ga =
          (b['guests_adults'] is int)
              ? b['guests_adults'] as int
              : int.tryParse('${b['guests_adults']}') ?? _guests;
      _context['guests'] = ga;
    });

    await _send(overrideText: 'reschedule_booking', addUserBubble: true);

    // refresh list (no user bubble)
    await _send(overrideText: 'list_bookings', addUserBubble: false);
  }

  void _clearSelectionAll() {
    setState(() {
      _context.clear();
      _selectedHotelName = null;
      _selectedRoomName = null;
      _dateRange = null;
      _guests = 2;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã reset lựa chọn.')));
  }

  Widget _topQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: _sending ? null : _showMyBookings,
            icon: const Icon(Icons.book_online),
            label: const Text('Booking của tôi'),
          ),
          OutlinedButton.icon(
            onPressed: _sending ? null : _pickGuests,
            icon: const Icon(Icons.people_alt_outlined),
            label: Text('Khách: $_guests'),
          ),
          OutlinedButton.icon(
            onPressed: _sending ? null : _clearSelectionAll,
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _cityChips() {
    const cities = ['Hà Nội', 'Đà Nẵng', 'TP.HCM'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Row(
        children:
            cities.map((c) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(c),
                  onPressed:
                      _sending
                          ? null
                          : () => _send(overrideText: 'tìm khách sạn ở $c'),
                ),
              );
            }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotelId = _context['hotel_id']?.toString();
    final hasHotel = hotelId != null && hotelId.isNotEmpty;

    final hasDate =
        _context['check_in'] != null && _context['check_out'] != null;
    final hasRoom = _context['room_type_id'] != null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          hasHotel
              ? (_selectedHotelName ?? 'Chatbot Booking')
              : 'Chatbot Booking',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (hasHotel)
            IconButton(
              tooltip: 'Chọn ngày',
              onPressed: _sending ? null : _pickDateRangeAndAutoCheck,
              icon: const Icon(Icons.calendar_month),
            ),
        ],
      ),
      body: Column(
        children: [
          _topQuickActions(),
          if (!hasHotel) _cityChips(),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final m = _messages[index];
                final isUser = m['role'] == 'user';
                final content = (m['content'] ?? '').toString();

                final hotels =
                    (m['hotels'] is List) ? (m['hotels'] as List) : null;
                final availability =
                    (m['availability'] is List)
                        ? (m['availability'] as List)
                        : null;
                final bookings =
                    (m['bookings'] is List) ? (m['bookings'] as List) : null;

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.90,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isUser
                              ? Colors.blue.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          style: const TextStyle(fontSize: 14.5, height: 1.35),
                        ),

                        // Hotels list
                        if (!isUser && hotels != null && hotels.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          ...hotels.map((h) {
                            final hotel = Map<String, dynamic>.from(h as Map);
                            final name = hotel['name']?.toString() ?? 'Hotel';
                            final city = hotel['city']?.toString() ?? '';
                            final rating =
                                hotel['star_rating']?.toString() ?? '';
                            final address = hotel['address']?.toString() ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (rating.isNotEmpty) '$rating★',
                                            if (city.isNotEmpty) city,
                                          ].join(' • '),
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        if (address.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            address,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _sending
                                            ? null
                                            : () => _chooseHotel(hotel),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Chọn'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // Availability list (choose room)
                        if (!isUser &&
                            availability != null &&
                            availability.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          const Text(
                            'Chọn loại phòng',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...availability.map((r) {
                            final room = Map<String, dynamic>.from(r as Map);
                            final name = room['name']?.toString() ?? 'Room';
                            final available =
                                (room['available_rooms'] ?? 0).toString();
                            final inventory =
                                (room['inventory'] ?? 0).toString();
                            final price = room['price_per_night'];

                            final priceText =
                                price == null ? '' : '${_formatVnd(price)}/đêm';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Còn: $available / $inventory',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        if (priceText.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            priceText,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        _sending
                                            ? null
                                            : () => _chooseRoom(room),
                                    child: const Text('Chọn phòng'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // Bookings list (cancel/reschedule)
                        if (!isUser &&
                            bookings != null &&
                            bookings.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          const Text(
                            'Booking của bạn',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          ...bookings.map((x) {
                            final b = Map<String, dynamic>.from(x as Map);
                            final id = b['id']?.toString() ?? '';
                            final hotelName =
                                b['hotel_name']?.toString() ?? 'Hotel';
                            final roomName =
                                b['room_name']?.toString() ?? 'Room';
                            final ci = b['check_in']?.toString() ?? '';
                            final co = b['check_out']?.toString() ?? '';
                            final status = b['status']?.toString() ?? '';
                            final pay = b['payment_status']?.toString() ?? '';
                            final price = b['total_price'];

                            final priceText =
                                price == null ? '' : _formatVnd(price);

                            final canAction =
                                status != 'cancelled' &&
                                status != 'completed' &&
                                status != 'done';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$hotelName — $roomName',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$ci → $co',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Status: $status • Payment: $pay',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  if (priceText.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tổng: $priceText',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed:
                                              _sending || !canAction
                                                  ? null
                                                  : () => _rescheduleBooking(b),
                                          child: const Text('Đổi ngày'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              _sending || !canAction
                                                  ? null
                                                  : () => _cancelBooking(b),
                                          child: const Text('Hủy'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (id.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'ID: $id',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom actions (booking flow)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child:
                  hasHotel
                      ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _sending ? null : _pickDateRangeAndAutoCheck,
                              icon: const Icon(Icons.calendar_month),
                              label: Text(hasDate ? 'Đổi ngày' : 'Chọn ngày'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _sending || !hasDate
                                      ? null
                                      : () => _send(
                                        overrideText:
                                            'còn phòng (${_context['check_in']} → ${_context['check_out']}, $_guests khách)',
                                      ),
                              icon: const Icon(Icons.search),
                              label: const Text('Kiểm tra'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed:
                                  _sending || !hasDate || !hasRoom
                                      ? null
                                      : _createBooking,
                              icon: const Icon(Icons.shopping_bag_outlined),
                              label: const Text('Đặt phòng'),
                            ),
                          ),
                        ],
                      )
                      : Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText:
                                    'Bạn có thể gõ: tìm khách sạn ở Hà Nội',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: _sending ? null : _send,
                            icon:
                                _sending
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.send),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
