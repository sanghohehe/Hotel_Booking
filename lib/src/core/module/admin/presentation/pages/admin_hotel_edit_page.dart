import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../supabase/supabase_manager.dart';
import '../../../hotel/data/hotel_api.dart';
import '../../../hotel/data/models/hotel_model.dart';

class AdminHotelEditPage extends StatefulWidget {
  final HotelModel? hotel; // null = create, != null = edit

  const AdminHotelEditPage({super.key, this.hotel});

  bool get isEdit => hotel != null;

  @override
  State<AdminHotelEditPage> createState() => _AdminHotelEditPageState();
}

class _AdminHotelEditPageState extends State<AdminHotelEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = HotelApi();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  late final TextEditingController _descController;

  double _rating = 4.0;
  String? _imageUrl; // url hiện tại trong DB
  XFile? _pickedImage; // ảnh mới chọn
  bool _saving = false;

  // room types
  List<RoomTypeModel> _roomTypes = [];
  bool _loadingRooms = false;

  @override
  void initState() {
    super.initState();
    final h = widget.hotel;
    _nameController = TextEditingController(text: h?.name ?? '');
    _cityController = TextEditingController(text: h?.city ?? '');
    _addressController = TextEditingController(text: h?.address ?? '');
    _descController = TextEditingController(text: h?.description ?? '');
    _rating = h?.starRating ?? 4.0;
    _imageUrl = h?.thumbnailUrl;

    if (widget.isEdit) {
      _loadRoomTypes();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomTypes() async {
    if (!widget.isEdit) return;
    setState(() {
      _loadingRooms = true;
    });
    try {
      final list = await _api.getRoomTypesForHotel(widget.hotel!.id);
      if (!mounted) return;
      setState(() {
        _roomTypes = list;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải room types: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _loadingRooms = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = picked;
      });
    }
  }

  Future<String?> _uploadImageIfNeeded() async {
    if (_pickedImage == null) return _imageUrl; // giữ nguyên nếu không đổi

    try {
      final client = SupabaseManager.client;
      final bytes = await _pickedImage!.readAsBytes();

      // 👉 đảm bảo đã tạo bucket 'hotel-images' (public) trong Supabase Storage
      final bucket = client.storage.from('hotel-images');

      final fileName =
          'hotel_${widget.hotel?.id ?? DateTime.now().millisecondsSinceEpoch}.jpg';

      await bucket.uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );

      final publicUrl = bucket.getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      if (!mounted) return _imageUrl;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi upload ảnh: $e')));
      return _imageUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final name = _nameController.text.trim();
      final city = _cityController.text.trim();
      final address = _addressController.text.trim();
      final desc =
          _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim();

      final thumbnailUrl = await _uploadImageIfNeeded();

      if (widget.isEdit) {
        await _api.updateHotel(
          id: widget.hotel!.id,
          name: name,
          city: city,
          address: address,
          description: desc,
          starRating: _rating,
          thumbnailUrl: thumbnailUrl,
        );
      } else {
        await _api.createHotel(
          name: name,
          city: city,
          address: address,
          description: desc,
          starRating: _rating,
          thumbnailUrl: thumbnailUrl,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? 'Hotel updated' : 'Hotel created'),
        ),
      );
      Navigator.of(context).pop(true); // báo màn trước reload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu hotel: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openRoomTypeForm({RoomTypeModel? room}) async {
    if (!widget.isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy tạo hotel trước rồi mới thêm phòng.'),
        ),
      );
      return;
    }

    final nameController = TextEditingController(text: room?.name ?? '');
    final priceController = TextEditingController(
      text: room?.pricePerNight.toString() ?? '',
    );
    final capacityController = TextEditingController(
      text: room?.capacity.toString() ?? '',
    );
    final bedController = TextEditingController(text: room?.bedType ?? '');
    final descController = TextEditingController(text: room?.description ?? '');

    final isEdit = room != null;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: bottomInset + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit room type' : 'Add room type',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price per night',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capacityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Capacity',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bedController,
                  decoration: const InputDecoration(
                    labelText: 'Bed type (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != true) return;

    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    final cap = int.tryParse(capacityController.text.trim());

    if (name.isEmpty || price == null || cap == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name, price, capacity are required')),
      );
      return;
    }

    try {
      if (isEdit) {
        await _api.updateRoomType(
          id: room!.id,
          name: name,
          pricePerNight: price,
          capacity: cap,
          bedType:
              bedController.text.trim().isEmpty
                  ? null
                  : bedController.text.trim(),
          description:
              descController.text.trim().isEmpty
                  ? null
                  : descController.text.trim(),
        );
      } else {
        await _api.createRoomType(
          hotelId: widget.hotel!.id,
          name: name,
          pricePerNight: price,
          capacity: cap,
          bedType:
              bedController.text.trim().isEmpty
                  ? null
                  : bedController.text.trim(),
          description:
              descController.text.trim().isEmpty
                  ? null
                  : descController.text.trim(),
        );
      }
      _loadRoomTypes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu room type: $e')));
    }
  }

  Future<void> _deleteRoomType(RoomTypeModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete room'),
            content: Text('Xoá loại phòng "${room.name}"?'),
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
      await _api.deleteRoomType(room.id);
      _loadRoomTypes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi xoá room type: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.isEdit;

    Widget buildImagePreview() {
      Widget child;
      if (_pickedImage != null) {
        child = Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
      } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        child = Image.network(
          _imageUrl!,
          fit: BoxFit.cover,
          errorBuilder:
              (_, __, ___) =>
                  const Center(child: Icon(Icons.broken_image, size: 40)),
        );
      } else {
        child = const Center(
          child: Icon(Icons.photo, size: 40, color: Colors.grey),
        );
      }

      return GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(color: Colors.grey[200], child: child),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.6),
                child: const Icon(
                  Icons.camera_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildRoomTypesSection() {
      if (!isEdit) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room types',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _openRoomTypeForm,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingRooms)
            const Center(child: CircularProgressIndicator())
          else if (_roomTypes.isEmpty)
            const Text('Chưa có loại phòng nào.')
          else
            Column(
              children:
                  _roomTypes.map((r) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(r.name),
                        subtitle: Text(
                          '\$${r.pricePerNight.toStringAsFixed(0)} / night • ${r.capacity} guest(s)',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openRoomTypeForm(room: r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteRoomType(r),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit hotel' : 'Create hotel')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                buildImagePreview(),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Star rating'),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: _rating,
                              min: 1,
                              max: 5,
                              divisions: 8,
                              label: _rating.toStringAsFixed(1),
                              onChanged: (v) {
                                setState(() {
                                  _rating = v;
                                });
                              },
                            ),
                          ),
                          Text(
                            _rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                buildRoomTypesSection(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon:
                        _saving
                            ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save),
                    label: Text(isEdit ? 'Save changes' : 'Create hotel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
