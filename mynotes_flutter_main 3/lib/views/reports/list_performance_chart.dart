import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/services/auth/auth_service.dart';
import 'package:flutter_application_1/utilities/apple_typography.dart';

class ListPerformanceChart extends StatefulWidget {
  const ListPerformanceChart({Key? key}) : super(key: key);

  @override
  State<ListPerformanceChart> createState() => _ListPerformanceChartState();
}

class _ListPerformanceChartState extends State<ListPerformanceChart> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _sortBy = 'successRate'; // 'successRate', 'totalCalls', 'alphabetical'
  
  List<ListPerformanceData> _listData = [];

  String get _userId => AuthService.firebase().currentUser!.id;

  @override
  void initState() {
    super.initState();
    _fetchListPerformance();
  }

  Future<void> _fetchListPerformance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Fetching list performance for user: $_userId');

      // Fetch all Contact Directories for this user
      final QuerySnapshot directoriesSnapshot = await _firestore
          .collection('Contact Directories')
          .where('user_id', isEqualTo: _userId)
          .get();

      print('Total contact directories: ${directoriesSnapshot.docs.length}');

      // Group contacts by list name
      Map<String, ListPerformanceData> listPerformanceMap = {};

      for (var doc in directoriesSnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final listName = data['list_name'] as String? ?? 'Unnamed List';
          final phoneNumber = data['phone_number'] as String? ?? '';

          if (phoneNumber.isEmpty) continue;

          // Initialize list data if not exists
          if (!listPerformanceMap.containsKey(listName)) {
            listPerformanceMap[listName] = ListPerformanceData(listName: listName);
          }

          listPerformanceMap[listName]!.totalContactsInList++;
        } catch (e) {
          print('Error parsing directory doc: $e');
        }
      }

      // Fetch all call history
      final QuerySnapshot callHistorySnapshot = await _firestore
          .collection('call_history')
          .where('user_id', isEqualTo: _userId)
          .get();

      print('Total call history records: ${callHistorySnapshot.docs.length}');

      // Create a map of phone numbers to list names from directories
      Map<String, String> phoneToListMap = {};
      for (var doc in directoriesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final phoneNumber = _normalizePhone(data['phone_number'] as String? ?? '');
        final listName = data['list_name'] as String? ?? 'Unnamed List';
        if (phoneNumber.isNotEmpty) {
          phoneToListMap[phoneNumber] = listName;
        }
      }

      // Process call history and match to lists
      for (var doc in callHistorySnapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          final phoneNumber = _normalizePhone(data['address'] as String? ?? '');
          
          if (phoneNumber.isEmpty) continue;

          // Find which list this phone number belongs to
          final listName = phoneToListMap[phoneNumber];
          if (listName == null) continue;

          if (!listPerformanceMap.containsKey(listName)) {
            listPerformanceMap[listName] = ListPerformanceData(listName: listName);
          }

          final listData = listPerformanceMap[listName]!;
          listData.totalCalls++;

          final duration = (data['duration'] as num?)?.toDouble() ?? 0.0;
          final callType = data['call_type'] as String? ?? '';
          
          bool answered;
          if (data['answered'] is bool) {
            answered = data['answered'] as bool;
          } else if (data['answered'] is int) {
            answered = (data['answered'] as int) == 1;
          } else {
            answered = false;
          }

          // Count connected calls
          if (callType.toLowerCase() != 'missed' && (answered || duration > 0)) {
            listData.connectedCalls++;
          }
        } catch (e) {
          print('Error parsing call history doc: $e');
        }
      }

      // Calculate success rates
      List<ListPerformanceData> listDataList = listPerformanceMap.values.toList();
      for (var listData in listDataList) {
        if (listData.totalCalls > 0) {
          listData.successRate = (listData.connectedCalls / listData.totalCalls) * 100;
        }
        print('${listData.listName}: ${listData.totalCalls} calls, ${listData.connectedCalls} connected, ${listData.successRate.toStringAsFixed(1)}%');
      }

      // Sort the list
      _sortListData(listDataList);

      if (mounted) {
        setState(() {
          _listData = listDataList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching list performance: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sortListData(List<ListPerformanceData> data) {
    switch (_sortBy) {
      case 'successRate':
        data.sort((a, b) => b.successRate.compareTo(a.successRate));
        break;
      case 'totalCalls':
        data.sort((a, b) => b.totalCalls.compareTo(a.totalCalls));
        break;
      case 'alphabetical':
        data.sort((a, b) => a.listName.compareTo(b.listName));
        break;
    }
  }

  String _normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= 9) {
      return digitsOnly.substring(digitsOnly.length - 9);
    }
    return digitsOnly;
  }

  Color _getSuccessRateColor(double successRate) {
    if (successRate >= 70) {
      return Colors.green;
    } else if (successRate >= 40) {
      return Colors.yellow.shade700;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'List Performance Comparison',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Compare effectiveness across all your contact lists',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Sort options
          Row(
            children: [
              Text(
                'Sort by:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Success Rate'),
                      selected: _sortBy == 'successRate',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _sortBy = 'successRate';
                            _sortListData(_listData);
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Total Calls'),
                      selected: _sortBy == 'totalCalls',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _sortBy = 'totalCalls';
                            _sortListData(_listData);
                          });
                        }
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Alphabetical'),
                      selected: _sortBy == 'alphabetical',
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _sortBy = 'alphabetical';
                            _sortListData(_listData);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('High (70%+)', Colors.green),
              _buildLegendItem('Medium (40-70%)', Colors.yellow.shade700),
              _buildLegendItem('Low (<40%)', Colors.red),
            ],
          ),

          const SizedBox(height: 24),

          // Chart
          if (_isLoading)
            const SizedBox(
              height: 400,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_listData.isEmpty)
            SizedBox(
              height: 400,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No list data found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create contact lists and make calls to see performance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: (_listData.length * 60.0).clamp(300, 600),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => Colors.blueGrey,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final listData = _listData[groupIndex];
                        return BarTooltipItem(
                          '${listData.listName}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: 'Success: ${listData.successRate.toStringAsFixed(1)}%\n',
                              style: const TextStyle(fontSize: 12),
                            ),
                            TextSpan(
                              text: 'Calls: ${listData.totalCalls}\n',
                              style: const TextStyle(fontSize: 12),
                            ),
                            TextSpan(
                              text: 'Connected: ${listData.connectedCalls}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '${value.toInt()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 120,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _listData.length) {
                            final listName = _listData[index].listName;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                listName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: false,
                    verticalInterval: 10,
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  barGroups: _buildBarGroups(),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Detailed breakdown
          if (!_isLoading && _listData.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detailed Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._listData.map((listData) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  listData.listName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getSuccessRateColor(listData.successRate).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${listData.successRate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _getSuccessRateColor(listData.successRate),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildStatBadge('Contacts: ${listData.totalContactsInList}', Colors.blue),
                              const SizedBox(width: 8),
                              _buildStatBadge('Calls: ${listData.totalCalls}', Colors.purple),
                              const SizedBox(width: 8),
                              _buildStatBadge('Connected: ${listData.connectedCalls}', Colors.green),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: listData.successRate / 100,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getSuccessRateColor(listData.successRate),
                            ),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    List<BarChartGroupData> groups = [];

    for (int i = 0; i < _listData.length; i++) {
      final listData = _listData[i];
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: listData.successRate,
              color: _getSuccessRateColor(listData.successRate),
              width: 20,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
              gradient: LinearGradient(
                colors: [
                  _getSuccessRateColor(listData.successRate).withOpacity(0.7),
                  _getSuccessRateColor(listData.successRate),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return groups;
  }
}

class ListPerformanceData {
  final String listName;
  int totalContactsInList = 0;
  int totalCalls = 0;
  int connectedCalls = 0;
  double successRate = 0.0;

  ListPerformanceData({required this.listName});
}
