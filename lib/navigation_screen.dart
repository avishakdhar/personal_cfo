import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _screens[_selectedIndex],
      ),
      drawer: _buildDrawer(),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(size: 26, color: Theme.of(context).colorScheme.primary);
            }
            return const IconThemeData(size: 24, color: Colors.grey);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 64, // Sleeker height
          elevation: 0,
          backgroundColor: Theme.of(context).colorScheme.surface,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance_rounded), label: 'Accounts'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Activity'),
            NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded), label: 'Budgets'),
            NavigationDestination(icon: Icon(Icons.smart_toy_outlined), selectedIcon: Icon(Icons.smart_toy_rounded), label: 'Assistant'),
          ],
        ),
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
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withAlpha(200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 12),
                Text('FinPilot.ai', style: TextStyle(color: colorScheme.onPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                Text('Your AI Finance Manager', style: TextStyle(color: colorScheme.onPrimary.withAlpha(204), fontSize: 13)),
              ],
            ),
          ),
          ...[
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
          ].animate(interval: 50.ms).fade().slideX(begin: -0.1),
        ],
      ),
    );
  }

  ListTile _drawerTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface.withAlpha(200), size: 22),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      minLeadingWidth: 24,
      dense: true,
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
