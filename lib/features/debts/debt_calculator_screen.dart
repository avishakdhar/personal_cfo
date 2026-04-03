import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/debt_model.dart';
import '../../core/providers/app_providers.dart';

class DebtCalculatorScreen extends ConsumerStatefulWidget {
  const DebtCalculatorScreen({super.key});

  @override
  ConsumerState<DebtCalculatorScreen> createState() => _DebtCalculatorScreenState();
}

class _DebtCalculatorScreenState extends ConsumerState<DebtCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Calculator'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'EMI Calc'),
            Tab(text: 'Amortization'),
            Tab(text: 'Payoff Strategy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _EmiCalculatorTab(),
          _AmortizationTab(),
          _PayoffStrategyTab(),
        ],
      ),
    );
  }
}

// ─── EMI Calculator ───────────────────────────────────────────────────────────

class _EmiCalculatorTab extends StatefulWidget {
  const _EmiCalculatorTab();

  @override
  State<_EmiCalculatorTab> createState() => _EmiCalculatorTabState();
}

class _EmiCalculatorTabState extends State<_EmiCalculatorTab> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  double? _emi;
  double? _totalInterest;
  double? _totalPayment;

  void _calculate() {
    final principal = double.tryParse(_principalCtrl.text);
    final annualRate = double.tryParse(_rateCtrl.text);
    final tenureMonths = int.tryParse(_tenureCtrl.text);

    if (principal == null || annualRate == null || tenureMonths == null) return;
    if (principal <= 0 || annualRate < 0 || tenureMonths <= 0) return;

    if (annualRate == 0) {
      setState(() {
        _emi = principal / tenureMonths;
        _totalInterest = 0;
        _totalPayment = principal;
      });
      return;
    }

    final monthlyRate = annualRate / 12 / 100;
    final emi = principal *
        monthlyRate *
        pow(1 + monthlyRate, tenureMonths) /
        (pow(1 + monthlyRate, tenureMonths) - 1);

    setState(() {
      _emi = emi;
      _totalPayment = emi * tenureMonths;
      _totalInterest = _totalPayment! - principal;
    });
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0.##', 'en_IN');
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _principalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Loan Amount (Principal)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Annual Interest Rate (%)',
                      suffixText: '% p.a.',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tenureCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Loan Tenure (Months)',
                      suffixText: 'months',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _calculate(),
                  ),
                ],
              ),
            ),
          ),
          if (_emi != null) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text('Monthly EMI',
                        style: TextStyle(fontSize: 14, color: cs.onPrimaryContainer.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text(
                      '₹${fmt.format(_emi!)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ResultCard(
                    label: 'Total Interest',
                    value: '₹${fmt.format(_totalInterest!)}',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultCard(
                    label: 'Total Payment',
                    value: '₹${fmt.format(_totalPayment!)}',
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Interest vs Principal pie indicator
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment Breakdown',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _BreakdownBar(
                      principalAmount: double.parse(_principalCtrl.text),
                      interestAmount: _totalInterest!,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _LegendDot(color: cs.primary, label: 'Principal ₹${fmt.format(double.parse(_principalCtrl.text))}'),
                        const SizedBox(width: 16),
                        _LegendDot(color: Colors.orange, label: 'Interest ₹${fmt.format(_totalInterest!)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Amortization Schedule ────────────────────────────────────────────────────

class _AmortizationTab extends StatefulWidget {
  const _AmortizationTab();

  @override
  State<_AmortizationTab> createState() => _AmortizationTabState();
}

class _AmortizationTabState extends State<_AmortizationTab> {
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  List<_AmortRow>? _schedule;

  void _calculate() {
    final principal = double.tryParse(_principalCtrl.text);
    final annualRate = double.tryParse(_rateCtrl.text);
    final tenureMonths = int.tryParse(_tenureCtrl.text);

    if (principal == null || annualRate == null || tenureMonths == null) return;
    if (principal <= 0 || tenureMonths <= 0) return;

    final rows = <_AmortRow>[];
    double balance = principal;
    final monthlyRate = annualRate > 0 ? annualRate / 12 / 100 : 0;

    double emi;
    if (monthlyRate == 0) {
      emi = principal / tenureMonths;
    } else {
      emi = principal *
          monthlyRate *
          pow(1 + monthlyRate, tenureMonths) /
          (pow(1 + monthlyRate, tenureMonths) - 1);
    }

    for (int month = 1; month <= tenureMonths; month++) {
      final interest = balance * monthlyRate;
      final principalPaid = emi - interest;
      balance = (balance - principalPaid).clamp(0, double.infinity);
      rows.add(_AmortRow(
        month: month,
        emi: emi,
        principal: principalPaid,
        interest: interest,
        balance: balance,
      ));
      if (balance <= 0) break;
    }

    setState(() => _schedule = rows);
  }

  @override
  void dispose() {
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _principalCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Principal (₹)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Rate (% p.a.)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _tenureCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tenure (mo)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ),
            ],
          ),
        ),
        if (_schedule == null)
          const Expanded(
            child: Center(
              child: Text('Enter loan details above', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columnSpacing: 12,
                headingRowColor: WidgetStateProperty.all(
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                columns: const [
                  DataColumn(label: Text('Mo')),
                  DataColumn(label: Text('EMI'), numeric: true),
                  DataColumn(label: Text('Principal'), numeric: true),
                  DataColumn(label: Text('Interest'), numeric: true),
                  DataColumn(label: Text('Balance'), numeric: true),
                ],
                rows: _schedule!.map((row) => DataRow(
                  cells: [
                    DataCell(Text('${row.month}')),
                    DataCell(Text(fmt.format(row.emi))),
                    DataCell(Text(fmt.format(row.principal))),
                    DataCell(Text(fmt.format(row.interest),
                        style: const TextStyle(color: Colors.orange))),
                    DataCell(Text(fmt.format(row.balance),
                        style: TextStyle(
                          color: row.balance == 0 ? Colors.green : null,
                          fontWeight: row.balance == 0 ? FontWeight.bold : null,
                        ))),
                  ],
                )).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Payoff Strategy ──────────────────────────────────────────────────────────

class _PayoffStrategyTab extends ConsumerWidget {
  const _PayoffStrategyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    final cs = Theme.of(context).colorScheme;

    return debtsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (debts) {
        final activeDebts = debts.where((d) => d.outstanding > 0).toList();

        if (activeDebts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('No active debts!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        // Avalanche: highest interest first
        final avalanche = List<Debt>.from(activeDebts)
          ..sort((a, b) => b.interestRate.compareTo(a.interestRate));

        // Snowball: lowest balance first
        final snowball = List<Debt>.from(activeDebts)
          ..sort((a, b) => a.outstanding.compareTo(b.outstanding));

        final totalOutstanding = activeDebts.fold(0.0, (s, d) => s + d.outstanding);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: cs.errorContainer,
                child: ListTile(
                  leading: Icon(Icons.account_balance, color: cs.error),
                  title: const Text('Total Debt Outstanding'),
                  trailing: Text(
                    '₹${fmt.format(totalOutstanding)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.error),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Avalanche
              _StrategyCard(
                title: 'Debt Avalanche',
                subtitle: 'Pay off highest interest rate first — saves the most money',
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
                debts: avalanche,
                fmt: fmt,
              ),
              const SizedBox(height: 16),

              // Snowball
              _StrategyCard(
                title: 'Debt Snowball',
                subtitle: 'Pay off smallest balance first — quick wins for motivation',
                icon: Icons.ac_unit,
                color: Colors.blue,
                debts: snowball,
                fmt: fmt,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StrategyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Debt> debts;
  final NumberFormat fmt;

  const _StrategyCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.debts,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...debts.asMap().entries.map((entry) {
              final i = entry.key;
              final debt = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: color.withOpacity(0.12),
                      child: Text('${i + 1}',
                          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(debt.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '${debt.interestRate}% p.a. · Outstanding: ₹${fmt.format(debt.outstanding)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (debt.emiAmount > 0)
                      Text('₹${fmt.format(debt.emiAmount)}/mo',
                          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _AmortRow {
  final int month;
  final double emi;
  final double principal;
  final double interest;
  final double balance;
  const _AmortRow({
    required this.month,
    required this.emi,
    required this.principal,
    required this.interest,
    required this.balance,
  });
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ResultCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
            ],
          ),
        ),
      );
}

class _BreakdownBar extends StatelessWidget {
  final double principalAmount;
  final double interestAmount;
  const _BreakdownBar({required this.principalAmount, required this.interestAmount});

  @override
  Widget build(BuildContext context) {
    final total = principalAmount + interestAmount;
    final pct = total > 0 ? principalAmount / total : 0.5;
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            Expanded(flex: (pct * 100).round(), child: Container(color: cs.primary)),
            Expanded(flex: ((1 - pct) * 100).round(), child: Container(color: Colors.orange)),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      );
}
