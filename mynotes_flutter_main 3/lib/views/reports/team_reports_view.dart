import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/app_user.dart';
import 'package:flutter_application_1/models/team.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/services/team_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:intl/intl.dart';

import 'heatmap/call_heatmap.dart';
import 'weekly_calls_chart.dart';
import 'call_duration_chart.dart';
import 'list_performance_chart.dart';
import 'call_outcome_donut_chart.dart';
import 'linear_regression_stats_view.dart';

/// Reports view for Team Owners.
/// Shows a member dropdown at the top to select whose data to display.
/// All chart tabs render data for the selected member via targetUserId.
class TeamReportsView extends StatefulWidget {
  const TeamReportsView({Key? key}) : super(key: key);

  @override
  State<TeamReportsView> createState() => _TeamReportsViewState();
}

class _TeamReportsViewState extends State<TeamReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeamService _teamService = TeamService();

  String get _ownerId => AuthService.firebase().currentUser!.id;

  // Team & members
  Team? _team;
  List<AppUser> _members = [];
  bool _loadingTeam = true;

  // Selected member
  String? _selectedMemberId;
  String? _selectedMemberName;

  // Heatmap settings (owner-level, per-session only)
  String _selectedTimeScale = 'last7days';
  int _maxCallThreshold = 10;
  final TextEditingController _thresholdController = TextEditingController(text: '10');
  bool _showHeatmap = true;
  int _timeOffset = 0;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

  // List filter
  String? _selectedListFilter;
  List<String> _availableLists = [];

  // Time range per tab
  String _weeklyTrendsTimeRange = 'last7days';
  String _callDurationTimeRange = 'last7days';
  String _outcomesTimeRange = 'last7days';
  DateTime? _weeklyTrendsStartDate;
  DateTime? _weeklyTrendsEndDate;
  DateTime? _callDurationStartDate;
  DateTime? _callDurationEndDate;
  DateTime? _outcomesStartDate;
  DateTime? _outcomesEndDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadTeamAndMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamAndMembers() async {
    try {
      final team = await _teamService.getTeamByOwnerId(_ownerId);
      if (team != null) {
        final members = await _teamService.getTeamMembers(team.id);
        if (mounted) {
          setState(() {
            _team = team;
            _members = members;
            _loadingTeam = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingTeam = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loadingTeam = false);
    }
  }

  void _onMemberSelected(String? memberId) {
    if (memberId == null) return;
    final member = _members.firstWhere((m) => m.id == memberId);
    setState(() {
      _selectedMemberId = memberId;
      _selectedMemberName = member.name.isNotEmpty ? member.name : member.email;
      // Reset filters when switching members
      _selectedListFilter = null;
      _availableLists = [];
    });
    _loadMemberLists(memberId);
  }

  Future<void> _loadMemberLists(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('lists_collection')
          .where('user_id', isEqualTo: userId)
          .get();
      final lists = snapshot.docs
          .map((d) => (d.data()['list_name'] ?? '').toString())
          .where((name) => name.isNotEmpty)
          .toList()
        ..sort();
      if (mounted) {
        setState(() => _availableLists = lists);
      }
    } catch (_) {}
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customStartDate != null && _customEndDate != null
          ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _customStartDate = picked.start;
        _customEndDate = picked.end;
        _selectedTimeScale = 'custom';
      });
    }
  }

  Future<void> _selectWeeklyTrendsDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _weeklyTrendsStartDate = picked.start;
        _weeklyTrendsEndDate = picked.end;
        _weeklyTrendsTimeRange = 'custom';
      });
    }
  }

  Future<void> _selectCallDurationDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _callDurationStartDate = picked.start;
        _callDurationEndDate = picked.end;
        _callDurationTimeRange = 'custom';
      });
    }
  }

  Future<void> _selectOutcomesDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _outcomesStartDate = picked.start;
        _outcomesEndDate = picked.end;
        _outcomesTimeRange = 'custom';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(248, 225, 209, 1),
      appBar: AppBar(
        title: Text(
          'Team Reports',
          style: AppleTypography.withAppleFont(
            AppleTypography.headline5.copyWith(fontWeight: FontWeight.normal),
          ),
        ),
        bottom: _selectedMemberId != null
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: 'Heatmap'),
                  Tab(icon: Icon(Icons.show_chart), text: 'Weekly Trends'),
                  Tab(icon: Icon(Icons.bar_chart), text: 'Call Duration'),
                  Tab(icon: Icon(Icons.bar_chart_outlined), text: 'List Performance'),
                  Tab(icon: Icon(Icons.pie_chart), text: 'Outcomes'),
                  Tab(icon: Icon(Icons.functions), text: 'Stats'),
                ],
              )
            : null,
        actions: [
          PopupMenuButton(
            onSelected: (value) async {
              if (value == 'logout') {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login/', (_) => false);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
        ],
      ),
      body: _loadingTeam
          ? const Center(child: CircularProgressIndicator())
          : _team == null
              ? _buildNoTeamView()
              : _buildBody(),
    );
  }

  Widget _buildNoTeamView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No team created yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to the Team tab to create your team first.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Member selector
        _buildMemberSelector(),
        // Content
        if (_selectedMemberId == null)
          Expanded(child: _buildSelectMemberPrompt())
        else
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHeatmapTab(),
                _buildWeeklyTrendsTab(),
                _buildCallDurationTab(),
                _buildListPerformanceTab(),
                _buildCallOutcomesTab(),
                _buildStatsTab(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMemberSelector() {
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.blue),
            const SizedBox(width: 12),
            Text(
              'Viewing:',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                value: _selectedMemberId,
                isExpanded: true,
                hint: const Text('Select a team member'),
                underline: const SizedBox(),
                onChanged: _onMemberSelected,
                items: _members.map((m) {
                  return DropdownMenuItem<String>(
                    value: m.id,
                    child: Text(
                      m.name.isNotEmpty ? m.name : m.email,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectMemberPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Select a team member to view their reports',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          if (_members.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No members in your team yet.\nShare your join code to invite members.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab builders – identical to ReportsView but passing targetUserId
  // ---------------------------------------------------------------------------

  Widget _buildHeatmapTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedMemberName ?? "Member"}\'s Heatmap',
                    style: AppleTypography.withAppleFont(
                      AppleTypography.headline5.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Time scale dropdown
                  _buildTimeScaleDropdown(),
                  const SizedBox(height: 12),
                  // List filter
                  if (_availableLists.isNotEmpty) ...[
                    _buildListFilterDropdown(),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 350,
                    child: CallHeatmap(
                      timeScale: _selectedTimeScale,
                      maxCallThreshold: _maxCallThreshold,
                      timeOffset: _timeOffset,
                      listFilter: _selectedListFilter,
                      customStartDate: _customStartDate,
                      customEndDate: _customEndDate,
                      targetUserId: _selectedMemberId,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrendsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTimeRangeDropdown(
                _weeklyTrendsTimeRange,
                (v) => setState(() => _weeklyTrendsTimeRange = v),
                _selectWeeklyTrendsDateRange,
                _weeklyTrendsStartDate,
                _weeklyTrendsEndDate,
              ),
            ),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: WeeklyCallsChart(
              selectedTimeRange: _weeklyTrendsTimeRange,
              customStartDate: _weeklyTrendsStartDate,
              customEndDate: _weeklyTrendsEndDate,
              listFilter: _selectedListFilter,
              targetUserId: _selectedMemberId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallDurationTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTimeRangeDropdown(
                _callDurationTimeRange,
                (v) => setState(() => _callDurationTimeRange = v),
                _selectCallDurationDateRange,
                _callDurationStartDate,
                _callDurationEndDate,
              ),
            ),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: CallDurationChart(
              selectedTimeRange: _callDurationTimeRange,
              customStartDate: _callDurationStartDate,
              customEndDate: _callDurationEndDate,
              listFilter: _selectedListFilter,
              targetUserId: _selectedMemberId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListPerformanceTab() {
    return SingleChildScrollView(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(8),
        child: ListPerformanceChart(
          selectedList: _selectedListFilter,
          targetUserId: _selectedMemberId,
        ),
      ),
    );
  }

  Widget _buildCallOutcomesTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildTimeRangeDropdown(
                _outcomesTimeRange,
                (v) => setState(() => _outcomesTimeRange = v),
                _selectOutcomesDateRange,
                _outcomesStartDate,
                _outcomesEndDate,
              ),
            ),
          ),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(8),
            child: CallOutcomeDonutChart(
              selectedTimeRange: _outcomesTimeRange,
              customStartDate: _outcomesStartDate,
              customEndDate: _outcomesEndDate,
              targetUserId: _selectedMemberId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return LinearRegressionStatsView(
      targetUserId: _selectedMemberId,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  Widget _buildTimeScaleDropdown() {
    return Row(
      children: [
        Text('Time Scale:', style: TextStyle(color: Colors.grey[700])),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _selectedTimeScale,
          onChanged: (v) {
            if (v == 'custom') {
              _selectDateRange();
            } else if (v != null) {
              setState(() {
                _selectedTimeScale = v;
                _timeOffset = 0;
              });
            }
          },
          items: const [
            DropdownMenuItem(value: 'last7days', child: Text('Last 7 Days')),
            DropdownMenuItem(value: 'currentWeek', child: Text('Current Week')),
            DropdownMenuItem(value: 'last30days', child: Text('Last 30 Days')),
            DropdownMenuItem(value: 'custom', child: Text('Custom')),
          ],
        ),
      ],
    );
  }

  Widget _buildListFilterDropdown() {
    return Row(
      children: [
        Text('List:', style: TextStyle(color: Colors.grey[700])),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<String>(
            value: _selectedListFilter,
            isExpanded: true,
            hint: const Text('All Lists'),
            onChanged: (v) => setState(() => _selectedListFilter = v),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('All Lists')),
              ..._availableLists.map((l) => DropdownMenuItem(value: l, child: Text(l))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeDropdown(
    String currentValue,
    Function(String) onChanged,
    VoidCallback onCustomSelected,
    DateTime? customStartDate,
    DateTime? customEndDate,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Time Range:', style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: currentValue,
              onChanged: (v) {
                if (v == 'custom') {
                  onCustomSelected();
                } else if (v != null) {
                  onChanged(v);
                }
              },
              items: const [
                DropdownMenuItem(value: 'last7days', child: Text('Last 7 Days')),
                DropdownMenuItem(value: 'currentWeek', child: Text('Current Week')),
                DropdownMenuItem(value: 'last30days', child: Text('Last 30 Days')),
                DropdownMenuItem(value: 'custom', child: Text('Select Custom')),
              ],
            ),
          ],
        ),
        if (currentValue == 'custom' && customStartDate != null && customEndDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selected: ${DateFormat('MMM d').format(customStartDate)} - ${DateFormat('MMM d, yyyy').format(customEndDate)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
