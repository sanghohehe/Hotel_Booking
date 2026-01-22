import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/profile_api.dart';
import '../../data/user_profile_model.dart';

class EditProfilePage extends StatefulWidget {
  final UserProfileModel? initialProfile;
  final String initialEmail;
  final String initialFullName;

  const EditProfilePage({
    super.key,
    required this.initialEmail,
    required this.initialFullName,
    this.initialProfile,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _api = ProfileApi();
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _picker = ImagePicker();

  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  DateTime? _dob;
  bool _saving = false;

  String? _currentAvatarUrl;
  XFile? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _fullNameController = TextEditingController(
      text: p?.fullName ?? widget.initialFullName,
    );
    _phoneController = TextEditingController(text: p?.phoneNumber ?? '');
    _addressController = TextEditingController(text: p?.address ?? '');
    _dob = p?.dateOfBirth;
    _currentAvatarUrl = p?.avatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (file != null) {
      setState(() {
        _newAvatarFile = file;
      });
    }
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    String? avatarUrl = _currentAvatarUrl;

    try {
      // Nếu user chọn avatar mới -> upload lên Supabase
      if (_newAvatarFile != null) {
        final bytes = await _newAvatarFile!.readAsBytes();
        final ext = _newAvatarFile!.name.split('.').last.toLowerCase();
        avatarUrl = await _api.uploadAvatar(bytes, ext);
      }

      await _api.upsertMyProfile(
        fullName: _fullNameController.text.trim(),
        phoneNumber:
            _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
        dateOfBirth: _dob,
        address:
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        avatarUrl: avatarUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật profile thành công')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDob(DateTime? d) {
    if (d == null) return 'Not set';
    return _dateFormat.format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Quyết định ảnh avatar dùng gì:
    ImageProvider? avatarImage;
    if (_newAvatarFile != null) {
      // Preview ảnh mới chọn từ gallery
      avatarImage = FileImage(File(_newAvatarFile!.path));
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      // Nếu chưa chọn mới, dùng ảnh từ server
      avatarImage = NetworkImage(_currentAvatarUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: avatarImage,
                      child:
                          avatarImage == null
                              ? const Icon(Icons.person, size: 40)
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Personal information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                enabled: false,
                initialValue: widget.initialEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _pickDob,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDob(_dob)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _onSave,
                  child:
                      _saving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
