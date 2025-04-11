class UserModel {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profileImageUrl;
  final String? profileImageBase64;
  final bool isAdmin;
  final String userType; // 'normal', 'astrologer'
  final String? astrologerStatus; // null, 'pending', 'approved', 'rejected'
  final String? aboutMe;
  final List<String>? services;
  final String? zodiacSign;
  final bool offersFreeSession;

  UserModel({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.profileImageUrl,
    this.profileImageBase64,
    this.isAdmin = false,
    this.userType = 'normal',
    this.astrologerStatus,
    this.aboutMe,
    this.services,
    this.zodiacSign,
    this.offersFreeSession = false,
  });

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    } else {
      return 'مستخدم';
    }
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      firstName: data['first_name'],
      lastName: data['last_name'],
      profileImageUrl: data['profile_image_url'],
      profileImageBase64: data['profile_image_base64'],
      isAdmin: data['is_admin'] ?? false,
      userType: data['user_type'] ?? 'normal',
      astrologerStatus: data['astrologer_status'],
      aboutMe: data['about_me'],
      services:
          data['services'] != null ? List<String>.from(data['services']) : null,
      zodiacSign: data['zodiac_sign'],
      offersFreeSession: data['offers_free_sessions'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'profile_image_url': profileImageUrl,
      'profile_image_base64': profileImageBase64,
      'is_admin': isAdmin,
      'user_type': userType,
      'astrologer_status': astrologerStatus,
      'about_me': aboutMe,
      'services': services,
      'zodiac_sign': zodiacSign,
      'offers_free_sessions': offersFreeSession,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    String? profileImageUrl,
    String? profileImageBase64,
    bool? isAdmin,
    String? userType,
    String? astrologerStatus,
    String? aboutMe,
    List<String>? services,
    String? zodiacSign,
    bool? offersFreeSession,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      profileImageBase64: profileImageBase64 ?? this.profileImageBase64,
      isAdmin: isAdmin ?? this.isAdmin,
      userType: userType ?? this.userType,
      astrologerStatus: astrologerStatus ?? this.astrologerStatus,
      aboutMe: aboutMe ?? this.aboutMe,
      services: services ?? this.services,
      zodiacSign: zodiacSign ?? this.zodiacSign,
      offersFreeSession: offersFreeSession ?? this.offersFreeSession,
    );
  }
}
