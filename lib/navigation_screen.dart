import 'package:flutter/material.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/budgets/budgets_screen.dart';
import 'features/ai/ai_chat_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/investments/investments_screen.dart';
import 'features/debts/debts_screen.dart';
import 'features/debts/debt_calculator_screen.dart';
import 'features/recurring/recurring_screen.dart';
import 'features/ai/ai_insights_screen.dart';
import 'features/ai/receipt_scan_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/settings/settings_screen.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const AccountsScreen(),
    const TransactionsScreen(),
    const BudgetsScreen(),
    const AiChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      drawer: _buildDrawer(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Budgets'),
          NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text('Personal CFO', style: TextStyle(color: colorScheme.onPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Your AI Finance Manager', style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.8), fontSize: 13)),
              ],
            ),
          ),
          _drawerTile(Icons.flag_outlined, 'Goals', () => _push(const GoalsScreen())),
          _drawerTile(Icons.trending_up_outlined, 'Investments', () => _push(const InvestmentsScreen())),
          _drawerTile(Icons.credit_card_outlined, 'Debts & Loans', () => _push(const DebtsScreen())),
          _drawerTile(Icons.calculate_outlined, 'Debt Calculator', () => _push(const DebtCalculatorScreen())),
          _drawerTile(Icons.repeat_outlined, 'Recurring', () => _push(const RecurringScreen())),
          const Divider(),
          _drawerTile(Icons.document_scanner_outlined, 'Scan Receipt', () => _push(const ReceiptScanScreen())),
          _drawerTile(Icons.insights_outlined, 'AI Insights', () => _push(const AiInsightsScreen())),
          _drawerTile(Icons.bar_chart_outlined, 'Reports', () => _push(const ReportsScreen())),
          const Divider(),
          _drawerTile(Icons.settings_outlined, 'Settings', () => _push(const SettingsScreen())),
        ],
      ),
    );
  }

  ListTile _drawerTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context); // close drawer
        onTap();
      },
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}
