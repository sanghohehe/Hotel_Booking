class UserProfileModel {
  final String userId;
  final String? fullName;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? address;
  final String? avatarUrl;

  UserProfileModel({
    required this.userId,
    this.fullName,
    this.phoneNumber,
    this.dateOfBirth,
    this.address,
    this.avatarUrl,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      dateOfBirth:
          json['date_of_birth'] != null
              ? DateTime.parse(json['date_of_birth'] as String)
              : null,
      address: json['address'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
