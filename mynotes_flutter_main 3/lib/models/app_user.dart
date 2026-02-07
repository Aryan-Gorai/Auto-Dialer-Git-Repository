import 'package:cloud_firestore/cloud_firestore.dart';

/// User roles in the app.
enum UserRole {
  teamMember,
  teamOwner;

  String get value {
    switch (this) {
      case UserRole.teamMember:
        return 'team_member';
      case UserRole.teamOwner:
        return 'team_owner';
    }
  }

  static UserRole? fromString(String? value) {
    switch (value) {
      case 'team_member':
        return UserRole.teamMember;
      case 'team_owner':
        return UserRole.teamOwner;
      default:
        return null;
    }
  }
}

/// Represents a user profile stored in Firestore `user_profiles` collection.
class AppUser {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String about;
  final String photoUrl;
  final UserRole? role;
  final String? teamId;

  const AppUser({
    required this.id,
    required this.email,
    this.name = '',
    this.phone = '',
    this.about = '',
    this.photoUrl = '',
    this.role,
    this.teamId,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      id: doc.id,
      email: (data['email'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      about: (data['about'] ?? '').toString(),
      photoUrl: (data['photoUrl'] ?? '').toString(),
      role: UserRole.fromString(data['role'] as String?),
      teamId: data['team_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'user_id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'about': about,
      'photoUrl': photoUrl,
      'role': role?.value,
      'team_id': teamId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? name,
    String? phone,
    String? about,
    String? photoUrl,
    UserRole? role,
    String? teamId,
    bool clearTeamId = false,
  }) {
    return AppUser(
      id: id,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      teamId: clearTeamId ? null : (teamId ?? this.teamId),
    );
  }
}
