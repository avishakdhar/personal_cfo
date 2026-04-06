import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/app_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final double? prefillAmount;
  final String? prefillCategory;
  final String? prefillNote;

  const AddExpenseScreen({
    super.key,
    this.prefillAmount,
    this.prefillCategory,
    this.prefillNote,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _unitsCtrl = TextEditingController();
  String _category = 'Food';
  int? _selectedAccountId;
  int? _linkedDebtId;
  int? _linkedInvestmentId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillAmount != null) {
      _amountCtrl.text = widget.prefillAmount!.toStringAsFixed(2);
    }
    if (widget.prefillNote != null) _noteCtrl.text = widget.prefillNote!;
    if (widget.prefillCategory != null) _category = widget.prefillCategory!;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _unitsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an account')),
      );
      return;
    }
    if (_category == 'Debt Repayment' && _linkedDebtId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select which liability to repay')),
      );
      return;
    }
    if (_category == 'Investment' && _linkedInvestmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select which investment to top up')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final amount = double.parse(_amountCtrl.text);
      await ref.read(transactionsProvider.notifier).addExpense(
            amount: amount,
            fromAccountId: _selectedAccountId!,
            category: _category,
            note: _noteCtrl.text,
          );
      if (_linkedDebtId != null) {
        await DatabaseHelper.instance.reduceDebtOutstanding(_linkedDebtId!, amount);
        ref.invalidate(debtsProvider);
        ref.invalidate(dashboardProvider);
      }
      if (_linkedInvestmentId != null) {
        final units = double.tryParse(_unitsCtrl.text) ?? 0;
        final pricePerUnit = units > 0 ? amount / units : amount;
        await ref.read(investmentsProvider.notifier).topUp(_linkedInvestmentId!, units > 0 ? units : 1, pricePerUnit);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (accounts) => DropdownButtonFormField<int>(
                initialValue: _selectedAccountId,
                items: accounts
                    .map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAccountId = v),
                decoration: const InputDecoration(
                  labelText: 'Pay From',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null ? 'Select account' : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: categoriesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (categories) {
                      final expenseCategories = categories
                          .where((c) => c.type == 'expense')
                          .map((c) => c.name)
                          .toSet()
                          .toList();
                      if (expenseCategories.isEmpty) expenseCategories.add('Food');

                      if (!expenseCategories.contains(_category)) {
                        _category = expenseCategories.first;
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: _category,
                        items: expenseCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _category = v!;
                          _linkedDebtId = null;
                          _linkedInvestmentId = null;
                        }),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            // ── Debt Repayment linking ──────────────────────────────────────
            if (_category == 'Debt Repayment') ...[
              const SizedBox(height: 16),
              ref.watch(debtsProvider).when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (debts) {
                  final active = debts.where((d) => !d.isFullyPaid).toList();
                  return InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Repay which liability?',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _linkedDebtId,
                        isDense: true,
                        hint: const Text('Select liability'),
                        items: active
                            .map((d) => DropdownMenuItem<int>(
                                  value: d.id,
                                  child: Text('${d.name} (₹${NumberFormat('#,##,##0.##', 'en_IN').format(d.outstanding)} left)'),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _linkedDebtId = v),
                      ),
                    ),
                  );
                },
              ),
            ],
            // ── Investment top-up linking ───────────────────────────────────
            if (_category == 'Investment') ...[
              const SizedBox(height: 16),
              ref.watch(investmentsProvider).when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (investments) => InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Top up which investment?',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _linkedInvestmentId,
                      isDense: true,
                      hint: const Text('Select investment'),
                      items: investments
                          .map((inv) => DropdownMenuItem<int>(
                                value: inv.id,
                                child: Text('${inv.name} (${inv.type})'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _linkedInvestmentId = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitsCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Units purchased (optional)',
                  hintText: 'Leave blank to treat full amount as 1 unit',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'The expense amount will be deducted from your account. Units will be added to the selected investment.',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (used for AI categorization)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
