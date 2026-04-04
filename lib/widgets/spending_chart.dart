import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SpendingChart extends StatefulWidget {
  final Map<String, double> categoryData;
  const SpendingChart({super.key, required this.categoryData});

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  int touchedIndex = -1;

  final List<Color> pieColors = [
    const Color(0xFF6750A4), // Primary Purple
    const Color(0xFFF25022), // Bright Orange/Red
    const Color(0xFF7FBA00), // Green
    const Color(0xFF00A4EF), // Blue
    const Color(0xFFFFB900), // Yellow
    const Color(0xFFE91E63), // Pink
    const Color(0xFF009688), // Teal
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.categoryData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No spending data to visualize.')),
      );
    }

    final entries = widget.categoryData.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value)); // Sort descending

    final total = entries.fold<double>(0, (sum, item) => sum + item.value);

    return AspectRatio(
      aspectRatio: 1.2,
      child: Row(
        children: <Widget>[
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 50,
                  sections: showingSections(entries, total),
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              entries.length > 6 ? 6 : entries.length, // Show up to 6 in legend
              (i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Indicator(
                  color: pieColors[i % pieColors.length],
                  text: entries[i].key,
                  isSquare: false,
                  size: touchedIndex == i ? 18 : 14,
                  textColor: touchedIndex == i ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withAlpha(180),
                ),
              ),
            )..addAll(
               entries.length > 6 ? [const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('... Others', style: TextStyle(fontSize: 12)))] : [],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  List<PieChartSectionData> showingSections(List<MapEntry<String, double>> entries, double total) {
    return List.generate(entries.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final percentage = (entries[i].value / total * 100);

      return PieChartSectionData(
        color: pieColors[i % pieColors.length],
        value: entries[i].value,
        title: percentage > 4 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black.withAlpha(100), blurRadius: 2)],
        ),
      );
    });
  }
}

class Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  const Indicator({
    super.key,
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        )
      ],
    );
  }
}