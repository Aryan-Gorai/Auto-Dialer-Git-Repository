import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "package:flutter_application_1/views/reports/bar_graph/bar_data.dart";



// BAR DATA




import 'individual_bar.dart';

class BarData {


  final double sunAmount;
  final double monAmount;
  final double tueAmount;
  final double wedAmount;


  BarData ({
    required this.sunAmount, 
    required this.monAmount, 
    required this.tueAmount, 
    required this.wedAmount,
    });

    List<IndividualBar> barData = [];

    void initializeBarData() {
      barData = [
        IndividualBar(x: 0, y: sunAmount),
        IndividualBar(x: 0, y: monAmount),
        IndividualBar(x: 0, y: tueAmount),
        IndividualBar(x: 0, y: wedAmount),

      ];
    }


}




// BAR DATA









class MyBarGraph extends StatelessWidget {
  final List weeklySummary;
  const MyBarGraph({super.key, required this.weeklySummary});

  @override
  Widget build(BuildContext context) {

    BarData myBarData = BarData(
      sunAmount: weeklySummary[0], 
      monAmount: weeklySummary[1], 
      tueAmount: weeklySummary[2], 
      wedAmount: weeklySummary[3]
      );
      myBarData.initializeBarData(); 

    return BarChart(
      BarChartData(
        maxY: 100,
        minY: 0,
        barGroups: myBarData.barData
        .map((data) => BarChartGroupData(
          x:data.x,
          barRods: [BarChartRodData(toY: data.y)]
        ),
        )
        .toList(),
        ),
      );
    
  }
}