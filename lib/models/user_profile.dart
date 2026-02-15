/// Model representing user profile from Supabase
class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String? phone;
  final String? profileImageUrl;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.profileImageUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create from Supabase user data
  factory UserProfile.fromSupabaseUser(Map<String, dynamic> userData) {
    return UserProfile(
      id: userData['id'] ?? '',
      email: userData['email'] ?? '',
      name: userData['user_metadata']?['name'] ?? userData['user_metadata']?['full_name'],
      phone: userData['phone'],
      profileImageUrl: userData['user_metadata']?['avatar_url'],
      createdAt: userData['created_at'] != null
          ? DateTime.parse(userData['created_at'])
          : DateTime.now(),
    );
  }

  /// Create from JSON map
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'],
      phone: json['phone'],
      profileImageUrl: json['profile_image_url'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Get display name (name or email username)
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    // Extract username from email
    return email.split('@').first;
  }

  /// Get initials for avatar placeholder
  String get initials {
    final displayNameValue = displayName;
    final parts = displayNameValue.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayNameValue.isNotEmpty ? displayNameValue[0].toUpperCase() : '?';
  }

  /// Create a copy with updated fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? profileImageUrl,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserProfile(id: $id, email: $email, name: $name)';
  }
}
