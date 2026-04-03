import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/budget_model.dart';
import '../../core/models/transaction_model.dart';
import '../../core/providers/app_providers.dart';

class AddBudgetScreen extends ConsumerStatefulWidget {
  final Budget? budget;
  const AddBudgetScreen({super.key, this.budget});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _limitCtrl = TextEditingController();
  late String _category;
  String _period = 'monthly';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _category = b?.category ?? TransactionModel.expenseCategories.first;
    _limitCtrl.text = b != null ? b.amountLimit.toString() : '';
    _period = b?.period ?? 'monthly';
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final budget = Budget(
      id: widget.budget?.id,
      category: _category,
      amountLimit: double.parse(_limitCtrl.text),
      period: _period,
      month: now.month,
      year: now.year,
    );
    if (widget.budget == null) {
      await ref.read(budgetsProvider.notifier).add(budget);
    } else {
      await ref.read(budgetsProvider.notifier).update(budget.id!, budget.toMap()..remove('id'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.budget == null ? 'Add Budget' : 'Edit Budget')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            DropdownButtonFormField<String>(
              value: _category,
              items: TransactionModel.expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monthly Limit', prefixText: '₹ ', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _period,
              items: ['monthly', 'weekly'].map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _period = v!),
              decoration: const InputDecoration(labelText: 'Period', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving ? const CircularProgressIndicator() : Text(widget.budget == null ? 'Add Budget' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
