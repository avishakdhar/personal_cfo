import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/debt_model.dart';
import '../../core/providers/app_providers.dart';

class AddDebtScreen extends ConsumerStatefulWidget {
  final Debt? debt;
  const AddDebtScreen({super.key, this.debt});

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _outstandingCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _emiCtrl = TextEditingController();
  final _emiDayCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'Personal Loan';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _nameCtrl.text = d.name;
      _lenderCtrl.text = d.lender;
      _principalCtrl.text = d.principal.toString();
      _outstandingCtrl.text = d.outstanding.toString();
      _interestCtrl.text = d.interestRate.toString();
      _emiCtrl.text = d.emiAmount.toString();
      _emiDayCtrl.text = d.emiDay.toString();
      _notesCtrl.text = d.notes;
      _type = d.type;
      _startDate = d.startDate;
      _endDate = d.endDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _lenderCtrl.dispose(); _principalCtrl.dispose();
    _outstandingCtrl.dispose(); _interestCtrl.dispose(); _emiCtrl.dispose();
    _emiDayCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final debt = Debt(
      id: widget.debt?.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      principal: double.parse(_principalCtrl.text),
      outstanding: double.parse(_outstandingCtrl.text),
      interestRate: double.tryParse(_interestCtrl.text) ?? 0,
      emiAmount: double.tryParse(_emiCtrl.text) ?? 0,
      emiDay: int.tryParse(_emiDayCtrl.text) ?? 1,
      startDate: _startDate,
      endDate: _endDate,
      lender: _lenderCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
    );
    if (widget.debt == null) {
      await ref.read(debtsProvider.notifier).add(debt);
    } else {
      await ref.read(debtsProvider.notifier).update(debt.id!, debt.toMap()..remove('id'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.debt == null ? 'Add Debt / Loan' : 'Edit Debt')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Debt Name', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _type,
              items: Debt.types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _lenderCtrl, decoration: const InputDecoration(labelText: 'Lender / Bank (optional)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _principalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Principal ₹', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _outstandingCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Outstanding ₹', border: OutlineInputBorder()), validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _interestCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Interest Rate % p.a.', border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _emiCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'EMI Amount ₹', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 16),
            TextFormField(controller: _emiDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'EMI Day of Month (1-31)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (d != null) setState(() => _startDate = d);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End Date (optional)'),
              subtitle: Text(_endDate != null ? DateFormat('dd MMM yyyy').format(_endDate!) : 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 30)));
                if (d != null) setState(() => _endDate = d);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving ? const CircularProgressIndicator() : Text(widget.debt == null ? 'Add Debt' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
