import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../supabase/supabase_manager.dart';
import '../../../bookings/data/booking_api.dart';
import '../../../favorites/data/favorite_api.dart';
import '../../../auth/presentation/pages/sign_in_page.dart';
import '../../data/profile_api.dart';
import '../../data/user_profile_model.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final String email;

  const ProfilePage({super.key, required this.email});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _bookingApi = BookingApi();
  final _favoriteApi = FavoriteApi();
  final _profileApi = ProfileApi();
  final _dateFormat = DateFormat('dd/MM/yyyy');

  bool _loadingStats = true;
  int _bookingCount = 0;
  int _favoriteCount = 0;

  bool _loadingProfile = true;
  String _fullName = '';
  UserProfileModel? _profile;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadProfileInfo(), _loadStats()]);
  }

  Future<void> _loadStats() async {
    try {
      final bookingCount = await _bookingApi.getMyBookingCount();
      final favoriteCount = await _favoriteApi.getMyFavoriteCount();

      if (!mounted) return;
      setState(() {
        _bookingCount = bookingCount;
        _favoriteCount = favoriteCount;
        _loadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingStats = false;
      });
    }
  }

  Future<void> _loadProfileInfo() async {
    final client = SupabaseManager.client;
    final user = client.auth.currentUser;

    final fullNameMeta = (user?.userMetadata?['full_name'] as String?) ?? '';

    try {
      final profile = await _profileApi.getMyProfile();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _fullName = profile?.fullName ?? fullNameMeta;
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fullName = fullNameMeta;
        _loadingProfile = false;
      });
    }
  }

  Future<void> _signOut() async {
    await SupabaseManager.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInPage()),
      (route) => false,
    );
  }

  Future<void> _onEditProfile() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => EditProfilePage(
              initialEmail: widget.email,
              initialFullName: _fullName,
              initialProfile: _profile,
            ),
      ),
    );

    if (result == true) {
      // reload lại info & stats
      _loadProfileInfo();
      _loadStats();
    }
  }

  String _getInitials() {
    final sourceName =
        _fullName.trim().isNotEmpty ? _fullName.trim() : widget.email;
    if (sourceName.isEmpty) return '?';

    final parts = sourceName.split(' ');
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _formatDob(DateTime? d) {
    if (d == null) return 'Not set';
    return _dateFormat.format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameToShow = _fullName.trim().isNotEmpty ? _fullName.trim() : 'Guest';
    final phone = _profile?.phoneNumber ?? 'Not set';
    final address = _profile?.address ?? 'Not set';
    final dobText = _formatDob(_profile?.dateOfBirth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _onEditProfile,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Avatar + name + email
              if (_loadingProfile)
                const CircleAvatar(
                  radius: 36,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (_profile?.avatarUrl != null &&
                    _profile!.avatarUrl!.isNotEmpty)
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: NetworkImage(_profile!.avatarUrl!),
                  )
                else
                  CircleAvatar(
                    radius: 36,
                    child: Text(
                      _getInitials(),
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  nameToShow,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Stats
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (_loadingStats)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: CircularProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Bookings',
                        value: _bookingCount.toString(),
                        icon: Icons.book_online_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Favorites',
                        value: _favoriteCount.toString(),
                        icon: Icons.favorite_border,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Personal info',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              _InfoTile(
                icon: Icons.phone_android_outlined,
                label: 'Phone',
                value: phone,
              ),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.cake_outlined,
                label: 'Date of birth',
                value: dobText,
              ),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.home_outlined,
                label: 'Address',
                value: address,
              ),

              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(widget.email),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Sign out',
                  style: TextStyle(color: Colors.redAccent),
                ),
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
