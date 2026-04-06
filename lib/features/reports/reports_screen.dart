import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/export_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late int _selectedMonth;
  late int _selectedYear;
  bool _loading = false;
  String? _error;

  Map<String, double> _categorySpending = {};
  double _totalSpending = 0;
  double _totalIncome = 0;
  List<Map<String, dynamic>> _monthlyHistory = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = DatabaseHelper.instance;
      final categorySpending = await db.getCategorySpending(month: _selectedMonth, year: _selectedYear);
      final totalSpending = await db.getTotalSpending(month: _selectedMonth, year: _selectedYear);
      final monthlyHistory = await db.getMonthlySpendingHistory(months: 6);

      final start = DateTime(_selectedYear, _selectedMonth, 1);
      final end = DateTime(_selectedYear, _selectedMonth + 1, 1);
      final incomeTxs = await db.getTransactions(type: 'income', startDate: start, endDate: end);
      final totalIncome = incomeTxs.fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

      setState(() {
        _categorySpending = categorySpending;
        _totalSpending = totalSpending;
        _totalIncome = totalIncome;
        _monthlyHistory = monthlyHistory;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _shareReport() async {
    try {
      await ExportService.instance.shareMonthlyReport(
        month: _selectedMonth,
        year: _selectedYear,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) { _selectedMonth = 1; _selectedYear++; }
      if (_selectedMonth < 1) { _selectedMonth = 12; _selectedYear--; }
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));
    final savings = _totalIncome - _totalSpending;
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Report',
            onPressed: _shareReport,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // ─── Month Selector ─────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _changeMonth(-1),
                          ),
                          Expanded(
                            child: Text(
                              monthLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: DateTime(_selectedYear, _selectedMonth + 1, 1)
                                    .isAfter(DateTime.now())
                                ? null
                                : () => _changeMonth(1),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ─── Summary Cards ──────────────────────────────────
                      Row(
                        children: [
                          Expanded(child: _SummaryCard(
                            label: 'Income', value: '₹${fmt.format(_totalIncome)}',
                            icon: Icons.arrow_downward, color: Colors.green,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _SummaryCard(
                            label: 'Expenses', value: '₹${fmt.format(_totalSpending)}',
                            icon: Icons.arrow_upward, color: Colors.red,
                          )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Card(
                        color: savings >= 0 ? Colors.green.withAlpha(26) : Colors.red.withAlpha(26),
                        child: ListTile(
                          leading: Icon(
                            savings >= 0 ? Icons.savings_outlined : Icons.trending_down,
                            color: savings >= 0 ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            savings >= 0 ? 'Saved This Month' : 'Overspent This Month',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Text(
                            '${savings >= 0 ? '+' : ''}₹${fmt.format(savings.abs())}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: savings >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ─── Spending by Category ───────────────────────────
                      if (_categorySpending.isNotEmpty) ...[
                        const Text('Spending by Category',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _CategoryBreakdown(
                          data: _categorySpending,
                          total: _totalSpending,
                        ),
                      ] else
                        const _EmptyMonthCard(),

                      const SizedBox(height: 20),

                      // ─── Monthly Trend ──────────────────────────────────
                      if (_monthlyHistory.length > 1) ...[
                        const Text('6-Month Spending Trend',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _MonthlyTrendChart(history: _monthlyHistory),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withAlpha(31),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Category Breakdown ───────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> data;
  final double total;

  const _CategoryBreakdown({required this.data, required this.total});

  static const _colors = [
    Color(0xFF6750A4), Color(0xFF009688), Color(0xFFE65100),
    Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFC62828),
    Color(0xFF4527A0), Color(0xFF00695C), Color(0xFFF57F17),
    Color(0xFF37474F),
  ];

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: sorted.asMap().entries.map((entry) {
            final idx = entry.key % _colors.length;
            final e = entry.value;
            final pct = total > 0 ? e.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 10, height: 10,
                          decoration: BoxDecoration(color: _colors[idx], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.key)),
                      Text('₹${fmt.format(e.value)}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('${(pct * 100).toStringAsFixed(1)}%',
                          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: _colors[idx].withAlpha(31),
                      valueColor: AlwaysStoppedAnimation(_colors[idx]),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Monthly Trend Chart ──────────────────────────────────────────────────────

class _MonthlyTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _MonthlyTrendChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = history.map((h) => (h['total'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVal * 1.2,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxVal / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: cs.outlineVariant.withAlpha(77),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= history.length) return const Text('');
                  final h = history[i];
                  return Text(
                    DateFormat('MMM').format(DateTime(h['year'], h['month'])),
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => cs.surfaceContainerHigh,
              getTooltipItem: (group, _, rod, _) {
                final h = history[group.x];
                return BarTooltipItem(
                  '${DateFormat('MMM yy').format(DateTime(h['year'], h['month']))}\n₹${NumberFormat('#,##,##0', 'en_IN').format(rod.toY)}',
                  TextStyle(color: cs.onSurface, fontSize: 12),
                );
              },
            ),
          ),
          barGroups: history.asMap().entries.map((entry) {
            final total = (entry.value['total'] as num).toDouble();
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: total,
                  color: cs.primary,
                  width: 24,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Empty Month Card ─────────────────────────────────────────────────────────

class _EmptyMonthCard extends StatelessWidget {
  const _EmptyMonthCard();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.bar_chart_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No transactions this month', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
}
