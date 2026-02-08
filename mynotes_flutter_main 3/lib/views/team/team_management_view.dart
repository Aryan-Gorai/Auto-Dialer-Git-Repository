// Team management page for team owners. Allows creating a team, viewing
// the join code, listing members, and removing members.
// Team members use this page to join/leave a team via a join code.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/models/app_user.dart';
import 'package:flutter_application_1/models/team.dart';
import 'package:flutter_application_1/services/team_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';

/// Team management page for Team Owners.
/// Shows: create team, join code, member list with remove action.
class TeamManagementView extends StatefulWidget {
  const TeamManagementView({Key? key}) : super(key: key);

  @override
  State<TeamManagementView> createState() => _TeamManagementViewState();
}

class _TeamManagementViewState extends State<TeamManagementView> {
  final TeamService _teamService = TeamService();
  late final String _userId;
  
  bool _loading = true;
  Team? _team;
  List<AppUser> _members = [];
  final _teamNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userId = fb_auth.FirebaseAuth.instance.currentUser?.uid ?? '';
    _loadTeam();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  // Fetches the team owned by this user plus its member list from Firestore.
  Future<void> _loadTeam() async {
    if (_userId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final team = await _teamService.getTeamByOwnerId(_userId);
      if (team != null) {
        final members = await _teamService.getTeamMembers(team.id);
        if (mounted) {
          setState(() {
            _team = team;
            _members = members;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTeam() async {
    final name = _teamNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final team = await _teamService.createTeam(_userId, name);
      if (mounted) {
        setState(() {
          _team = team;
          _members = [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create team: $e')),
        );
      }
    }
  }

  // Generates a fresh 6-character join code and updates the team doc.
  Future<void> _regenerateCode() async {
    if (_team == null) return;
    try {
      final newCode = await _teamService.regenerateJoinCode(_team!.id);
      if (mounted) {
        setState(() {
          _team = Team(
            id: _team!.id,
            ownerId: _team!.ownerId,
            teamName: _team!.teamName,
            joinCode: newCode,
            members: _team!.members,
            createdAt: _team!.createdAt,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Join code regenerated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to regenerate code: $e')),
        );
      }
    }
  }

  // Shows a confirmation dialog, then removes the member from the team.
  void _confirmRemoveMember(AppUser member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove "${member.name.isNotEmpty ? member.name : member.email}" from the team?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _loading = true);
              await _teamService.removeMember(_userId, member.id, _team!.id);
              await _loadTeam();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Member removed')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 10,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Team Management',
                style: AppleTypography.withAppleFont(
                  AppleTypography.headline3.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_team == null)
            _buildCreateTeamView()
          else
            Expanded(child: _buildTeamDashboard()),
        ],
      ),
    );
  }

  Widget _buildCreateTeamView() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Create Your Team',
              style: AppleTypography.withAppleFont(
                AppleTypography.headline4.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a team and invite members using a unique join code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _teamNameController,
              decoration: InputDecoration(
                labelText: 'Team Name',
                hintText: 'e.g. Sales Team Alpha',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _createTeam,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Create Team',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team info card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, color: Theme.of(context).colorScheme.primary, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _team!.teamName,
                          style: AppleTypography.withAppleFont(
                            AppleTypography.headline5.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Join code section
                  Text(
                    'Join Code',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _team!.joinCode,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _team!.joinCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied to clipboard')),
                            );
                          },
                          icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _regenerateCode,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Generate New Code'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Members section
          Text(
            'Members (${_members.length})',
            style: AppleTypography.withAppleFont(
              AppleTypography.headline6.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_add, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No members yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share the join code above to invite team members.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ...List.generate(_members.length, (i) {
              final member = _members[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    backgroundImage: member.photoUrl.isNotEmpty
                        ? NetworkImage(member.photoUrl)
                        : null,
                    child: member.photoUrl.isEmpty
                        ? Text(
                            (member.name.isNotEmpty ? member.name[0] : member.email[0]).toUpperCase(),
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                          )
                        : null,
                  ),
                  title: Text(
                    member.name.isNotEmpty ? member.name : 'Unnamed',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    member.email,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  trailing: IconButton(
                    onPressed: () => _confirmRemoveMember(member),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    tooltip: 'Remove member',
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
