import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import 'edit_transaction_screen.dart';

class TransactionHistoryScreen extends ConsumerWidget {
  const TransactionHistoryScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction History')),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('No transactions'));
          }
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, i) {
              final tx = transactions[i];
              final isIncome = tx.isIncome;
              final isTransfer = tx.isTransfer;
              final color = isIncome ? Colors.green : (isTransfer ? Colors.blue : Colors.red);
              final prefix = isIncome ? '+' : (isTransfer ? '' : '-');
              final icon = isIncome
                  ? Icons.arrow_downward
                  : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withAlpha(31),
                  child: Icon(icon, color: color, size: 18),
                ),
                title: Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${tx.note.isNotEmpty ? tx.note : '—'} · ${DateFormat('dd MMM yyyy, HH:mm').format(tx.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  '$prefix₹${_fmt(tx.amount)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => EditTransactionScreen(transaction: tx)),
                ).then((_) => ref.invalidate(transactionsProvider)),
              );
            },
          );
        },
      ),
    );
  }
}
