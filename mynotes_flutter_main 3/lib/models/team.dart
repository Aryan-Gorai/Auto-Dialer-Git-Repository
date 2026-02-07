import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a team stored in Firestore `teams` collection.
class Team {
  final String id;
  final String ownerId;
  final String teamName;
  final String joinCode;
  final List<String> members; // List of user IDs
  final DateTime? createdAt;

  const Team({
    required this.id,
    required this.ownerId,
    required this.teamName,
    required this.joinCode,
    this.members = const [],
    this.createdAt,
  });

  factory Team.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Team(
      id: doc.id,
      ownerId: (data['owner_id'] ?? '').toString(),
      teamName: (data['team_name'] ?? '').toString(),
      joinCode: (data['join_code'] ?? '').toString(),
      members: List<String>.from(data['members'] ?? []),
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'owner_id': ownerId,
      'team_name': teamName,
      'join_code': joinCode,
      'members': members,
      'created_at': FieldValue.serverTimestamp(),
    };
  }
}
