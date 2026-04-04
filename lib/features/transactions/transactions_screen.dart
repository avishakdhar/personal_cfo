import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/transaction_model.dart';
import '../../core/providers/app_providers.dart';
import '../ai/receipt_scan_screen.dart';
import 'add_expense_screen.dart';
import 'add_income_screen.dart';
import 'edit_transaction_screen.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _showSearch = false;

  final _tabs = ['All', 'Expense', 'Income', 'Transfer'];
  DateTime? _filterStart;
  DateTime? _filterEnd;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _updateFilter();
    });
  }

  void _updateFilter() {
    final type =
        _tabCtrl.index == 0 ? null : _tabs[_tabCtrl.index].toLowerCase();
    ref.read(transactionFilterProvider.notifier).state = TransactionFilter(
      type: type,
      searchQuery: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      startDate: _filterStart,
      endDate: _filterEnd,
    );
    // transactionsProvider watches transactionFilterProvider, so it rebuilds
    // automatically. Do NOT also call ref.invalidate() here — that causes a
    // second rebuild which can race with the first and show stale data.
  }

  Future<void> _showDateFilter() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterStart != null && _filterEnd != null
          ? DateTimeRange(start: _filterStart!, end: _filterEnd!)
          : null,
      helpText: 'Filter by Date Range',
    );
    if (range != null) {
      setState(() {
        _filterStart = range.start;
        _filterEnd = range.end.add(const Duration(hours: 23, minutes: 59));
      });
      _updateFilter();
    }
  }

  void _clearDateFilter() {
    setState(() { _filterStart = null; _filterEnd = null; });
    _updateFilter();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => _updateFilter(),
              )
            : const Text('Transactions'),
        actions: _showSearch
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() { _showSearch = false; _searchCtrl.clear(); });
                    _updateFilter();
                  },
                ),
              ]
            : [
                if (_filterStart != null)
                  IconButton(
                    icon: const Icon(Icons.filter_alt_off),
                    tooltip: 'Clear date filter',
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _clearDateFilter,
                  ),
                IconButton(
                  icon: const Icon(Icons.date_range_outlined),
                  tooltip: 'Filter by date range',
                  onPressed: _showDateFilter,
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => setState(() => _showSearch = true),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (v) {
                    if (v == 'scan') {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ReceiptScanScreen())).then((_) {
                        ref.invalidate(transactionsProvider);
                        ref.invalidate(accountsProvider);
                        ref.invalidate(dashboardProvider);
                      });
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'scan', child: Text('Scan Receipt')),
                  ],
                ),
              ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'income',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddIncomeScreen()),
            ).then((_) {
              ref.invalidate(transactionsProvider);
              ref.invalidate(accountsProvider);
              ref.invalidate(dashboardProvider);
            }),
            child: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'expense',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
            ).then((_) {
              ref.invalidate(transactionsProvider);
              ref.invalidate(accountsProvider);
              ref.invalidate(dashboardProvider);
            }),
            child: const Icon(Icons.remove_circle_outline),
          ),
        ],
      ),
      body: txAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (txs) {
          if (txs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No transactions', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: txs.length,
            itemBuilder: (context, i) => _TxTile(
              tx: txs[i],
              onDelete: () => _delete(txs[i]),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditTransactionScreen(transaction: txs[i]),
                ),
              ).then((_) {
                ref.invalidate(transactionsProvider);
                ref.invalidate(accountsProvider);
              }),
            ),
          );
        },
      ),
    );
  }

  Future<void> _delete(TransactionModel tx) async {
    await ref.read(transactionsProvider.notifier).softDelete(tx.id!);
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

class _TxTile extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TxTile({
    required this.tx,
    required this.onDelete,
    required this.onEdit,
  });

  String _fmt(double v) => NumberFormat('#,##,##0.##', 'en_IN').format(v);

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final isTransfer = tx.isTransfer;
    final color =
        isIncome ? Colors.green : (isTransfer ? Colors.blue : Colors.red);
    final prefix = isIncome ? '+' : (isTransfer ? '⇄' : '-');
    final date = DateFormat('dd MMM, HH:mm').format(tx.date);

    return Dismissible(
      key: Key('tx_${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('This will reverse the balance change.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(31),
          child: Icon(
            isIncome
                ? Icons.arrow_downward
                : (isTransfer ? Icons.swap_horiz : Icons.arrow_upward),
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          tx.category,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${tx.note.isNotEmpty ? tx.note : "—"} · $date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$prefix ₹${_fmt(tx.amount)}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 15,
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
