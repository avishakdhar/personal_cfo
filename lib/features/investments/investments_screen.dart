import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/investment_model.dart';
import '../../core/providers/app_providers.dart';
import 'add_investment_screen.dart';
import 'add_sip_screen.dart';

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Investments')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'sip',
            tooltip: 'Add SIP Installment',
            onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddSipScreen()))
                .then((_) => ref.invalidate(investmentsProvider)),
            child: const Icon(Icons.repeat),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'investment',
            icon: const Icon(Icons.add),
            label: const Text('Add Investment'),
            onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddInvestmentScreen()))
                .then((_) => ref.invalidate(investmentsProvider)),
          ),
        ],
      ),
      body: invAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (investments) {
          if (investments.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.trending_up_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No investments tracked', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Track stocks, mutual funds, FDs, and more', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final totalInvested = investments.fold(0.0, (s, i) => s + i.totalInvested);
          final currentValue = investments.fold(0.0, (s, i) => s + i.currentValue);
          final totalPnL = currentValue - totalInvested;
          final pnlPct = totalInvested > 0 ? (totalPnL / totalInvested * 100) : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              // Portfolio summary
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Portfolio Value', style: TextStyle(fontSize: 13)),
                            Text('₹${_fmt(currentValue)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            const Text('Total P&L', style: TextStyle(fontSize: 13)),
                            Text(
                              '${totalPnL >= 0 ? '+' : ''}₹${_fmt(totalPnL)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: totalPnL >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                            Text(
                              '${pnlPct >= 0 ? '+' : ''}${pnlPct.toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 12,
                                color: totalPnL >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(color: Theme.of(context).colorScheme.onPrimaryContainer.withAlpha(51)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Invested: ₹${_fmt(totalInvested)}', style: const TextStyle(fontSize: 13)),
                          Text('${investments.length} holdings', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...investments.map((inv) => _InvestmentCard(
                investment: inv,
                onEdit: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddInvestmentScreen(investment: inv)))
                  .then((_) => ref.invalidate(investmentsProvider)),
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete investment?'),
                      content: Text('Delete "${inv.name}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) ref.read(investmentsProvider.notifier).delete(inv.id!);
                },
              )),
            ],
          );
        },
      ),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  final Investment investment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvestmentCard({required this.investment, required this.onEdit, required this.onDelete});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context) {
    final inv = investment;
    final pnl = inv.profitLoss;
    final pnlColor = pnl >= 0 ? Colors.green : Colors.red;
    // Growth ratio: 0 = no growth, 1 = doubled
    final growthRatio = inv.totalInvested > 0
        ? (inv.currentValue / inv.totalInvested).clamp(0.0, 2.0) / 2.0
        : 0.0;
    final isFixedIncome = Investment.fixedIncomeTypes.contains(inv.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    inv.type.substring(0, 1),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(inv.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${inv.type}${inv.symbol != null ? ' · ${inv.symbol}' : ''} · Qty: ${inv.quantity}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${_fmt(inv.currentValue)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(
                      '${pnl >= 0 ? '+' : ''}₹${_fmt(pnl)} (${inv.profitLossPercent.toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 11, color: pnlColor),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar: invested → current value
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: growthRatio,
                minHeight: 6,
                backgroundColor: Colors.grey.withAlpha(51),
                valueColor: AlwaysStoppedAnimation<Color>(pnlColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Invested: ₹${_fmt(inv.totalInvested)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (isFixedIncome && inv.annualRate > 0)
                  Text('${inv.annualRate}% p.a.', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    onPressed: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
