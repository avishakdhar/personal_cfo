import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/account_model.dart';
import '../../core/providers/app_providers.dart';
import 'add_account_screen.dart';
import '../transactions/transfer_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Transfer',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransferScreen()))
                .then((_) { ref.invalidate(accountsProvider); ref.invalidate(dashboardProvider); }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Account'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAccountScreen()))
            .then((_) => ref.invalidate(accountsProvider)),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No accounts yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Tap + to add your first account', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final totalBalance = accounts.fold(0.0, (sum, a) => sum + a.balance);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(accountsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Balance', style: TextStyle(fontSize: 13)),
                            Text(
                              '₹${_fmt(totalBalance)}',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...accounts.map((account) => _AccountCard(
                  account: account,
                  onDelete: () => _deleteAccount(context, ref, account),
                  onEdit: () => _editAccount(context, ref, account),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref, Account account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Delete "${account.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(accountsProvider.notifier).delete(account.id!);
    }
  }

  void _editAccount(BuildContext context, WidgetRef ref, Account account) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddAccountScreen(account: account)))
        .then((_) => ref.invalidate(accountsProvider));
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _AccountCard({required this.account, required this.onDelete, required this.onEdit});

  IconData get _icon {
    switch (account.type) {
      case 'Bank': return Icons.account_balance;
      case 'Credit Card': return Icons.credit_card;
      case 'Cash': return Icons.money;
      case 'Wallet': return Icons.account_balance_wallet;
      default: return Icons.savings;
    }
  }

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context) {
    final isNegative = account.balance < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(_icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${account.type} • ${account.currency}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '₹${_fmt(account.balance)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isNegative ? Colors.red : null,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
