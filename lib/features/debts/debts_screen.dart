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
                color: Colors.red.withAlpha(26),
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
                onDelete: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete debt?'),
                      content: Text('Delete "${debt.name}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) ref.read(debtsProvider.notifier).delete(debt.id!);
                },
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
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final accountsAsync = ref.watch(accountsProvider);
          return AlertDialog(
            title: Text('Record EMI — ${debt.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outstanding: ₹${NumberFormat('#,##,##0.##', 'en_IN').format(debt.outstanding)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'EMI Amount', prefixText: '₹ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                accountsAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (accounts) => InputDecorator(
                    decoration: const InputDecoration(labelText: 'Pay from account', border: OutlineInputBorder()),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedAccountId,
                        isDense: true,
                        isExpanded: true,
                        hint: const Text('Select account'),
                        items: accounts.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setDialogState(() => selectedAccountId = v),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(ctrl.text);
                  if (amount == null || amount <= 0) return;
                  if (selectedAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an account')),
                    );
                    return;
                  }
                  await ref.read(debtsProvider.notifier).recordEmi(debt.id!, amount, selectedAccountId!, debt.name);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Record Payment'),
              ),
            ],
          );
        },
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(debt.type, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
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
                backgroundColor: Colors.grey.withAlpha(51),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    onPressed: onEdit,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: onDelete,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: debt.isFullyPaid ? null : onPayEmi,
                child: const Text('Pay EMI'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
