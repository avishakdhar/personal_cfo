import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/transaction_model.dart';
import '../../core/providers/app_providers.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionModel transaction;
  const EditTransactionScreen({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState
    extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noteCtrl;
  late String _category;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.transaction.note);
    _category = widget.transaction.category;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.updateTransaction(
        widget.transaction.id!,
        {'note': _noteCtrl.text, 'category': _category},
      );
      ref.invalidate(transactionsProvider);
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
    final categories = widget.transaction.isIncome
        ? TransactionModel.incomeCategories
        : TransactionModel.expenseCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                title: const Text('Amount (cannot be changed)'),
                trailing: Text(
                  '₹${widget.transaction.amount}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note',
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
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
