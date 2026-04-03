import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/budget_model.dart';
import '../../core/providers/app_providers.dart';
import 'add_budget_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text('Budgets — ${DateFormat('MMMM yyyy').format(now)}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Budget'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBudgetScreen()))
            .then((_) => ref.invalidate(budgetsProvider)),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No budgets set', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('Set spending limits by category', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add Budget'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBudgetScreen()))
                        .then((_) => ref.invalidate(budgetsProvider)),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(budgetsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              itemCount: budgets.length,
              itemBuilder: (context, i) => _BudgetCard(
                budget: budgets[i],
                onDelete: () => ref.read(budgetsProvider.notifier).delete(budgets[i].id!),
                onEdit: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddBudgetScreen(budget: budgets[i])))
                  .then((_) => ref.invalidate(budgetsProvider)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final Budget budget;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BudgetCard({required this.budget, required this.onDelete, required this.onEdit});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync = ref.watch(budgetSpentProvider(budget.category));

    return spentAsync.when(
      loading: () => const Card(child: ListTile(title: Text('Loading...'))),
      error: (e, _) => const SizedBox.shrink(),
      data: (spent) {
        final progress = budget.amountLimit > 0 ? (spent / budget.amountLimit).clamp(0.0, 1.0) : 0.0;
        final remaining = budget.amountLimit - spent;
        final isOver = spent > budget.amountLimit;
        final progressColor = progress > 0.9 ? Colors.red : (progress > 0.7 ? Colors.orange : Colors.green);

        return Dismissible(
          key: Key('budget_${budget.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => onDelete(),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(budget.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      if (isOver)
                        const Chip(
                          label: Text('Over Budget', style: TextStyle(color: Colors.white, fontSize: 11)),
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.zero,
                        ),
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spent: ₹${_fmt(spent)}', style: TextStyle(color: progressColor, fontWeight: FontWeight.w600)),
                      Text('Limit: ₹${_fmt(budget.amountLimit)}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Text(
                    isOver ? 'Over by ₹${_fmt(-remaining)}' : 'Remaining: ₹${_fmt(remaining)}',
                    style: TextStyle(fontSize: 12, color: isOver ? Colors.red : Colors.green),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
