import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../cubit/chatbot_cubit.dart';
import '../cubit/chatbot_state.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- UI Action: Cuộn xuống cuối (Giữ ở UI vì liên quan đến ScrollController) ---
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // --- UI Action: Kiểm tra Auth và Gửi (Giữ một chút để check nhanh UI) ---
  void _handleSend(ChatbotCubit cubit) {
    if (Supabase.instance.client.auth.currentSession == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng đăng nhập.')));
      return;
    }
    cubit.send(_controller.text.trim());
    _controller.clear();
  }

  // --- UI Action: Mở Picker hệ thống ---
  Future<void> _pickDateRange(ChatbotCubit cubit, ChatbotState state) async {
    if (state.botContext['hotel_id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chọn khách sạn trước.')));
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) cubit.onDateRangeSelected(picked);
  }

  Future<void> _showGuestPicker(ChatbotCubit cubit, int currentGuests) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        int temp = currentGuests;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Số khách',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed:
                              temp <= 1
                                  ? null
                                  : () => setModalState(() => temp--),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$temp',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModalState(() => temp++),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (result != null) cubit.updateGuests(result);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatbotCubit>();

    return Scaffold(
      appBar: AppBar(title: const Text('Travel AI Assistant')),
      body: BlocConsumer<ChatbotCubit, ChatbotState>(
        listener: (context, state) => _scrollToBottom(),
        builder: (context, state) {
          final noHotel = state.botContext['hotel_id'] == null;
          return Column(
            children: [
              _buildTopQuickActions(state, cubit),
              if (noHotel) _buildCityChips(cubit),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: state.messages.length,
                  itemBuilder:
                      (ctx, i) =>
                          _buildMessageBubble(state.messages[i], state, cubit),
                ),
              ),
              if (state.isSending) const LinearProgressIndicator(),
              _buildInputArea(state, cubit),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopQuickActions(ChatbotState state, ChatbotCubit cubit) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ActionChip(
            label: const Text('Booking của tôi'),
            onPressed: () => cubit.send('list_bookings'),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: Text('Khách: ${state.guests}'),
            onPressed: () => _showGuestPicker(cubit, state.guests),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text('Reset'),
            onPressed: () => cubit.reset(),
          ),
        ],
      ),
    );
  }

  Widget _buildCityChips(ChatbotCubit cubit) {
    return Container(
      height: 45,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children:
            ['Hà Nội', 'Đà Nẵng', 'TP.HCM']
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(c),
                      onPressed: () => cubit.send('tìm khách sạn ở $c'),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessageEntity m,
    ChatbotState state,
    ChatbotCubit cubit,
  ) {
    bool isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.content),
            if (m.hotels != null)
              ...m.hotels!.map((h) => _buildHotelCard(h, cubit, state)),
            if (m.availability != null)
              ...m.availability!.map((r) => _buildRoomCard(r, state, cubit)),
          ],
        ),
      ),
    );
  }

  Widget _buildHotelCard(dynamic h, ChatbotCubit cubit, ChatbotState state) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        title: Text(
          h['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(h['city'] ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          cubit.updateBotContext({'hotel_id': h['id']});
          _pickDateRange(cubit, state);
        },
      ),
    );
  }

  Widget _buildRoomCard(dynamic r, ChatbotState state, ChatbotCubit cubit) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        title: Text(r['name'] ?? 'Phòng'),
        subtitle: Text(
          'Giá: ${state.formatVnd(r['price_per_night'])}',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: state.isSending ? null : () => cubit.bookRoom(r),
          child: const Text('Đặt ngay'),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatbotState state, ChatbotCubit cubit) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _handleSend(cubit),
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: state.isSending ? null : () => _handleSend(cubit),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
