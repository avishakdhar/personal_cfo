import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/app_providers.dart';

/// SIP (Systematic Investment Plan) entry screen.
/// Each SIP installment is recorded as an individual investment entry.
class AddSipScreen extends ConsumerStatefulWidget {
  const AddSipScreen({super.key});

  @override
  ConsumerState<AddSipScreen> createState() => _AddSipScreenState();
}

class _AddSipScreenState extends ConsumerState<AddSipScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sipAmountCtrl = TextEditingController();
  final _navCtrl = TextEditingController();
  final _symbolCtrl = TextEditingController();
  DateTime _sipDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sipAmountCtrl.dispose();
    _navCtrl.dispose();
    _symbolCtrl.dispose();
    super.dispose();
  }

  /// Calculate units purchased: SIP Amount / NAV
  double get _units {
    final amount = double.tryParse(_sipAmountCtrl.text) ?? 0;
    final nav = double.tryParse(_navCtrl.text) ?? 0;
    return nav > 0 ? amount / nav : 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final sipAmount = double.parse(_sipAmountCtrl.text);
      final nav = double.parse(_navCtrl.text);
      final units = sipAmount / nav;

      await DatabaseHelper.instance.insertInvestment({
        'name': '${_nameCtrl.text.trim()} (SIP)',
        'type': 'Mutual Fund',
        'symbol': _symbolCtrl.text.trim().isEmpty ? null : _symbolCtrl.text.trim(),
        'quantity': units,
        'buy_price': nav,
        'current_price': nav,
        'buy_date': _sipDate.toIso8601String(),
        'notes': 'SIP installment — ₹${sipAmount.toStringAsFixed(0)} at NAV ₹${nav.toStringAsFixed(2)}',
        'created_at': DateTime.now().toIso8601String(),
      });

      ref.invalidate(investmentsProvider);
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
    final fmt = NumberFormat('#,##,##0.###', 'en_IN');

    return Scaffold(
      appBar: AppBar(title: const Text('Add SIP Installment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Each SIP installment is tracked separately. Units = SIP Amount ÷ NAV.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Fund Name',
                hintText: 'e.g. Parag Parikh Flexicap',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _symbolCtrl,
              decoration: const InputDecoration(
                labelText: 'Fund Symbol / ISIN (optional)',
                hintText: 'e.g. INF761K01EG3',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sipAmountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'SIP Amount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if ((double.tryParse(v) ?? 0) <= 0) return 'Enter valid amount';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _navCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'NAV (Price)',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if ((double.tryParse(v) ?? 0) <= 0) return 'Enter valid NAV';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),

            if (_units > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Units to be allotted: ${fmt.format(_units)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 14),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Investment Date'),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_sipDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _sipDate,
                  firstDate: DateTime(2010),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _sipDate = picked);
              },
            ),

            const SizedBox(height: 28),

            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add),
              label: Text(_saving ? 'Saving...' : 'Add SIP Installment'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
