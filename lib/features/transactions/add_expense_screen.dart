import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/transaction_model.dart';
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
  String _category = 'Food';
  int? _selectedAccountId;
  bool _saving = false;
  bool _aiLoading = false;

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
    super.dispose();
  }

  Future<void> _getAiCategory() async {
    if (_noteCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a note first')),
      );
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final ai = ref.read(aiServiceProvider);
      final category = await ai.categorizeTransaction(_noteCtrl.text);
      setState(() => _category = category);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI error: $e')));
      }
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an account')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(transactionsProvider.notifier).addExpense(
            amount: double.parse(_amountCtrl.text),
            fromAccountId: _selectedAccountId!,
            category: _category,
            note: _noteCtrl.text,
          );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                value: _selectedAccountId,
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
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    items: TransactionModel.expenseCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'AI suggest category',
                  child: FilledButton.tonal(
                    onPressed: _aiLoading ? null : _getAiCategory,
                    child: _aiLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.smart_toy_outlined),
                  ),
                ),
              ],
            ),
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
