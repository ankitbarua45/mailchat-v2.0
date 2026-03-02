class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? profileImageUrl;
  final String? fullName;
  final String? bio;
  final DateTime createdAt;
  final bool isOnline;
  final DateTime? lastSeen;
  final List<String> blockedUsers;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.profileImageUrl,
    this.fullName,
    this.bio,
    required this.createdAt,
    this.isOnline = false,
    this.lastSeen,
    this.blockedUsers = const [],
  });

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'fullName': fullName,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'isOnline': isOnline,
      'lastSeen': lastSeen?.toIso8601String(),
      'blockedUsers': blockedUsers,
    };
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      fullName: map['fullName'],
      bio: map['bio'],
      createdAt: DateTime.parse(map['createdAt']),
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] != null
          ? DateTime.parse(map['lastSeen'])
          : null,
      blockedUsers: map['blockedUsers'] != null
          ? List<String>.from(map['blockedUsers'])
          : [],
    );
  }

  // CopyWith method for updating user data
  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? profileImageUrl,
    String? fullName,
    String? bio,
    DateTime? createdAt,
    bool? isOnline,
    DateTime? lastSeen,
    List<String>? blockedUsers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      fullName: fullName ?? this.fullName,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      blockedUsers: blockedUsers ?? this.blockedUsers,
    );
  }
}
