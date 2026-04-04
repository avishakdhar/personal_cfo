import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/app_providers.dart';

class AiInsightsScreen extends ConsumerStatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  ConsumerState<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends ConsumerState<AiInsightsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(apiKeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Insights'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Insights'),
            Tab(text: 'Anomalies'),
            Tab(text: 'Subscriptions'),
            Tab(text: 'Forecast'),
          ],
        ),
      ),
      body: apiKey.isEmpty
          ? _NoApiKeyBanner()
          : TabBarView(
              controller: _tabCtrl,
              children: const [
                _InsightsTab(),
                _AnomaliesTab(),
                _SubscriptionsTab(),
                _ForecastTab(),
              ],
            ),
    );
  }
}

// ─── No API Key Banner ────────────────────────────────────────────────────────

class _NoApiKeyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.smart_toy_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 20),
            const Text(
              'AI Insights Unavailable',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Set your Claude API key in Settings to unlock AI-powered spending insights, anomaly detection, subscription tracking, and cash flow forecasts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Go to Settings'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Insights Tab ─────────────────────────────────────────────────────────────

class _InsightsTab extends ConsumerStatefulWidget {
  const _InsightsTab();

  @override
  ConsumerState<_InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends ConsumerState<_InsightsTab> {
  String? _insights;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final db = DatabaseHelper.instance;
      final categorySpending = await db.getCategorySpending(month: now.month, year: now.year);
      final totalSpend = await db.getTotalSpending(month: now.month, year: now.year);

      // Get income this month
      final txs = await db.getTransactions(type: 'income', startDate: DateTime(now.year, now.month, 1));
      final totalIncome = txs.fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

      // Get budgets
      final budgets = await db.getBudgets(month: now.month, year: now.year);
      final budgetMap = { for (final b in budgets) b['category'] as String: (b['amount_limit'] as num).toDouble() };

      final ai = ref.read(aiServiceProvider);
      final result = await ai.generateInsights(
        categorySpending: categorySpending,
        totalSpending: totalSpend,
        totalIncome: totalIncome,
        budgets: budgetMap,
      );
      if (mounted) setState(() { _insights = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(error: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InsightHeader(
              icon: Icons.lightbulb_outline,
              title: 'This Month\'s Insights',
              subtitle: 'AI-generated analysis of your spending patterns',
            ),
            const SizedBox(height: 16),
            if (_insights != null)
              _InsightCard(content: _insights!),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Insights'),
                onPressed: _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Anomalies Tab ────────────────────────────────────────────────────────────

class _AnomaliesTab extends ConsumerStatefulWidget {
  const _AnomaliesTab();

  @override
  ConsumerState<_AnomaliesTab> createState() => _AnomaliesTabState();
}

class _AnomaliesTabState extends ConsumerState<_AnomaliesTab> {
  List<String>? _anomalies;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final now = DateTime.now();
      final db = DatabaseHelper.instance;

      final currentSpending = await db.getCategorySpending(month: now.month, year: now.year);

      // Build 3-month average for comparison
      final avgSpending = <String, double>{};
      int monthCount = 0;
      for (int i = 1; i <= 3; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthly = await db.getCategorySpending(month: date.month, year: date.year);
        for (final e in monthly.entries) {
          avgSpending[e.key] = (avgSpending[e.key] ?? 0) + e.value;
        }
        monthCount++;
      }
      if (monthCount > 0) {
        avgSpending.updateAll((key, value) => value / monthCount);
      }

      final ai = ref.read(aiServiceProvider);
      final result = await ai.detectAnomalies(
        currentMonthSpending: currentSpending,
        avgMonthlySpending: avgSpending,
      );
      if (mounted) setState(() { _anomalies = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(error: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InsightHeader(
              icon: Icons.warning_amber_outlined,
              title: 'Spending Anomalies',
              subtitle: 'Categories with unusual spending vs your 3-month average',
            ),
            const SizedBox(height: 16),
            if (_anomalies == null || _anomalies!.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('No Anomalies Detected',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('Your spending is consistent with recent months.',
                                style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...(_anomalies!.map((a) => _AnomalyTile(text: a))),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Re-analyze'),
                onPressed: _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Subscriptions Tab ────────────────────────────────────────────────────────

class _SubscriptionsTab extends ConsumerStatefulWidget {
  const _SubscriptionsTab();

  @override
  ConsumerState<_SubscriptionsTab> createState() => _SubscriptionsTabState();
}

class _SubscriptionsTabState extends ConsumerState<_SubscriptionsTab> {
  List<String>? _subscriptions;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final txs = await DatabaseHelper.instance.getTransactions(type: 'expense', limit: 100);
      final ai = ref.read(aiServiceProvider);
      final result = await ai.detectSubscriptions(txs);
      if (mounted) setState(() { _subscriptions = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(error: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InsightHeader(
              icon: Icons.repeat_outlined,
              title: 'Detected Subscriptions',
              subtitle: 'Recurring charges identified from your last 100 transactions',
            ),
            const SizedBox(height: 16),
            if (_subscriptions == null || _subscriptions!.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No recurring subscriptions detected in recent transactions.'),
                ),
              )
            else
              ...(_subscriptions!.map((s) => _SubscriptionTile(text: s))),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Re-scan'),
                onPressed: _load,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Forecast Tab ─────────────────────────────────────────────────────────────

class _ForecastTab extends ConsumerStatefulWidget {
  const _ForecastTab();

  @override
  ConsumerState<_ForecastTab> createState() => _ForecastTabState();
}

class _ForecastTabState extends ConsumerState<_ForecastTab> {
  String? _forecast;
  Map<String, double>? _suggestedBudgets;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final db = DatabaseHelper.instance;
      final accounts = await db.getAccounts();
      final currentBalance = accounts.fold(0.0, (s, a) => s + (a['balance'] as num).toDouble());
      final history = await db.getMonthlySpendingHistory(months: 6);

      // Build avg spending for budget suggestions
      final now = DateTime.now();
      final avgSpending = <String, double>{};
      for (int i = 1; i <= 3; i++) {
        final date = DateTime(now.year, now.month - i, 1);
        final monthly = await db.getCategorySpending(month: date.month, year: date.year);
        for (final e in monthly.entries) {
          avgSpending[e.key] = (avgSpending[e.key] ?? 0) + e.value / 3;
        }
      }

      final ai = ref.read(aiServiceProvider);
      final results = await Future.wait([
        ai.predictCashFlow(monthlyHistory: history, currentBalance: currentBalance),
        ai.suggestBudgets(avgSpending),
      ]);

      if (mounted) {
        setState(() {
          _forecast = results[0] as String;
          _suggestedBudgets = results[1] as Map<String, double>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(error: _error!, onRetry: _load);

    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InsightHeader(
              icon: Icons.trending_up_outlined,
              title: 'Cash Flow Forecast',
              subtitle: 'Next month prediction based on spending history',
            ),
            const SizedBox(height: 12),
            if (_forecast != null) _InsightCard(content: _forecast!),

            const SizedBox(height: 20),
            _InsightHeader(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Suggested Budgets',
              subtitle: 'AI-recommended limits to help you save more',
            ),
            const SizedBox(height: 12),
            if (_suggestedBudgets != null && _suggestedBudgets!.isNotEmpty)
              Card(
                child: Column(
                  children: _suggestedBudgets!.entries.map((e) => ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(e.key),
                    trailing: Text(
                      '₹${fmt.format(e.value)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  )).toList(),
                ),
              ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Forecast'),
                onPressed: _load,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Shared UI Helpers ────────────────────────────────────────────────────────

class _InsightHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InsightHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: cs.outline)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String content;
  const _InsightCard({required this.content});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(content, style: const TextStyle(height: 1.5)),
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final String text;
  const _AnomalyTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withAlpha(20),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: Colors.orange),
        title: Text(text),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final String text;
  const _SubscriptionTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.repeat, color: Theme.of(context).colorScheme.primary),
        title: Text(text),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
