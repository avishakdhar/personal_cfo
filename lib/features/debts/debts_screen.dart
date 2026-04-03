import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/debt_model.dart';
import '../../core/providers/app_providers.dart';
import 'add_debt_screen.dart';
import 'debt_calculator_screen.dart';

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts & Loans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Debt Calculator',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DebtCalculatorScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Debt'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDebtScreen()))
            .then((_) => ref.invalidate(debtsProvider)),
      ),
      body: debtsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (debts) {
          if (debts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No debts tracked', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Track loans, EMIs, and credit card dues', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final totalOutstanding = debts.fold(0.0, (s, d) => s + d.outstanding);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              Card(
                color: Colors.red.withOpacity(0.1),
                child: ListTile(
                  leading: const Icon(Icons.account_balance, color: Colors.red),
                  title: const Text('Total Outstanding'),
                  trailing: Text(
                    '₹${_fmt(totalOutstanding)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...debts.map((debt) => _DebtCard(
                debt: debt,
                onEdit: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddDebtScreen(debt: debt)))
                  .then((_) => ref.invalidate(debtsProvider)),
                onDelete: () => ref.read(debtsProvider.notifier).delete(debt.id!),
                onPayEmi: () => _showEmiPayment(context, ref, debt),
              )),
            ],
          );
        },
      ),
    );
  }

  void _showEmiPayment(BuildContext context, WidgetRef ref, Debt debt) {
    final ctrl = TextEditingController(text: debt.emiAmount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record EMI — ${debt.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Outstanding: ₹${NumberFormat('#,##,##0.##', 'en_IN').format(debt.outstanding)}'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'EMI Amount', prefixText: '₹ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              await ref.read(debtsProvider.notifier).recordEmi(debt.id!, amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPayEmi;

  const _DebtCard({required this.debt, required this.onEdit, required this.onDelete, required this.onPayEmi});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context) {
    final remaining = debt.remainingMonths;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Text(debt.type, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'emi') onPayEmi();
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'emi', child: Text('Record EMI')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (debt.lender.isNotEmpty)
              Text('Lender: ${debt.lender}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: debt.progressPercent,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Outstanding: ₹${_fmt(debt.outstanding)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                Text('Principal: ₹${_fmt(debt.principal)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (debt.emiAmount > 0)
                  Text('EMI: ₹${_fmt(debt.emiAmount)}/mo', style: const TextStyle(fontSize: 12)),
                if (debt.interestRate > 0)
                  Text('Rate: ${debt.interestRate}% p.a.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            if (remaining != null)
              Text('~$remaining months remaining', style: const TextStyle(fontSize: 12, color: Colors.orange)),
            if (debt.isFullyPaid)
              const Text('Fully Paid!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onPayEmi,
                child: const Text('Record EMI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
