import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/goal_model.dart';
import '../../core/providers/app_providers.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  final Goal? goal;
  const AddGoalScreen({super.key, this.goal});

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _iconName = 'star';
  DateTime? _targetDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _nameCtrl.text = g.name;
      _targetCtrl.text = g.targetAmount.toString();
      _descCtrl.text = g.description;
      _iconName = g.iconName;
      _targetDate = g.targetDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final goal = Goal(
      id: widget.goal?.id,
      name: _nameCtrl.text.trim(),
      targetAmount: double.parse(_targetCtrl.text),
      currentAmount: widget.goal?.currentAmount ?? 0,
      targetDate: _targetDate,
      description: _descCtrl.text.trim(),
      iconName: _iconName,
    );
    if (widget.goal == null) {
      await ref.read(goalsProvider.notifier).add(goal);
    } else {
      await ref.read(goalsProvider.notifier).update(goal.id!, goal.toMap()..remove('id'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.goal == null ? 'Add Goal' : 'Edit Goal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Goal Name', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Target Amount', prefixText: '₹ ', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Target Date'),
              subtitle: Text(_targetDate != null ? DateFormat('dd MMM yyyy').format(_targetDate!) : 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (d != null) setState(() => _targetDate = d);
              },
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: Goal.iconOptions.map((icon) {
                final isSelected = _iconName == icon;
                return GestureDetector(
                  onTap: () => setState(() => _iconName = icon),
                  child: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      _getIcon(icon),
                      color: isSelected ? Colors.white : Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving ? const CircularProgressIndicator() : Text(widget.goal == null ? 'Add Goal' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
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
}
