import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../supabase/supabase_manager.dart';
import 'user_profile_model.dart';

class ProfileApi {
  final SupabaseClient _client = SupabaseManager.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw Exception('Not logged in');
    }
    return id;
  }

  /// Lấy profile của current user. Có thể trả về null nếu chưa có record.
  Future<UserProfileModel?> getMyProfile() async {
    final data =
        await _client
            .from('user_profiles')
            .select('*')
            .eq('user_id', _userId)
            .maybeSingle();

    if (data == null) return null;
    return UserProfileModel.fromJson(data as Map<String, dynamic>);
  }

  /// Upload avatar lên bucket 'avatars' và trả về public URL
  Future<String> uploadAvatar(Uint8List bytes, String fileExt) async {
    final filePath =
        '$_userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _client.storage
        .from('avatars')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png', // hoặc image/jpeg, không quá quan trọng
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);
    return publicUrl;
  }

  /// Tạo/Update profile (upsert theo user_id)
  Future<UserProfileModel> upsertMyProfile({
    String? fullName,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? address,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{
      'user_id': _userId,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'date_of_birth':
          dateOfBirth != null
              ? dateOfBirth.toIso8601String().split('T').first
              : null,
      'address': address,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (avatarUrl != null) {
      payload['avatar_url'] = avatarUrl;
    }

    final data =
        await _client
            .from('user_profiles')
            .upsert(payload)
            .select('*')
            .single();

    // Sync full_name sang user_metadata cho đẹp
    if (fullName != null && fullName.trim().isNotEmpty) {
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {'full_name': fullName.trim()}),
        );
      } catch (_) {
        // ignore if metadata update fails
      }
    }

    return UserProfileModel.fromJson(data as Map<String, dynamic>);
  }
}
