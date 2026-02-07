import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_1/models/app_user.dart';
import 'package:flutter_application_1/models/team.dart';

/// Service for managing teams: creation, join codes, membership.
class TeamService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final TeamService _instance = TeamService._internal();
  factory TeamService() => _instance;
  TeamService._internal();

  // ---------------------------------------------------------------------------
  // Team CRUD
  // ---------------------------------------------------------------------------

  /// Create a team for the given owner. Sets `team_id` on the owner's profile.
  Future<Team> createTeam(String ownerId, String teamName) async {
    final joinCode = await _generateUniqueJoinCode();

    final docRef = await _firestore.collection('teams').add({
      'owner_id': ownerId,
      'team_name': teamName,
      'join_code': joinCode,
      'members': <String>[],
      'created_at': FieldValue.serverTimestamp(),
    });

    // Update owner's profile with team_id
    await _firestore.collection('user_profiles').doc(ownerId).set({
      'team_id': docRef.id,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return Team(
      id: docRef.id,
      ownerId: ownerId,
      teamName: teamName,
      joinCode: joinCode,
      members: [],
    );
  }

  /// Get a team by its document ID.
  Future<Team?> getTeam(String teamId) async {
    final doc = await _firestore.collection('teams').doc(teamId).get();
    if (!doc.exists) return null;
    return Team.fromFirestore(doc);
  }

  /// Get the team owned by [ownerId]. Returns null if no team exists.
  Future<Team?> getTeamByOwnerId(String ownerId) async {
    final query = await _firestore
        .collection('teams')
        .where('owner_id', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return Team.fromFirestore(query.docs.first);
  }

  /// Stream the team document for real-time updates.
  Stream<Team?> streamTeam(String teamId) {
    return _firestore.collection('teams').doc(teamId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Team.fromFirestore(doc);
    });
  }

  // ---------------------------------------------------------------------------
  // Join code
  // ---------------------------------------------------------------------------

  /// Generate a new join code for an existing team.
  Future<String> regenerateJoinCode(String teamId) async {
    final newCode = await _generateUniqueJoinCode();
    await _firestore.collection('teams').doc(teamId).update({
      'join_code': newCode,
    });
    return newCode;
  }

  /// Generate a unique 6-character alphanumeric code.
  Future<String> _generateUniqueJoinCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I ambiguity
    final rng = Random.secure();
    String code;
    int attempts = 0;
    do {
      code = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
      final existing = await _firestore
          .collection('teams')
          .where('join_code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
      attempts++;
    } while (attempts < 10);
    // Extremely unlikely to reach here given 34^6 ≈ 1.5 billion combos
    return code;
  }

  // ---------------------------------------------------------------------------
  // Membership
  // ---------------------------------------------------------------------------

  /// Join a team using a 6-char code. Returns the team on success, null if code not found.
  Future<Team?> joinTeam(String userId, String joinCode) async {
    final query = await _firestore
        .collection('teams')
        .where('join_code', isEqualTo: joinCode.toUpperCase().trim())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final teamDoc = query.docs.first;
    final teamId = teamDoc.id;
    final team = Team.fromFirestore(teamDoc);

    // Don't allow joining if already a member
    if (team.members.contains(userId)) return team;

    // Add to team members array
    await _firestore.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayUnion([userId]),
    });

    // Set team_id on the user's profile
    await _firestore.collection('user_profiles').doc(userId).set({
      'team_id': teamId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return Team(
      id: teamId,
      ownerId: team.ownerId,
      teamName: team.teamName,
      joinCode: team.joinCode,
      members: [...team.members, userId],
    );
  }

  /// Leave a team (called by the member themselves).
  Future<void> leaveTeam(String userId, String teamId) async {
    await _firestore.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
    await _firestore.collection('user_profiles').doc(userId).set({
      'team_id': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove a member from a team (called by the owner).
  Future<void> removeMember(String ownerId, String memberId, String teamId) async {
    // Verify caller is the owner
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return;
    final team = Team.fromFirestore(teamDoc);
    if (team.ownerId != ownerId) return; // Not the owner — refuse

    await _firestore.collection('teams').doc(teamId).update({
      'members': FieldValue.arrayRemove([memberId]),
    });
    await _firestore.collection('user_profiles').doc(memberId).set({
      'team_id': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Get all members of a team as AppUser list.
  Future<List<AppUser>> getTeamMembers(String teamId) async {
    final teamDoc = await _firestore.collection('teams').doc(teamId).get();
    if (!teamDoc.exists) return [];
    final team = Team.fromFirestore(teamDoc);
    if (team.members.isEmpty) return [];

    // Firestore 'whereIn' supports max 30 items. Batch if needed.
    final List<AppUser> results = [];
    final batches = _batch(team.members, 30);
    for (final batch in batches) {
      final query = await _firestore
          .collection('user_profiles')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in query.docs) {
        results.add(AppUser.fromFirestore(doc));
      }
    }
    return results;
  }

  /// Get the team ID a user belongs to (from their profile).
  Future<String?> getTeamIdForUser(String userId) async {
    final doc = await _firestore.collection('user_profiles').doc(userId).get();
    if (!doc.exists) return null;
    return doc.data()?['team_id'] as String?;
  }

  /// Get the user's role from their profile.
  Future<UserRole?> getUserRole(String userId) async {
    final doc = await _firestore.collection('user_profiles').doc(userId).get();
    if (!doc.exists) return null;
    return UserRole.fromString(doc.data()?['role'] as String?);
  }

  // Utility: batch a list into chunks of [size].
  List<List<T>> _batch<T>(List<T> items, int size) {
    final List<List<T>> batches = [];
    for (var i = 0; i < items.length; i += size) {
      batches.add(items.sublist(i, i + size > items.length ? items.length : i + size));
    }
    return batches;
  }
}
