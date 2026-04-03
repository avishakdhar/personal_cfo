import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/recurring_transaction_model.dart';
import '../../core/providers/app_providers.dart';
import 'add_recurring_screen.dart';

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Recurring'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddRecurringScreen()))
            .then((_) => ref.invalidate(recurringProvider)),
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.repeat_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No recurring transactions', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Automate salary, rent, subscriptions', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final isDue = item.isDue;
              final isIncome = item.type == 'income';
              final color = isIncome ? Colors.green : Colors.red;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.12),
                    child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: color, size: 18),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(item.note.isNotEmpty ? item.note : item.category, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (isDue)
                        const Chip(
                          label: Text('Due', style: TextStyle(color: Colors.white, fontSize: 10)),
                          backgroundColor: Colors.orange,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${item.frequencyLabel} · Next: ${DateFormat('dd MMM').format(item.nextDueDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}₹${_fmt(item.amount)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.bold),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AddRecurringScreen(recurring: item)))
                                .then((_) => ref.invalidate(recurringProvider));
                          }
                          if (v == 'delete') {
                            await ref.read(recurringProvider.notifier).delete(item.id!);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
