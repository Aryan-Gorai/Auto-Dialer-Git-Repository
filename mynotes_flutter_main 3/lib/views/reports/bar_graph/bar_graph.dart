import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class IndividualBar {
  final int x;
  final double y;

  IndividualBar({required this.x, required this.y});
}

class BarData {
  final List<double> listPercentages;

  BarData({required this.listPercentages});

  List<IndividualBar> barData = [];

  void initializeBarData() {
    barData = listPercentages.asMap().entries.map((entry) {
      return IndividualBar(x: entry.key, y: entry.value);
    }).toList();
  }
}

class MyBarGraph extends StatelessWidget {
  final List<double> weeklySummary;

  const MyBarGraph({Key? key, required this.weeklySummary}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    BarData myBarData = BarData(listPercentages: weeklySummary);
    myBarData.initializeBarData();

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        barGroups: myBarData.barData.map((data) {
          return BarChartGroupData(
            x: data.x,
            barRods: [BarChartRodData(toY: data.y)],
          );
        }).toList(),
      ),
    );
  }
}
