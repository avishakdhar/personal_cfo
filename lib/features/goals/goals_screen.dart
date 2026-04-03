import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/goal_model.dart';
import '../../core/providers/app_providers.dart';
import 'add_goal_screen.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Goal'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalScreen()))
            .then((_) => ref.invalidate(goalsProvider)),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No goals yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Set a savings target to track your progress', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: goals.length,
            itemBuilder: (context, i) => _GoalCard(
              goal: goals[i],
              onContribute: () => _showContribute(context, ref, goals[i]),
              onEdit: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AddGoalScreen(goal: goals[i])))
                .then((_) => ref.invalidate(goalsProvider)),
              onDelete: () => ref.read(goalsProvider.notifier).delete(goals[i].id!),
            ),
          );
        },
      ),
    );
  }

  void _showContribute(BuildContext context, WidgetRef ref, Goal goal) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add to "${goal.name}"'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null || amount <= 0) return;
              await ref.read(goalsProvider.notifier).contribute(goal.id!, amount);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onContribute;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({required this.goal, required this.onContribute, required this.onEdit, required this.onDelete});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  IconData get _icon {
    switch (goal.iconName) {
      case 'home': return Icons.home;
      case 'directions_car': return Icons.directions_car;
      case 'flight': return Icons.flight;
      case 'school': return Icons.school;
      case 'favorite': return Icons.favorite;
      case 'savings': return Icons.savings;
      case 'computer': return Icons.computer;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'medical_services': return Icons.medical_services;
      default: return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = goal.isCompleted ? Colors.green : Theme.of(context).colorScheme.primary;
    final daysLeft = goal.targetDate != null ? goal.targetDate!.difference(DateTime.now()).inDays : null;

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
                  backgroundColor: progressColor.withOpacity(0.15),
                  child: Icon(_icon, color: progressColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      if (goal.description.isNotEmpty)
                        Text(goal.description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (goal.isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${_fmt(goal.currentAmount)} / ₹${_fmt(goal.targetAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('${(goal.progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(color: progressColor, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (daysLeft != null)
                  Text(
                    daysLeft > 0 ? '$daysLeft days left' : 'Overdue',
                    style: TextStyle(fontSize: 12, color: daysLeft < 0 ? Colors.red : Colors.grey),
                  )
                else
                  const SizedBox(),
                if (!goal.isCompleted)
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Contribute'),
                    onPressed: onContribute,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
