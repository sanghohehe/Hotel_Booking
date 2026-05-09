import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ChatbotPageState extends State<ChatbotPage>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _typingAnimController;
  bool _showScrollFab = false;

  // ─── Màu sắc theme ───────────────────────────────────────────────
  static const _primary = Color(0xFF0A84FF);
  static const _bgPage = Color(0xFFF2F6FC);
  static const _bubbleUser = Color(0xFF0A84FF);
  static const _bubbleBot = Colors.white;
  static const _textUser = Colors.white;
  static const _textBot = Color(0xFF1C1C1E);
  static const _chipBg = Color(0xFFE8F0FE);
  static const _chipText = Color(0xFF1A56DB);

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scrollController.addListener(() {
      final atBottom =
          _scrollController.position.maxScrollExtent -
              _scrollController.offset <
          120;
      if (atBottom != !_showScrollFab) {
        setState(() => _showScrollFab = !atBottom);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _handleSend(ChatbotCubit cubit) {
    if (Supabase.instance.client.auth.currentSession == null) {
      _showSnack('Vui lòng đăng nhập để tiếp tục.');
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    cubit.send(text);
    _controller.clear();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _pickDateRange(ChatbotCubit cubit, ChatbotState state) async {
    if (state.botContext['hotel_id'] == null) {
      _showSnack('Vui lòng chọn khách sạn trước.');
      return;
    }
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder:
          (context, child) => Theme(
            data: Theme.of(
              context,
            ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
            child: child!,
          ),
    );
    if (picked != null) cubit.onDateRangeSelected(picked);
  }

  Future<void> _showGuestPicker(ChatbotCubit cubit, int currentGuests) async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int temp = currentGuests;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Text(
                      'Số khách',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _textBot,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CounterButton(
                          icon: Icons.remove,
                          enabled: temp > 1,
                          onTap: () => setModalState(() => temp--),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            '$temp',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                        ),
                        _CounterButton(
                          icon: Icons.add,
                          enabled: temp < 20,
                          onTap: () => setModalState(() => temp++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, temp),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Xác nhận',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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

  // ─── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChatbotCubit>();

    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(cubit),
      floatingActionButton:
          _showScrollFab
              ? FloatingActionButton.small(
                onPressed: _scrollToBottom,
                backgroundColor: _primary,
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              )
              : null,
      body: BlocConsumer<ChatbotCubit, ChatbotState>(
        listener: (context, state) => _scrollToBottom(),
        builder: (context, state) {
          return Column(
            children: [
              _buildContextBar(state, cubit),
              if (state.botContext['hotel_id'] == null) _buildCityChips(cubit),
              Expanded(child: _buildMessageList(state, cubit)),
              if (state.isSending) _buildTypingIndicator(),
              _buildQuickReplies(state, cubit),
              _buildInputArea(state, cubit),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatbotCubit cubit) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.black12,
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A84FF), Color(0xFF34AADC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.travel_explore,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Travel AI',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textBot,
                ),
              ),
              Text(
                'Trợ lý đặt phòng',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _primary),
          tooltip: 'Cuộc hội thoại mới',
          onPressed: () {
            HapticFeedback.mediumImpact();
            context.read<ChatbotCubit>().reset();
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
    );
  }

  /// Thanh hiển thị context hiện tại (khách sạn, ngày, khách)
  Widget _buildContextBar(ChatbotState state, ChatbotCubit cubit) {
    final hasHotel = state.botContext['hotel_id'] != null;
    final hasDate = state.botContext['check_in'] != null;

    if (!hasHotel && !hasDate && state.guests == 1) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (hasHotel)
              _ContextChip(
                icon: Icons.hotel_outlined,
                label: 'Đã chọn khách sạn',
                color: Colors.green,
              ),
            if (hasHotel) const SizedBox(width: 6),
            if (hasDate)
              _ContextChip(
                icon: Icons.date_range_outlined,
                label:
                    '${state.botContext['check_in']} → ${state.botContext['check_out']}',
                color: Colors.orange,
              ),
            if (hasDate) const SizedBox(width: 6),
            _ContextChip(
              icon: Icons.person_outline,
              label: '${state.guests} khách',
              color: _primary,
              onTap: () => _showGuestPicker(cubit, state.guests),
            ),
            const SizedBox(width: 6),
            _ContextChip(
              icon: Icons.list_alt_outlined,
              label: 'Booking của tôi',
              color: Colors.purple,
              onTap: () => cubit.send('list_bookings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityChips(ChatbotCubit cubit) {
    final cities = ['Hà Nội', 'Đà Nẵng', 'TP.HCM', 'Hội An', 'Phú Quốc'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Tìm nhanh theo thành phố',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  cities.map((city) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: _chipText,
                        ),
                        label: Text(
                          city,
                          style: const TextStyle(
                            color: _chipText,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor: _chipBg,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () => cubit.send('tìm khách sạn ở $city'),
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatbotState state, ChatbotCubit cubit) {
    if (state.messages.isEmpty) {
      return _buildWelcomeScreen(cubit);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: state.messages.length,
      itemBuilder: (ctx, i) {
        final msg = state.messages[i];
        final showAvatar =
            msg.role == 'assistant' &&
            (i == 0 || state.messages[i - 1].role != 'assistant');
        return _buildMessageBubble(
          msg,
          state,
          cubit,
          showBotAvatar: showAvatar,
        );
      },
    );
  }

  Widget _buildWelcomeScreen(ChatbotCubit cubit) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A84FF), Color(0xFF34AADC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.travel_explore,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Xin chào! 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _textBot,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tôi có thể giúp bạn tìm khách sạn,\nkiểm tra phòng trống và đặt phòng.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _buildSuggestionsGrid(cubit),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsGrid(ChatbotCubit cubit) {
    final suggestions = [
      ('🏨', 'Tìm khách sạn ở Đà Nẵng', 'tìm khách sạn ở Đà Nẵng'),
      ('📋', 'Xem booking của tôi', 'list_bookings'),
      ('🌟', 'Khách sạn 5 sao Hà Nội', 'tìm khách sạn ở Hà Nội'),
      ('🏝️', 'Khách sạn Huế', 'tìm khách sạn ở Huế'),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.8,
      children:
          suggestions.map((s) {
            return InkWell(
              onTap: () => cubit.send(s.$3),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(s.$1, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.$2,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _textBot,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildMessageBubble(
    ChatMessageEntity m,
    ChatbotState state,
    ChatbotCubit cubit, {
    bool showBotAvatar = false,
  }) {
    final isUser = m.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Bot avatar
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child:
                  showBotAvatar
                      ? Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0A84FF), Color(0xFF34AADC)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.travel_explore,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                      : const SizedBox(width: 30),
            ),

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              margin: EdgeInsets.only(
                top: 2,
                bottom: 2,
                left: isUser ? 48 : 0,
                right: isUser ? 0 : 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _bubbleUser : _bubbleBot,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isUser
                            ? _primary.withOpacity(0.25)
                            : Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.content.isNotEmpty)
                    Text(
                      m.content,
                      style: TextStyle(
                        color: isUser ? _textUser : _textBot,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  if (m.hotels != null && m.hotels!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...m.hotels!.map((h) => _buildHotelCard(h, cubit, state)),
                  ],
                  if (m.availability != null && m.availability!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...m.availability!.map(
                      (r) => _buildRoomCard(r, state, cubit),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // User avatar placeholder (spacing)
          if (isUser) const SizedBox(width: 0),
        ],
      ),
    );
  }

  Widget _buildHotelCard(dynamic h, ChatbotCubit cubit, ChatbotState state) {
    final stars = (h['star_rating'] as num?)?.toInt() ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          cubit.updateBotContext({'hotel_id': h['id']});
          _pickDateRange(cubit, state);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail placeholder
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.hotel, color: Colors.blue.shade300, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h['name'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _textBot,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          h['city'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        if (stars > 0) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: List.generate(
                              stars.clamp(0, 5),
                              (_) => const Icon(
                                Icons.star,
                                size: 11,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoomCard(dynamic r, ChatbotState state, ChatbotCubit cubit) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['name'] ?? 'Phòng',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: _textBot,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.formatVnd(r['price_per_night']),
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (r['available_rooms'] != null)
                    Text(
                      'Còn ${r['available_rooms']} phòng',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: state.isSending ? null : () => cubit.bookRoom(r),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: const Text(
                'Đặt ngay',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 50, bottom: 8, top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _typingAnimController,
                builder: (_, __) {
                  final t = (_typingAnimController.value + i * 0.3) % 1.0;
                  final scale =
                      0.6 + 0.4 * (1 - (t - 0.5).abs() * 2).clamp(0, 1);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        color: _primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Quick reply buttons xuất hiện tùy context
  Widget _buildQuickReplies(ChatbotState state, ChatbotCubit cubit) {
    final suggestions = <String>[];

    if (state.botContext['hotel_id'] != null &&
        state.botContext['check_in'] == null) {
      suggestions.add('📅 Chọn ngày');
    }
    if (state.botContext['hotel_id'] != null &&
        state.botContext['check_in'] != null) {
      suggestions.add('🛏 Xem phòng trống');
    }
    if (state.messages.any((m) => m.role == 'assistant')) {
      suggestions.add('📋 Booking của tôi');
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      color: _bgPage,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              suggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      s,
                      style: const TextStyle(
                        color: _chipText,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: _chipBg,
                    side: BorderSide.none,
                    onPressed: () {
                      if (s.contains('Chọn ngày')) {
                        _pickDateRange(cubit, state);
                      } else if (s.contains('Xem phòng')) {
                        cubit.send('còn phòng không');
                      } else if (s.contains('Booking')) {
                        cubit.send('list_bookings');
                      }
                    },
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatbotState state, ChatbotCubit cubit) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _bgPage,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _handleSend(cubit),
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(fontSize: 15, color: _textBot),
                  decoration: const InputDecoration(
                    hintText: 'Nhập tin nhắn...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final hasText = _controller.text.trim().isNotEmpty;
                return GestureDetector(
                  onTap: state.isSending ? null : () => _handleSend(cubit),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          hasText && !state.isSending
                              ? _primary
                              : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color:
                          hasText && !state.isSending
                              ? Colors.white
                              : Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFE8F0FE) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF0A84FF) : Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ContextChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.arrow_drop_down, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
