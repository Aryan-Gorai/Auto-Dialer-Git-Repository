import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/enums/menu_action.dart';
import 'package:flutter_application_1/utilities/dialogs/logout_dialog.dart';

import '../dialer/dialer.dart';
import '../list/firebase_services.dart';
import 'heatmap/call_heatmap.dart';
import 'weekly_calls_chart.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({Key? key}) : super(key: key);

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> with SingleTickerProviderStateMixin {
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  late TabController _tabController;

  // Heatmap settings
  String _selectedTimeScale = 'month'; // 'month', 'week', 'day'
  int _maxCallThreshold = 10; // Default max threshold
  final TextEditingController _thresholdController = TextEditingController(text: '10');
  final FocusNode _thresholdFocusNode = FocusNode();
  bool _showHeatmap = true;
  int _timeOffset = 0; // 0 = current period, -1 = previous, 1 = next, etc.

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHeatmapSettings();
    _thresholdController.addListener(_updateThresholdAndSave);
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
            _selectedTimeScale = data['heatmap_time_scale'];
          }
          if (data.containsKey('heatmap_max_threshold')) {
            _maxCallThreshold = data['heatmap_max_threshold'];
            _thresholdController.text = _maxCallThreshold.toString();
          }
          if (data.containsKey('heatmap_visible')) {
            _showHeatmap = data['heatmap_visible'];
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
      await firestore.collection('user_settings').doc(userId).set({
        // Store the user id explicitly to avoid any cross-user overlap and allow collection-level queries
        'user_id': userId,
        'heatmap_time_scale': _selectedTimeScale,
        'heatmap_max_threshold': _maxCallThreshold,
        'heatmap_visible': _showHeatmap,
        'last_updated': Timestamp.now(),
      }, SetOptions(merge: true));
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

  void _updateThresholdAndSave() {
    final value = int.tryParse(_thresholdController.text);
    if (value != null && value > 0) {
      setState(() {
        _maxCallThreshold = value;
      });
      _saveHeatmapSettings();
    }
  }

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
        title: const Text('Reports View (% Completion)'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.grid_on),
              text: 'Heatmap',
            ),
            Tab(
              icon: Icon(Icons.show_chart),
              text: 'Weekly Trends',
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
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Time scale selector
                          Row(
                            children: [
                              Text(
                                'Time Scale:',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const SizedBox(width: 16),
                              DropdownButton<String>(
                                value: _selectedTimeScale,
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedTimeScale = newValue;
                                    });
                                    _saveHeatmapSettings();
                                  }
                                },
                                items: <String>['month', 'week', 'day']
                                    .map<DropdownMenuItem<String>>((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value[0].toUpperCase() + value.substring(1)),
                                  );
                                }).toList(),
                              ),
                            ],
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
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(8.0),
          child: const WeeklyCallsChart(),
        ),
      ),
    );
  }

  Widget buildCurvedNavigationBar() {
    return CurvedNavigationBar(
      key: _bottomNavigationKey,
      index: 0,
      height: 60.0,
      items: const <Widget>[
        Icon(Icons.add, size: 30),
        Icon(Icons.list, size: 30),
        Icon(Icons.compare_arrows, size: 30),
        Icon(Icons.call_split, size: 30),
        Icon(Icons.perm_identity, size: 30),
      ],
      color: Colors.white,
      buttonBackgroundColor: Colors.white,
      backgroundColor: const Color.fromRGBO(248, 225, 209, 1),
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 600),
      onTap: (index) {
        navigateToPage(index);
      },
      letIndexChange: (index) => true,
    );
  }

  Widget pageNavigator(int index) {
    if (index == 2) {
      return DialerContactsView(listName: selectedList);
    } else {
      return Container();
    }
  }

  void navigateToPage(int index) {
    switch (index) {
      case 0:
        break;
      case 1:
        break;
    }
  }
}
