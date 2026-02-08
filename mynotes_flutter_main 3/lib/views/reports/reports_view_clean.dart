// Main reports dashboard. Uses a TabController to switch between six report
// tabs: Call Heatmap, Weekly Calls, Call Duration, List Performance,
// Call Outcomes (donut chart), and ML Stats (linear regression + Wilson + KM).
// Pulls all data from the logged-in user's Firestore call_history.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/enums/menu_action.dart';
import 'package:flutter_application_1/utilities/dialogs/logout_dialog.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';
import 'package:intl/intl.dart';

import 'heatmap/call_heatmap.dart';
import 'weekly_calls_chart.dart';
import 'call_duration_chart.dart';
import 'list_performance_chart.dart';
import 'call_outcome_donut_chart.dart';
import 'linear_regression_stats_view.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({Key? key}) : super(key: key);

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Heatmap settings
  String _selectedTimeScale = 'last7days'; // 'last7days', 'currentWeek', 'last30days', 'custom'
  int _maxCallThreshold = 10; // Default max threshold
  final TextEditingController _thresholdController = TextEditingController(text: '10');
  final FocusNode _thresholdFocusNode = FocusNode();
  bool _showHeatmap = true;
  int _timeOffset = 0; // 0 = current period, -1 = previous, 1 = next, etc.
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  
  // Contact filter for heatmap
  String? _selectedContactFilter; // normalized_phone of selected contact, null = All Contacts
  List<Map<String, dynamic>> _availableContacts = [];
  bool _isLoadingContacts = false;

  // List filter for heatmap
  String? _selectedListFilter; // list_name to filter by specific list, null = All Lists
  List<String> _availableLists = [];
  bool _isLoadingLists = false;

  // Common time range settings for all tabs
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
    _loadHeatmapSettings();
    _loadContactsForFilter();
    _loadListsForFilter();
    _thresholdController.addListener(_updateThresholdAndSave);
  }

  // Fetch contacts from Contact Directories for filter dropdown
  Future<void> _loadContactsForFilter() async {
    setState(() {
      _isLoadingContacts = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      print('Loading contacts for filter, userId: $userId');
      
      QuerySnapshot snapshot = await firestore
          .collection('Contact Directories')
          .where('user_id', isEqualTo: userId)
          .get();

      print('Found ${snapshot.docs.length} contacts in Contact Directories');

      List<Map<String, dynamic>> contacts = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final contactData = {
          'contact_name': data['contact_name'] ?? '',
          'normalized_phone': data['normalized_phone'] ?? '',
          'contact_phone_number': data['contact_phone_number'] ?? '',
        };
        contacts.add(contactData);
        print('Added contact: ${contactData['contact_name']} - ${contactData['contact_phone_number']}');
      }

      // Sort contacts alphabetically by name in memory
      contacts.sort((a, b) {
        String nameA = (a['contact_name'] as String).toLowerCase();
        String nameB = (b['contact_name'] as String).toLowerCase();
        if (nameA.isEmpty) nameA = a['contact_phone_number'] as String;
        if (nameB.isEmpty) nameB = b['contact_phone_number'] as String;
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _availableContacts = contacts;
          _isLoadingContacts = false;
        });
        print('Contacts loaded successfully: ${contacts.length} contacts');
      }
    } catch (e) {
      print('❌ Error loading contacts for filter: $e');
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  // Fetch lists from lists_collection for filter dropdown
  Future<void> _loadListsForFilter() async {
    setState(() {
      _isLoadingLists = true;
    });

    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      print('Loading lists for filter, userId: $userId');
      
      QuerySnapshot snapshot = await firestore
          .collection('lists_collection')
          .where('user_id', isEqualTo: userId)
          .get();

      print('Found ${snapshot.docs.length} lists in lists_collection');

      List<String> lists = [];
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final listName = data['list_name'] as String?;
        if (listName != null && listName.isNotEmpty) {
          lists.add(listName);
          print('Added list: $listName');
        }
      }

      // Sort lists alphabetically
      lists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          _availableLists = lists;
          _isLoadingLists = false;
        });
        print('Lists loaded successfully: ${lists.length} lists');
      }
    } catch (e) {
      print('❌ Error loading lists for filter: $e');
      if (mounted) {
        setState(() {
          _isLoadingLists = false;
        });
      }
    }
  }

  // Load heatmap settings from Firebase
  Future<void> _loadHeatmapSettings() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentSnapshot snapshot = await firestore.collection('user_settings').doc(userId).get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          if (data.containsKey('heatmap_time_scale')) {
            String savedTimeScale = data['heatmap_time_scale'];
            // Handle migration from old values to new values
            switch (savedTimeScale) {
              case 'day':
                _selectedTimeScale = 'last7days';
                break;
              case 'week':
                _selectedTimeScale = 'currentWeek';
                break;
              case 'month':
                _selectedTimeScale = 'last30days';
                break;
              case 'last7days':
              case 'currentWeek':
              case 'last30days':
              case 'custom':
                _selectedTimeScale = savedTimeScale;
                break;
              default:
                _selectedTimeScale = 'last7days'; // fallback default
            }
          }
          if (data.containsKey('heatmap_max_threshold')) {
            _maxCallThreshold = data['heatmap_max_threshold'];
            _thresholdController.text = _maxCallThreshold.toString();
          }
          if (data.containsKey('heatmap_visible')) {
            _showHeatmap = data['heatmap_visible'];
          }
          if (data.containsKey('custom_start_date')) {
            _customStartDate = (data['custom_start_date'] as Timestamp).toDate();
          }
          if (data.containsKey('custom_end_date')) {
            _customEndDate = (data['custom_end_date'] as Timestamp).toDate();
          }
          if (data.containsKey('heatmap_contact_filter')) {
            _selectedContactFilter = data['heatmap_contact_filter'] as String?;
          }
          if (data.containsKey('heatmap_list_filter')) {
            _selectedListFilter = data['heatmap_list_filter'] as String?;
          }
        });
      }
    } catch (e) {
      // noop
    }
  }

  // Save heatmap settings to Firebase
  Future<void> _saveHeatmapSettings() async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      Map<String, dynamic> dataToSave = {
        // Store the user id explicitly to avoid any cross-user overlap and allow collection-level queries
        'user_id': userId,
        'heatmap_time_scale': _selectedTimeScale,
        'heatmap_max_threshold': _maxCallThreshold,
        'heatmap_visible': _showHeatmap,
        'last_updated': Timestamp.now(),
      };

      if (_customStartDate != null) {
        dataToSave['custom_start_date'] = Timestamp.fromDate(_customStartDate!);
      }
      if (_customEndDate != null) {
        dataToSave['custom_end_date'] = Timestamp.fromDate(_customEndDate!);
      }
      if (_selectedContactFilter != null) {
        dataToSave['heatmap_contact_filter'] = _selectedContactFilter;
      } else {
        dataToSave['heatmap_contact_filter'] = null;
      }
      if (_selectedListFilter != null) {
        dataToSave['heatmap_list_filter'] = _selectedListFilter;
      } else {
        dataToSave['heatmap_list_filter'] = null;
      }

      await firestore.collection('user_settings').doc(userId).set(dataToSave, SetOptions(merge: true));
    } catch (e) {
      // noop
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _thresholdController.dispose();
    _thresholdFocusNode.dispose();
    super.dispose();
  }

  String get userId => AuthService.firebase().currentUser!.id;

  // Opens the native date-range picker for the heatmap tab.
  // When the user confirms, we switch the time scale to 'custom' and persist.
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
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
      _saveHeatmapSettings();
    }
  }

  // Same date-range picker but for the weekly trends chart tab.
  Future<void> _selectWeeklyTrendsDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _weeklyTrendsStartDate != null && _weeklyTrendsEndDate != null
          ? DateTimeRange(start: _weeklyTrendsStartDate!, end: _weeklyTrendsEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _weeklyTrendsStartDate = picked.start;
        _weeklyTrendsEndDate = picked.end;
        _weeklyTrendsTimeRange = 'custom';
      });
    }
  }

  // Date-range picker for the call duration chart tab.
  Future<void> _selectCallDurationDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _callDurationStartDate != null && _callDurationEndDate != null
          ? DateTimeRange(start: _callDurationStartDate!, end: _callDurationEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _callDurationStartDate = picked.start;
        _callDurationEndDate = picked.end;
        _callDurationTimeRange = 'custom';
      });
    }
  }

  // Date-range picker for the outcomes donut chart tab.
  Future<void> _selectOutcomesDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _outcomesStartDate != null && _outcomesEndDate != null
          ? DateTimeRange(start: _outcomesStartDate!, end: _outcomesEndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _outcomesStartDate = picked.start;
        _outcomesEndDate = picked.end;
        _outcomesTimeRange = 'custom';
      });
    }
  }

  // Reads the threshold text field and persists the new max-call value
  // so the heatmap colour scale adjusts accordingly.
  void _updateThresholdAndSave() {
    final value = int.tryParse(_thresholdController.text);
    if (value != null && value > 0) {
      setState(() {
        _maxCallThreshold = value;
      });
      _saveHeatmapSettings();
    }
  }

  // Toggles whether the heatmap widget is visible and saves the pref.
  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
    _saveHeatmapSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(248, 225, 209, 1),
      appBar: AppBar(
        title: Text(
          'Reports View',
          style: AppleTypography.withAppleFont(
            AppleTypography.headline5.copyWith(
              fontWeight: FontWeight.normal,
            )
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.grid_on),
              text: 'Heatmap',
            ),
            Tab(
              icon: Icon(Icons.show_chart),
              text: 'Weekly Trends',
            ),
            Tab(
              icon: Icon(Icons.bar_chart),
              text: 'Call Duration',
            ),
            Tab(
              icon: Icon(Icons.bar_chart_outlined),
              text: 'List Performance',
            ),
            Tab(
              icon: Icon(Icons.pie_chart),
              text: 'Outcomes',
            ),
            Tab(
              icon: Icon(Icons.functions),
              text: 'Stats',
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            onSelected: (value) async {
              switch (value) {
                case MenuAction.logout:
                  final shouldLogout = await showLogOutDialog(context);
                  if (shouldLogout) {
                    await FirebaseAuth.instance.signOut();
                    // ignore: use_build_context_synchronously
                    Navigator.of(context).pushNamedAndRemoveUntil('/login/', (_) => false);
                  }
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<MenuAction>(
                  value: MenuAction.logout,
                  child: Text('Log out'),
                ),
              ];
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Heatmap
          _buildHeatmapTab(),
          // Tab 2: Weekly Trends
          _buildWeeklyTrendsTab(),
          // Tab 3: Call Duration
          _buildCallDurationTab(),
          // Tab 4: List Performance
          _buildListPerformanceTab(),
          // Tab 5: Call Outcomes
          _buildCallOutcomesTab(),
          // Tab 6: Stats (Linear Regression)
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildHeatmapTab() {
    return Center(
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Heatmap Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Call Frequency Heatmap',
                            style: AppleTypography.withAppleFont(
                              AppleTypography.headline5.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              )
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Contact filter dropdown
                          Row(
                            children: [
                              Text(
                                'Filter by Contact:',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.body1.copyWith(
                                    color: Colors.grey[700],
                                  )
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _isLoadingContacts
                                  ? const SizedBox(
                                      height: 30,
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : _availableContacts.isEmpty
                                    ? Row(
                                        children: [
                                          const Text('No contacts found'),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: _loadContactsForFilter,
                                            child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      )
                                    : DropdownButton<String?>(
                                        isExpanded: true,
                                        value: _availableContacts.any((c) => c['normalized_phone'] == _selectedContactFilter) 
                                            ? _selectedContactFilter 
                                            : null,
                                        hint: Text('All Contacts (${_availableContacts.length} available)'),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedContactFilter = newValue;
                                          });
                                          _saveHeatmapSettings();
                                        },
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('All Contacts'),
                                          ),
                                          ..._availableContacts.map((contact) {
                                            final name = contact['contact_name'] as String? ?? '';
                                            final phone = contact['contact_phone_number'] as String? ?? '';
                                            final displayText = name.isNotEmpty ? name : phone;
                                            
                                            return DropdownMenuItem<String?>(
                                              value: contact['normalized_phone'] as String?,
                                              child: Text(
                                                displayText,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // List filter dropdown
                          Row(
                            children: [
                              Text(
                                'Filter by List:',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.body1.copyWith(
                                    color: Colors.grey[700],
                                  )
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _isLoadingLists
                                  ? const SizedBox(
                                      height: 30,
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      ),
                                    )
                                  : _availableLists.isEmpty
                                    ? Row(
                                        children: [
                                          const Text('No lists found'),
                                          const SizedBox(width: 8),
                                          TextButton(
                                            onPressed: _loadListsForFilter,
                                            child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                          ),
                                        ],
                                      )
                                    : DropdownButton<String?>(
                                        isExpanded: true,
                                        value: _availableLists.contains(_selectedListFilter)
                                            ? _selectedListFilter
                                            : null,
                                        hint: Text('All Lists (${_availableLists.length} available)'),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedListFilter = newValue;
                                          });
                                          _saveHeatmapSettings();
                                        },
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('All Lists'),
                                          ),
                                          ..._availableLists.map((listName) {
                                            return DropdownMenuItem<String?>(
                                              value: listName,
                                              child: Text(
                                                listName,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Time scale selector
                          Row(
                            children: [
                              Text(
                                'Time Scale:',
                                style: AppleTypography.withAppleFont(
                                  AppleTypography.body1.copyWith(
                                    color: Colors.grey[700],
                                  )
                                ),
                              ),
                              const SizedBox(width: 16),
                              DropdownButton<String>(
                                value: _selectedTimeScale,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    if (newValue == 'custom') {
                                      _selectDateRange();
                                    } else {
                                      setState(() {
                                        _selectedTimeScale = newValue;
                                      });
                                      _saveHeatmapSettings();
                                    }
                                  }
                                },
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: 'last7days',
                                    child: Text('Last 7 Days'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'currentWeek',
                                    child: Text('Current Week'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'last30days',
                                    child: Text('Last 30 Days'),
                                  ),
                                  const DropdownMenuItem<String>(
                                    value: 'custom',
                                    child: Text('Select Custom'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_selectedTimeScale == 'custom' && _customStartDate != null && _customEndDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Selected: ${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          // Max threshold input
                          Row(
                            children: [
                              Text(
                                'Max Call Threshold:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  controller: _thresholdController,
                                  focusNode: _thresholdFocusNode,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  onSubmitted: (value) {
                                    _thresholdFocusNode.unfocus();
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Toggle and refresh buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _showHeatmap = false;
                                  });
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    setState(() {
                                      _showHeatmap = true;
                                    });
                                  });
                                },
                                child: const Text(
                                  'Refresh Data',
                                  style: TextStyle(color: Colors.green),
                                ),
                              ),
                              TextButton(
                                onPressed: _toggleHeatmap,
                                child: Text(
                                  _showHeatmap ? 'Hide Heatmap' : 'Show Heatmap',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_showHeatmap)
                      Column(
                        children: [
                          // Navigation buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios),
                                onPressed: () {
                                  setState(() {
                                    _timeOffset--;
                                  });
                                },
                                tooltip: 'Previous ${_selectedTimeScale}',
                              ),
                              const SizedBox(width: 20),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _timeOffset = 0;
                                  });
                                },
                                child: const Text('Current'),
                              ),
                              const SizedBox(width: 20),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios),
                                onPressed: () {
                                  setState(() {
                                    _timeOffset++;
                                  });
                                },
                                tooltip: 'Next ${_selectedTimeScale}',
                              ),
                            ],
                          ),
                          // Heatmap
                          SizedBox(
                            height: 350,
                            child: CallHeatmap(
                              timeScale: _selectedTimeScale,
                              maxCallThreshold: _maxCallThreshold,
                              timeOffset: _timeOffset,
                              contactFilter: _selectedContactFilter,
                              listFilter: _selectedListFilter,
                              customStartDate: _customStartDate,
                              customEndDate: _customEndDate,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyTrendsTab() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List filter dropdown
                        Row(
                          children: [
                            Text(
                              'Filter by List:',
                              style: AppleTypography.withAppleFont(
                                AppleTypography.body1.copyWith(
                                  color: Colors.grey[700],
                                )
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _isLoadingLists
                                ? const SizedBox(
                                    height: 30,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : _availableLists.isEmpty
                                  ? Row(
                                      children: [
                                        const Text('No lists found'),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _loadListsForFilter,
                                          child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    )
                                  : DropdownButton<String?>(
                                      isExpanded: true,
                                      value: _availableLists.contains(_selectedListFilter)
                                          ? _selectedListFilter
                                          : null,
                                      hint: Text('All Lists (${_availableLists.length} available)'),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedListFilter = newValue;
                                        });
                                      },
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('All Lists'),
                                        ),
                                        ..._availableLists.map((listName) {
                                          return DropdownMenuItem<String?>(
                                            value: listName,
                                            child: Text(
                                              listName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Time range dropdown
                        _buildTimeRangeDropdown(
                          _weeklyTrendsTimeRange,
                          (String newValue) {
                            setState(() {
                              _weeklyTrendsTimeRange = newValue;
                            });
                          },
                          _selectWeeklyTrendsDateRange,
                          _weeklyTrendsStartDate,
                          _weeklyTrendsEndDate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: WeeklyCallsChart(
                selectedTimeRange: _weeklyTrendsTimeRange,
                customStartDate: _weeklyTrendsStartDate,
                customEndDate: _weeklyTrendsEndDate,
                              listFilter: _selectedListFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallDurationTab() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // List filter dropdown
                        Row(
                          children: [
                            Text(
                              'Filter by List:',
                              style: AppleTypography.withAppleFont(
                                AppleTypography.body1.copyWith(
                                  color: Colors.grey[700],
                                )
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _isLoadingLists
                                ? const SizedBox(
                                    height: 30,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  )
                                : _availableLists.isEmpty
                                  ? Row(
                                      children: [
                                        const Text('No lists found'),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: _loadListsForFilter,
                                          child: const Text('Retry', style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    )
                                  : DropdownButton<String?>(
                                      isExpanded: true,
                                      value: _availableLists.contains(_selectedListFilter)
                                          ? _selectedListFilter
                                          : null,
                                      hint: Text('All Lists (${_availableLists.length} available)'),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedListFilter = newValue;
                                        });
                                      },
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('All Lists'),
                                        ),
                                        ..._availableLists.map((listName) {
                                          return DropdownMenuItem<String?>(
                                            value: listName,
                                            child: Text(
                                              listName,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Time range dropdown
                        _buildTimeRangeDropdown(
                          _callDurationTimeRange,
                          (String newValue) {
                            setState(() {
                              _callDurationTimeRange = newValue;
                            });
                          },
                          _selectCallDurationDateRange,
                          _callDurationStartDate,
                          _callDurationEndDate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: CallDurationChart(
                selectedTimeRange: _callDurationTimeRange,
                customStartDate: _callDurationStartDate,
                customEndDate: _callDurationEndDate,
                listFilter: _selectedListFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListPerformanceTab() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(8.0),
          child: ListPerformanceChart(selectedList: _selectedListFilter),
        ),
      ),
    );
  }

  Widget _buildCallOutcomesTab() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildTimeRangeDropdown(
                  _outcomesTimeRange,
                  (String newValue) {
                    setState(() {
                      _outcomesTimeRange = newValue;
                    });
                  },
                  _selectOutcomesDateRange,
                  _outcomesStartDate,
                  _outcomesEndDate,
                ),
              ),
            ),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.all(8.0),
              child: CallOutcomeDonutChart(
                selectedTimeRange: _outcomesTimeRange,
                customStartDate: _outcomesStartDate,
                customEndDate: _outcomesEndDate,
              ),
            ),
          ],
        ),
      ),
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
            Text(
              'Time Range:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: currentValue,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  if (newValue == 'custom') {
                    onCustomSelected();
                  } else {
                    onChanged(newValue);
                  }
                }
              },
              items: const [
                DropdownMenuItem<String>(
                  value: 'last7days',
                  child: Text('Last 7 Days'),
                ),
                DropdownMenuItem<String>(
                  value: 'currentWeek',
                  child: Text('Current Week'),
                ),
                DropdownMenuItem<String>(
                  value: 'last30days',
                  child: Text('Last 30 Days'),
                ),
                DropdownMenuItem<String>(
                  value: 'custom',
                  child: Text('Select Custom'),
                ),
              ],
            ),
          ],
        ),
        if (currentValue == 'custom' && customStartDate != null && customEndDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Selected: ${DateFormat('MMM d').format(customStartDate)} - ${DateFormat('MMM d, yyyy').format(customEndDate)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsTab() {
    return const LinearRegressionStatsView();
  }
}
