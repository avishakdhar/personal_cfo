import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/database/database_helper.dart';
import 'core/providers/app_providers.dart';
import 'core/services/notification_service.dart';
import 'features/auth/pin_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Initialize notifications
  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification init error: $e');
  }

  // Process recurring transactions on each app launch
  try {
    final processed = await DatabaseHelper.instance.processDueRecurring();
    if (processed > 0) {
      debugPrint('Auto-processed $processed recurring transactions');
      await NotificationService.instance.showRecurringProcessed(processed);
    }
  } catch (e) {
    debugPrint('Recurring processing error: $e');
  }

  // Check budget alerts and EMI reminders
  try {
    await NotificationService.instance.checkAndNotifyBudgets();
    await NotificationService.instance.checkEmiReminders();
  } catch (e) {
    debugPrint('Notification check error: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const PersonalCFOApp(),
    ),
  );
}

class PersonalCFOApp extends ConsumerWidget {
  const PersonalCFOApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(darkModeProvider);
    return MaterialApp(
      title: 'Personal CFO',
      debugShowCheckedModeBanner: false,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      home: const AppGate(),
    );
  }
}

class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnboarded = ref.watch(isOnboardedProvider);
    final pinEnabled = ref.watch(pinEnabledProvider);
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    if (!isOnboarded) return const OnboardingScreen();
    if (pinEnabled && !isAuthenticated) return const PinLockScreen();
    return const NavigationScreen();
  }
}
