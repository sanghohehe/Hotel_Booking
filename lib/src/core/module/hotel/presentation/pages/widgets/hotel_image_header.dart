import 'package:flutter/material.dart';

class HotelImageHeader extends StatefulWidget {
  final List<String> images;
  final String? url; // Đây là fallback (thumbnail)

  const HotelImageHeader({super.key, required this.images, this.url});

  @override
  State<HotelImageHeader> createState() => _HotelImageHeaderState();
}

class _HotelImageHeaderState extends State<HotelImageHeader> {
  int _currentIndex = 0;
  // Thêm PageController để điều khiển chuyển trang bằng code
  final PageController _controller = PageController();

  @override
  void dispose() {
    _controller.dispose(); // Đừng quên dispose controller nhé
    super.dispose();
  }

  void _nextPage() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> displayList =
        widget.images.isNotEmpty
            ? widget.images
            : (widget.url != null ? [widget.url!] : []);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. PageView
        PageView.builder(
          controller: _controller, // Gán controller vào đây
          itemCount: displayList.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            return Image.network(displayList[index], fit: BoxFit.cover);
          },
        ),

        // 2. Nút Mũi tên bên trái
        if (_currentIndex > 0)
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
                onPressed: _previousPage,
              ),
            ),
          ),

        // 3. Nút Mũi tên bên phải
        if (_currentIndex < displayList.length - 1)
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                ),
                onPressed: _nextPage,
              ),
            ),
          ),

        // 4. Indicator số trang (giữ nguyên)
        if (displayList.length > 1)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1} / ${displayList.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
