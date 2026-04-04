import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/providers/app_providers.dart';
import '../../widgets/spending_chart.dart';
import '../../widgets/net_worth_chart.dart';
import '../transactions/add_expense_screen.dart';
import '../transactions/add_income_screen.dart';
import '../transactions/transfer_screen.dart';
import '../debts/add_debt_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);
    final netWorthAsync = ref.watch(netWorthSnapshotsProvider);
    final userName = ref.watch(userNameProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, $userName', style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          ref.invalidate(netWorthSnapshotsProvider);
          ref.invalidate(accountsProvider);
        },
        child: dashAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Premium Net Worth Card
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withAlpha(200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withAlpha(76), blurRadius: 16, offset: const Offset(0, 8)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Net Worth', style: TextStyle(color: cs.onPrimary.withAlpha(200), fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_fmt(data.netWorth)}',
                        style: TextStyle(color: cs.onPrimary, fontSize: 36, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _AnimatedMiniStat(label: 'Assets', value: '₹${_fmt(data.totalAssets)}', color: Colors.greenAccent),
                          const SizedBox(width: 32),
                          _AnimatedMiniStat(label: 'Liabilities', value: '₹${_fmt(data.totalLiabilities)}', color: Colors.redAccent),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.today,
                      label: "Today's Spend",
                      value: '₹${_fmt(data.todaySpending)}',
                      color: Colors.orange,
                    ).animate(delay: 100.ms).fade().slideY(begin: 0.1),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_month,
                      label: 'This Month',
                      value: '₹${_fmt(data.monthlySpending)}',
                      color: cs.primary,
                    ).animate(delay: 200.ms).fade().slideY(begin: 0.1),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface.withAlpha(150))).animate(delay: 300.ms).fade(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.arrow_downward_rounded,
                      label: 'Expense',
                      color: Colors.red,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())).then((_) {
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(accountsProvider);
                      }),
                    ).animate(delay: 300.ms).scale(),
                  ),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.arrow_upward_rounded,
                      label: 'Income',
                      color: Colors.green,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddIncomeScreen())).then((_) {
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(accountsProvider);
                      }),
                    ).animate(delay: 400.ms).scale(),
                  ),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer',
                      color: Colors.blue,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen())).then((_) {
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(accountsProvider);
                      }),
                    ).animate(delay: 500.ms).scale(),
                  ),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.credit_card_rounded,
                      label: 'Liability',
                      color: Colors.purple,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDebtScreen())).then((_) {
                        ref.invalidate(dashboardProvider);
                        ref.invalidate(debtsProvider);
                      }),
                    ).animate(delay: 600.ms).scale(),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              if (data.categorySpending.isNotEmpty) ...[
                Text('Spending Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SpendingChart(categoryData: data.categorySpending),
                const SizedBox(height: 32),
              ].animate(delay: 500.ms).fade().slideY(begin: 0.1),
              
              netWorthAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (snapshots) => snapshots.length > 1
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Net Worth History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          NetWorthChart(snapshots: snapshots),
                        ],
                      ).animate(delay: 600.ms).fade().slideY(begin: 0.1)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedMiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AnimatedMiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary.withAlpha(200))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
        ],
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withAlpha(76)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withAlpha(179))),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withAlpha(25), blurRadius: 10, offset: const Offset(0, 4)),
                  BoxShadow(color: cs.shadow.withAlpha(15), blurRadius: 4, offset: const Offset(0, 2)),
                ],
                border: Border.all(color: color.withAlpha(50)),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
