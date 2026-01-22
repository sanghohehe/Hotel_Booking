import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../bookings/data/booking_api.dart';
import '../../../bookings/presentation/pages/booking_confirm_page.dart';
import '../../../favorites/data/favorite_api.dart';
import '../../../reviews/data/models/review_model.dart';
import '../../../reviews/data/review_api.dart';
import '../../data/hotel_api.dart';
import '../../data/models/hotel_model.dart';

class HotelDetailPage extends StatefulWidget {
  final HotelModel hotel; // hotel từ list truyền sang (preview)
  final bool openReviewOnStart;

  const HotelDetailPage({
    super.key,
    required this.hotel,
    this.openReviewOnStart = false,
  });

  @override
  State<HotelDetailPage> createState() => _HotelDetailPageState();
}

class _HotelDetailPageState extends State<HotelDetailPage> {
  final _hotelApi = HotelApi();
  final _favoriteApi = FavoriteApi();
  final _reviewApi = ReviewApi();
  final _bookingApi = BookingApi();

  HotelModel? _detail;
  bool _loading = true;
  String? _error;

  bool _isFavorite = false;
  bool _favLoading = false;

  List<ReviewModel> _reviews = [];
  bool _loadingReviews = true;
  double _avgRating = 0;
  int get _reviewCount => _reviews.length;

  /// chỉ cho review nếu user có booking status = 'done' cho khách sạn này
  bool _canReview = false;
  bool _checkingCanReview = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadFavoriteStatus();
    _loadReviews();
    _checkCanReview();

