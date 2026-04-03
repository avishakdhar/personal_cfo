import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SpendingChart extends StatelessWidget {

  final Map<String, double> categoryData;

  const SpendingChart({super.key, required this.categoryData});

  @override
  Widget build(BuildContext context) {

    final entries = categoryData.entries.toList();

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,

          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true),
            ),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {

                  if (value.toInt() >= entries.length) {
                    return const Text('');
                  }

                  return Text(
                    entries[value.toInt()].key,
                    style: const TextStyle(fontSize: 10),
                  );

                },
              ),
            ),
          ),

          barGroups: List.generate(entries.length, (index) {

            final amount = entries[index].value;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: amount,
                ),
              ],
            );

          }),

        ),
      ),
    );
  }
}