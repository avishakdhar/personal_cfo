import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database_helper.dart';

/// Handles all local push notifications for budget alerts, bill reminders, etc.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification channel IDs
  static const String _budgetChannelId = 'budget_alerts';
  static const String _reminderChannelId = 'reminders';
  static const String _insightChannelId = 'insights';

  // Notification IDs
  static const int _budgetBaseId = 1000;
  static const int _billReminderId = 2000;
  static const int _weeklyInsightId = 3000;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    await _createChannels();
    _initialized = true;
  }

  Future<void> _createChannels() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _budgetChannelId,
        'Budget Alerts',
        description: 'Alerts when you are close to or over your budget limits',
        importance: Importance.high,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        'Reminders',
        description: 'EMI due dates and bill payment reminders',
        importance: Importance.defaultImportance,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _insightChannelId,
        'Financial Insights',
        description: 'Weekly spending summaries and tips',
        importance: Importance.low,
      ),
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    // Navigation can be wired up here if needed
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permission on Android 13+
  Future<bool> requestPermission() async {
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // ─── Budget Alerts ────────────────────────────────────────────────────────

  /// Show a budget alert for a specific category.
  Future<void> showBudgetAlert({
    required String category,
    required double spent,
    required double limit,
  }) async {
    if (!_initialized) await initialize();

    final pct = (spent / limit * 100).toStringAsFixed(0);
    final isOver = spent > limit;

    await _plugin.show(
      _budgetBaseId + category.hashCode.abs() % 900,
      isOver ? '🚨 Budget Exceeded: $category' : '⚠️ Budget Warning: $category',
      isOver
          ? 'You\'ve spent ₹${spent.toStringAsFixed(0)} — ₹${(spent - limit).toStringAsFixed(0)} over your ₹${limit.toStringAsFixed(0)} limit'
          : 'You\'ve used $pct% of your ₹${limit.toStringAsFixed(0)} $category budget',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _budgetChannelId,
          'Budget Alerts',
          channelDescription: 'Budget limit alerts',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: isOver ? const Color(0xFFE53935) : const Color(0xFFFB8C00),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
      payload: 'budget:$category',
    );
  }

  /// Check all budgets and notify for any that are >= 80% spent.
  Future<void> checkAndNotifyBudgets() async {
    if (!_initialized) await initialize();

    final now = DateTime.now();
    final db = DatabaseHelper.instance;
    final budgets = await db.getBudgets(month: now.month, year: now.year);

    for (final budget in budgets) {
      final category = budget['category'] as String;
      final limit = (budget['amount_limit'] as num).toDouble();
      final spent = await db.getBudgetSpent(category, now.month, now.year);
      final pct = limit > 0 ? spent / limit : 0.0;

      if (pct >= 0.8) {
        await showBudgetAlert(category: category, spent: spent, limit: limit);
      }
    }
  }

  // ─── EMI / Bill Reminders ─────────────────────────────────────────────────

  /// Show reminders for EMIs due in the next 3 days.
  Future<void> checkEmiReminders() async {
    if (!_initialized) await initialize();

    final debts = await DatabaseHelper.instance.getDebts();
    final now = DateTime.now();

    for (final debt in debts) {
      final outstanding = (debt['outstanding'] as num).toDouble();
      if (outstanding <= 0) continue;

      final emiDay = debt['emi_day'] as int? ?? 1;
      final emiAmount = (debt['emi_amount'] as num).toDouble();
      if (emiAmount <= 0) continue;

      // Check if EMI is due in next 3 days
      final dueDate = DateTime(now.year, now.month, emiDay);
      final daysUntil = dueDate.difference(now).inDays;
      if (daysUntil >= 0 && daysUntil <= 3) {
        await _showEmiReminder(
          debtName: debt['name'] as String,
          emiAmount: emiAmount,
          daysUntil: daysUntil,
          debtId: debt['id'] as int,
        );
      }
    }
  }

  Future<void> _showEmiReminder({
    required String debtName,
    required double emiAmount,
    required int daysUntil,
    required int debtId,
  }) async {
    final dueText = daysUntil == 0
        ? 'due today'
        : daysUntil == 1
            ? 'due tomorrow'
            : 'due in $daysUntil days';

    await _plugin.show(
      _billReminderId + debtId,
      '💳 EMI Reminder: $debtName',
      '₹${emiAmount.toStringAsFixed(0)} EMI $dueText',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Reminders',
          channelDescription: 'EMI and bill reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true),
      ),
      payload: 'debt:$debtId',
    );
  }

  // ─── Weekly Insight ───────────────────────────────────────────────────────

  /// Show a simple weekly spending summary notification.
  Future<void> showWeeklyInsight(double weeklySpend, double prevWeekSpend) async {
    if (!_initialized) await initialize();

    final diff = weeklySpend - prevWeekSpend;
    final isUp = diff > 0;
    final pct = prevWeekSpend > 0 ? (diff.abs() / prevWeekSpend * 100).toStringAsFixed(0) : '0';

    await _plugin.show(
      _weeklyInsightId,
      '📊 Weekly Spending Summary',
      'You spent ₹${weeklySpend.toStringAsFixed(0)} this week — '
          '${isUp ? '↑' : '↓'}$pct% vs last week',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _insightChannelId,
          'Financial Insights',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: false),
      ),
      payload: 'insight:weekly',
    );
  }

  // ─── Recurring Transaction Alert ─────────────────────────────────────────

  Future<void> showRecurringProcessed(int count) async {
    if (!_initialized) await initialize();
    if (count <= 0) return;

    await _plugin.show(
      4000,
      '🔄 Recurring Transactions',
      '$count recurring transaction${count > 1 ? 's' : ''} processed automatically',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Reminders',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(presentAlert: false),
      ),
    );
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) => _plugin.cancel(id);

  /// Cancel all notifications
  Future<void> cancelAll() => _plugin.cancelAll();
}
