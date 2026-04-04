import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _noteCtrl;
  late String _category;
  late DateTime _date;
  int? _selectedAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _amountCtrl = TextEditingController(text: tx.amount.toString());
    _noteCtrl = TextEditingController(text: tx.note);
    _category = tx.category;
    _date = tx.date;
    _selectedAccountId = tx.isIncome ? tx.toAccount : tx.fromAccount;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            picked.year, picked.month, picked.day,
            _date.hour, _date.minute,
          ));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final tx = widget.transaction;
      final newAmount = double.parse(_amountCtrl.text.trim());
      final oldAccountId = tx.isIncome ? tx.toAccount : tx.fromAccount;

      if (tx.isTransfer) {
        // For transfers, only allow note/category/date edits (no account/amount change)
        await DatabaseHelper.instance.updateTransaction(tx.id!, {
          'note': _noteCtrl.text,
          'category': _category,
          'date': _date.toIso8601String(),
        });
      } else {
        await DatabaseHelper.instance.updateTransactionFull(
          id: tx.id!,
          type: tx.type,
          oldAmount: tx.amount,
          oldAccountId: oldAccountId,
          newAmount: newAmount,
          newAccountId: _selectedAccountId,
          newDate: _date.toIso8601String(),
          newCategory: _category,
          newNote: _noteCtrl.text,
        );
      }

      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(budgetSpentProvider);
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
    final tx = widget.transaction;
    final categories = tx.isIncome
        ? TransactionModel.incomeCategories
        : TransactionModel.expenseCategories;
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Type chip (read-only indicator)
            Chip(
              label: Text(tx.type.toUpperCase()),
              backgroundColor: tx.isIncome
                  ? Colors.green.withAlpha(30)
                  : (tx.isTransfer ? Colors.blue.withAlpha(30) : Colors.red.withAlpha(30)),
            ),
            const SizedBox(height: 16),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              enabled: !tx.isTransfer,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 16),

            // Account (not editable for transfers)
            if (!tx.isTransfer)
              accountsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (accounts) => InputDecorator(
                  decoration: InputDecoration(
                    labelText: tx.isIncome ? 'To Account' : 'From Account',
                    border: const OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedAccountId,
                      isDense: true,
                      hint: const Text('Select account'),
                      items: accounts
                          .map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedAccountId = v),
                    ),
                  ),
                ),
              ),
            if (!tx.isTransfer) const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => _category = v!,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Note / Remarks
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
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
