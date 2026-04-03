import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/notification_service.dart';
import '../../navigation_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _apiKeyCtrl = TextEditingController();
  bool _showApiKey = false;
  int _currentPage = 0;

  // Info pages (4) + API key setup page (1) = 5 total
  static const int _totalPages = 5;

  final _infoPages = const [
    _OnboardingPage(
      icon: Icons.account_balance_wallet,
      title: 'Track All Accounts',
      body: 'Add bank accounts, cash, credit cards, and wallets. See your complete net worth at a glance.',
      color: Color(0xFF6750A4),
    ),
    _OnboardingPage(
      icon: Icons.savings,
      title: 'Budget & Save',
      body: 'Set monthly budgets per category, track spending progress, and build savings goals with a timeline.',
      color: Color(0xFF00897B),
    ),
    _OnboardingPage(
      icon: Icons.trending_up,
      title: 'Invest & Track Debt',
      body: 'Monitor your stock, mutual fund, and FD portfolio. Track loans and EMI schedules.',
      color: Color(0xFFE65100),
    ),
    _OnboardingPage(
      icon: Icons.smart_toy,
      title: 'AI-Powered Insights',
      body: 'Your personal CFO AI categorizes spending, detects anomalies, forecasts cash flow, and answers financial questions.',
      color: Color(0xFF1565C0),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Save API key if entered
    final key = _apiKeyCtrl.text.trim();
    if (key.isNotEmpty) {
      await ref.read(apiKeyProvider.notifier).setKey(key);
    }

    // Request notification permission
    try {
      await NotificationService.instance.requestPermission();
    } catch (_) {}

    await ref.read(isOnboardedProvider.notifier).complete();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const NavigationScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLastPage = _currentPage == _totalPages - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  ..._infoPages,
                  _ApiKeySetupPage(
                    controller: _apiKeyCtrl,
                    showKey: _showApiKey,
                    onToggleShow: () => setState(() => _showApiKey = !_showApiKey),
                  ),
                ],
              ),
            ),
            // Page indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == _currentPage ? cs.primary : cs.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    child: Text(isLastPage ? 'Get Started' : 'Next'),
                  ),
                  if (isLastPage) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip for now — set up AI later in Settings'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─── API Key Setup Page ───────────────────────────────────────────────────────

class _ApiKeySetupPage extends StatelessWidget {
  final TextEditingController controller;
  final bool showKey;
  final VoidCallback onToggleShow;

  const _ApiKeySetupPage({
    required this.controller,
    required this.showKey,
    required this.onToggleShow,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.key_outlined, size: 50, color: Color(0xFF1565C0)),
          ),
          const SizedBox(height: 28),
          Text(
            'Set Up AI Features',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Enter your Claude API key to enable AI chat, auto-categorization, receipt scanning, and spending insights.',
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.7),
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            obscureText: !showKey,
            decoration: InputDecoration(
              labelText: 'Claude API Key (optional)',
              hintText: 'sk-ant-...',
              helperText: 'Get your free key at console.anthropic.com',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(showKey ? Icons.visibility_off : Icons.visibility),
                onPressed: onToggleShow,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, color: cs.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your key is stored locally on your device only. '
                    'It\'s never shared with anyone except Anthropic\'s servers for AI queries.',
                    style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info Page ────────────────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
