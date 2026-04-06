import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/investment_model.dart';
import '../../core/providers/app_providers.dart';

class AddInvestmentScreen extends ConsumerStatefulWidget {
  final Investment? investment;
  const AddInvestmentScreen({super.key, this.investment});

  @override
  ConsumerState<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends ConsumerState<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _buyPriceCtrl = TextEditingController();
  final _currentPriceCtrl = TextEditingController();
  final _annualRateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _type = 'Stock';
  DateTime _buyDate = DateTime.now();
  bool _saving = false;

  bool get _isFixedIncome => Investment.fixedIncomeTypes.contains(_type);

  @override
  void initState() {
    super.initState();
    final inv = widget.investment;
    if (inv != null) {
      _nameCtrl.text = inv.name;
      _symbolCtrl.text = inv.symbol ?? '';
      _qtyCtrl.text = inv.quantity.toString();
      _buyPriceCtrl.text = inv.buyPrice.toString();
      _currentPriceCtrl.text = inv.currentPrice.toString();
      _annualRateCtrl.text = inv.annualRate > 0 ? inv.annualRate.toString() : '';
      _notesCtrl.text = inv.notes;
      _type = inv.type;
      _buyDate = inv.buyDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _symbolCtrl.dispose(); _qtyCtrl.dispose();
    _buyPriceCtrl.dispose(); _currentPriceCtrl.dispose();
    _annualRateCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final annualRate = double.tryParse(_annualRateCtrl.text) ?? 0;
    final inv = Investment(
      id: widget.investment?.id,
      name: _nameCtrl.text.trim(),
      type: _type,
      symbol: _symbolCtrl.text.isNotEmpty ? _symbolCtrl.text.trim() : null,
      quantity: double.parse(_qtyCtrl.text),
      buyPrice: double.parse(_buyPriceCtrl.text),
      currentPrice: double.parse(_currentPriceCtrl.text),
      annualRate: annualRate,
      buyDate: _buyDate,
      notes: _notesCtrl.text.trim(),
    );
    if (widget.investment == null) {
      await ref.read(investmentsProvider.notifier).add(inv);
    } else {
      await ref.read(investmentsProvider.notifier).edit(inv.id!, inv.toMap()..remove('id'));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.investment == null ? 'Add Investment' : 'Edit Investment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: Investment.types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _type = v!),
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _symbolCtrl,
              decoration: const InputDecoration(labelText: 'Symbol / Ticker (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity / Units', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _buyPriceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Buy Price ₹', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (_isFixedIncome) ...[
              TextFormField(
                controller: _annualRateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Annual Interest Rate (% p.a.)',
                  hintText: 'e.g. 7.1 for PPF',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Current value will be auto-calculated using compound interest based on rate and buy date.',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
            TextFormField(
              controller: _currentPriceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _isFixedIncome ? 'Current Price ₹ (manual override)' : 'Current Price ₹',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Buy / Start Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_buyDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _buyDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _buyDate = d);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: _saving
                  ? const CircularProgressIndicator()
                  : Text(widget.investment == null ? 'Add Investment' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