    if (widget.openReviewOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // chờ check quyền review xong cho chắc
        await Future.delayed(const Duration(milliseconds: 250));
        if (!mounted) return;
        _openAddReviewDialog();
      });
    }
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _hotelApi.getHotelDetail(widget.hotel.id);
      if (!mounted) return;
      setState(() {
        _detail = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadFavoriteStatus() async {
    setState(() {
      _favLoading = true;
    });
    try {
      final fav = await _favoriteApi.isFavorite(widget.hotel.id);
      if (!mounted) return;
      setState(() {
        _isFavorite = fav;
      });
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loadingReviews = true;
    });
    try {
      final list = await _reviewApi.getReviewsForHotel(widget.hotel.id);
      double avg = 0;
      if (list.isNotEmpty) {
        final sum = list.fold<int>(0, (prev, e) => prev + e.rating);
        avg = sum / list.length;
      }
      if (!mounted) return;
      setState(() {
        _reviews = list;
        _avgRating = avg;
      });
    } catch (e) {
      // có thể log nếu muốn
    } finally {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  Future<void> _checkCanReview() async {
    setState(() {
      _checkingCanReview = true;
    });
    try {
      final can = await _bookingApi.hasBookingForHotel(widget.hotel.id);
      if (!mounted) return;
      setState(() {
        _canReview = can;
      });
    } catch (e) {
      // ignore hoặc log
    } finally {
      if (mounted) {
        setState(() {
          _checkingCanReview = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_favLoading) return;
    setState(() {
      _favLoading = true;
      _isFavorite = !_isFavorite;
    });

    try {
      if (_isFavorite) {
        await _favoriteApi.addFavorite(widget.hotel.id);
      } else {
        await _favoriteApi.removeFavorite(widget.hotel.id);
      }
    } catch (e) {
      if (!mounted) return;
      // revert nếu lỗi
      setState(() {
        _isFavorite = !_isFavorite;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật favorites: $e')));
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _openAddReviewDialog() async {
    if (!_canReview) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn cần có booking đã hoàn thành (done) mới được review.',
          ),
        ),
      );
      return;
    }

    final result = await showDialog<_AddReviewResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AddReviewDialog(),
    );

    if (result == null) return;

    try {
      // upload ảnh trước
      List<String> imageUrls = [];
      if (result.images.isNotEmpty) {
        imageUrls = await _reviewApi.uploadReviewImages(
          files: result.images,
          hotelId: widget.hotel.id,
        );
      }

      await _reviewApi.addReview(
        hotelId: widget.hotel.id,
        rating: result.rating,
        comment: result.comment?.trim().isEmpty == true ? null : result.comment,
        images: imageUrls.isEmpty ? null : imageUrls,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã gửi review')));
      _loadReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi gửi review: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hotel = _detail ?? widget.hotel; // nếu chưa load xong dùng preview

    return Scaffold(
      appBar: AppBar(
        title: Text(hotel.name),
        actions: [
          IconButton(
            onPressed: _favLoading ? null : _toggleFavorite,
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadDetail();
          await _loadFavoriteStatus();
          await _loadReviews();
          await _checkCanReview();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ảnh cover
              AspectRatio(
                aspectRatio: 16 / 9,
                child:
                    hotel.thumbnailUrl != null
                        ? Image.network(
                          hotel.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) =>
                                  Container(color: Colors.grey[300]),
                        )
                        : Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.hotel, size: 48),
                          ),
                        ),
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên + rating chung
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            hotel.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          hotel.starRating.toString(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Avg rating từ reviews (nếu có)
                    if (!_loadingReviews && _reviewCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.reviews, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            '${_avgRating.toStringAsFixed(1)} / 5.0 • $_reviewCount review(s)',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 18),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${hotel.city} • ${hotel.address}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (hotel.description != null &&
                        hotel.description!.trim().isNotEmpty) ...[
                      Text(
                        'Description',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hotel.description!,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_loading && _detail == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Lỗi tải chi tiết: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 8),

                    Text(
                      'Room types',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (hotel.roomTypes.isEmpty && !_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Text(
                          'Chưa có loại phòng nào. Hãy thêm dữ liệu vào bảng room_types.',
                        ),
                      ),

                    // List room types
                    ...hotel.roomTypes.map((room) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.people_outline, size: 16),
                                  const SizedBox(width: 4),
                                  Text('Max ${room.capacity} guests'),
                                  if (room.bedType != null) ...[
                                    const SizedBox(width: 12),
                                    const Icon(Icons.bed_outlined, size: 16),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        room.bedType!,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${room.pricePerNight.toStringAsFixed(0)} / night',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green[700],
                                ),
                              ),
                              if (room.description != null &&
                                  room.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  room.description!,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => BookingConfirmPage(
                                              hotel: hotel,
                                              roomType: room,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text('Book now'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 24),

                    // Reviews section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reviews',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_checkingCanReview)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else if (_canReview)
                          TextButton.icon(
                            onPressed: _openAddReviewDialog,
                            icon: const Icon(Icons.edit),
                            label: const Text('Write'),
                          )
                        else
                          const Text(
                            'Chỉ booking DONE mới review',
                            style: TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_loadingReviews)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_reviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Chưa có review nào. Hãy là người đầu tiên viết review!',
                        ),
                      )
                    else
                      Column(
                        children:
                            _reviews.map((r) {
                              final name = (r.username ?? 'User').trim();
                              final avatar = r.avatarUrl;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundImage:
                                                (avatar != null &&
                                                        avatar.isNotEmpty)
                                                    ? NetworkImage(avatar)
                                                    : null,
                                            child:
                                                (avatar == null ||
                                                        avatar.isEmpty)
                                                    ? Text(
                                                      name.isNotEmpty
                                                          ? name[0]
                                                              .toUpperCase()
                                                          : 'U',
                                                    )
                                                    : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: theme
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    ...List.generate(
                                                      5,
                                                      (i) => Icon(
                                                        i < r.rating
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        size: 14,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      r.createdAt
                                                          .toLocal()
                                                          .toString()
                                                          .split('.')
                                                          .first,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                            fontSize: 11,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (r.comment != null &&
                                          r.comment!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          r.comment!,
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],

                                      if (r.images.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 86,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: r.images.length,
                                            separatorBuilder:
                                                (_, __) =>
                                                    const SizedBox(width: 8),
                                            itemBuilder: (_, i) {
                                              final url = r.images[i];
                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.network(
                                                  url,
                                                  width: 110,
                                                  height: 86,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (_, __, ___) => Container(
                                                        width: 110,
                                                        height: 86,
                                                        color: Colors.grey[300],
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddReviewResult {
  final int rating;
  final String? comment;
  final List<File> images;

  const _AddReviewResult({
    required this.rating,
    required this.comment,
    required this.images,
  });
}

class _AddReviewDialog extends StatefulWidget {
  const _AddReviewDialog();

  @override
  State<_AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<_AddReviewDialog> {
  final _commentController = TextEditingController();
  final _picker = ImagePicker();

  int _rating = 5;
  final List<File> _images = [];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final files = await _picker.pickMultiImage(imageQuality: 80);
    if (!mounted) return;
    if (files.isEmpty) return;

    setState(() {
      _images.addAll(files.map((x) => File(x.path)));
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      _AddReviewResult(
        rating: _rating,
        comment: _commentController.text,
        images: List<File>.from(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Write a review'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                final filled = star <= _rating;
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Add photos'),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_images.length} selected',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

            if (_images.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 74,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_images.length, (i) {
                        final f = _images[i];
                        return Padding(
                          padding: EdgeInsets.only(
                            right: i == _images.length - 1 ? 0 : 8,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  f,
                                  width: 74,
                                  height: 74,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 2,
                                top: 2,
                                child: Material(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap:
                                        () =>
                                            setState(() => _images.removeAt(i)),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Submit')),
      ],
    );
  }
}
