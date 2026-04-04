import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/recurring_transaction_model.dart';
import '../../core/models/transaction_model.dart';
import '../../core/providers/app_providers.dart';

class AddRecurringScreen extends ConsumerStatefulWidget {
  final RecurringTransaction? recurring;
  const AddRecurringScreen({super.key, this.recurring});

  @override
  ConsumerState<AddRecurringScreen> createState() => _AddRecurringScreenState();
}

class _AddRecurringScreenState extends ConsumerState<AddRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _type = 'expense';
  String _category = 'Bills';
  String _frequency = 'monthly';
  DateTime _nextDueDate = DateTime.now().add(const Duration(days: 30));
  int? _fromAccountId;
  int? _toAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recurring;
    if (r != null) {
      _amountCtrl.text = r.amount.toString();
      _noteCtrl.text = r.note;
      _type = r.type;
      _category = r.category;
      _frequency = r.frequency;
      _nextDueDate = r.nextDueDate;
      _fromAccountId = r.fromAccountId;
      _toAccountId = r.toAccountId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final rec = RecurringTransaction(
      id: widget.recurring?.id,
      type: _type,
      amount: double.parse(_amountCtrl.text),
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
      category: _category,
      note: _noteCtrl.text.trim(),
      frequency: _frequency,
      nextDueDate: _nextDueDate,
    );
    if (widget.recurring == null) {
      await ref.read(recurringProvider.notifier).add(rec);
    } else {
      await ref.read(recurringProvider.notifier).edit(rec.id!, rec.toMap()..remove('id'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categories = _type == 'income'
        ? TransactionModel.incomeCategories
        : TransactionModel.expenseCategories;

    return Scaffold(
      appBar: AppBar(title: Text(widget.recurring == null ? 'Add Recurring' : 'Edit Recurring')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (accounts) => Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('Income'), icon: Icon(Icons.arrow_downward, size: 16)),
                  ButtonSegment(value: 'expense', label: Text('Expense'), icon: Icon(Icons.arrow_upward, size: 16)),
                ],
                selected: {_type},
                onSelectionChanged: (v) => setState(() {
                  _type = v.first;
                  _category = _type == 'income' ? 'Salary' : 'Bills';
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              if (_type == 'expense')
                DropdownButtonFormField<int>(
                  initialValue: _fromAccountId,
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _fromAccountId = v),
                  decoration: const InputDecoration(labelText: 'Pay From', border: OutlineInputBorder()),
                )
              else
                DropdownButtonFormField<int>(
                  initialValue: _toAccountId,
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (v) => setState(() => _toAccountId = v),
                  decoration: const InputDecoration(labelText: 'Deposit To', border: OutlineInputBorder()),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _category = v!),
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _frequency,
                items: RecurringTransaction.frequencies
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _frequency = v!),
                decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Label / Note', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next Due Date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_nextDueDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _nextDueDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (d != null) setState(() => _nextDueDate = d);
                },
              ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                child: _saving ? const CircularProgressIndicator() : Text(widget.recurring == null ? 'Add Recurring' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
