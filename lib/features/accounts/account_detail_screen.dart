import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/account_model.dart';
import '../../core/models/transaction_model.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  final Account account;
  const AccountDetailScreen({super.key, required this.account});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  List<TransactionModel> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final maps = await DatabaseHelper.instance.getTransactions(accountId: widget.account.id);
    if (mounted) {
      setState(() {
        _transactions = maps.map(TransactionModel.fromMap).toList();
        _loading = false;
      });
    }
  }

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final cs = Theme.of(context).colorScheme;
    final isNegative = account.balance < 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(account.name),
            Text('${account.type} · ${account.currency}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Balance header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isNegative ? Colors.red.withAlpha(20) : cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Balance', style: TextStyle(color: cs.onSurface.withAlpha(150), fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  '₹${_fmt(account.balance)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isNegative ? Colors.red : cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),

          // Transaction list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('No transactions for this account', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _transactions.length,
                          itemBuilder: (context, i) => _LedgerTile(tx: _transactions[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final TransactionModel tx;
  const _LedgerTile({required this.tx});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final isTransfer = tx.isTransfer;
    final color = isIncome ? Colors.green : (isTransfer ? Colors.blue : Colors.red);
    final prefix = isIncome ? '+' : (isTransfer ? '⇄' : '-');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(
          isIncome ? Icons.arrow_downward : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward),
          color: color,
          size: 18,
        ),
      ),
      title: Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${tx.note.isNotEmpty ? tx.note : "—"} · ${DateFormat("dd MMM, HH:mm").format(tx.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '$prefix ₹${_fmt(tx.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
