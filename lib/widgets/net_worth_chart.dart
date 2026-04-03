import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../core/models/net_worth_snapshot_model.dart';

class NetWorthChart extends StatelessWidget {
  final List<NetWorthSnapshot> snapshots;

  const NetWorthChart({super.key, required this.snapshots});

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final spots = snapshots.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.netWorth))
        .toList();

    final minY = snapshots.map((s) => s.netWorth).reduce((a, b) => a < b ? a : b);
    final maxY = snapshots.map((s) => s.netWorth).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY).abs() * 0.1 + 1000;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY + padding * 2) / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final formatted = _shortFmt(value);
                  return Text(formatted,
                      style: TextStyle(fontSize: 10, color: cs.outline));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (snapshots.length / 4).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= snapshots.length) return const Text('');
                  final d = snapshots[idx].date;
                  return Text(DateFormat('MMM yy').format(d),
                      style: TextStyle(fontSize: 9, color: cs.outline));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainerHigh,
              getTooltipItems: (spots) => spots.map((s) {
                final snap = snapshots[s.x.toInt()];
                return LineTooltipItem(
                  '${DateFormat('MMM yy').format(snap.date)}\n₹${_shortFmt(s.y)}',
                  TextStyle(color: cs.onSurface, fontSize: 12),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: cs.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: snapshots.length <= 6,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: cs.primary,
                  strokeWidth: 2,
                  strokeColor: cs.surface,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.primary.withOpacity(0.25),
                    cs.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortFmt(double value) {
    if (value.abs() >= 10000000) return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    if (value.abs() >= 100000) return '₹${(value / 100000).toStringAsFixed(1)}L';
    if (value.abs() >= 1000) return '₹${(value / 1000).toStringAsFixed(0)}K';
    return '₹${value.toStringAsFixed(0)}';
  }
}
