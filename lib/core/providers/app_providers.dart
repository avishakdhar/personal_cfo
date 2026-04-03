import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/account_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/goal_model.dart';
import '../models/investment_model.dart';
import '../models/debt_model.dart';
import '../models/recurring_transaction_model.dart';
import '../models/net_worth_snapshot_model.dart';
import '../services/ai_service.dart';

// ─── SETTINGS ────────────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DarkModeNotifier(prefs);
});

class DarkModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  DarkModeNotifier(this._prefs) : super(_prefs.getBool('dark_mode') ?? false);

  void toggle() {
    state = !state;
    _prefs.setBool('dark_mode', state);
  }

  void set(bool value) {
    state = value;
    _prefs.setBool('dark_mode', value);
  }
}

final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, String>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiKeyNotifier(prefs);
});

class ApiKeyNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  ApiKeyNotifier(this._prefs) : super(_prefs.getString('claude_api_key') ?? '');

  Future<void> setKey(String key) async {
    state = key;
    await _prefs.setString('claude_api_key', key);
  }
}

final aiServiceProvider = Provider<AiService>((ref) {
  final key = ref.watch(apiKeyProvider);
  return AiService(key);
});

// PIN auth
final pinEnabledProvider = StateNotifierProvider<PinEnabledNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PinEnabledNotifier(prefs);
});

class PinEnabledNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  PinEnabledNotifier(this._prefs) : super(_prefs.getBool('pin_enabled') ?? false);

  Future<void> setEnabled(bool value) async {
    state = value;
    await _prefs.setBool('pin_enabled', value);
  }
}

final isAuthenticatedProvider = StateProvider<bool>((ref) => false);
final isOnboardedProvider = StateNotifierProvider<OnboardedNotifier, bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardedNotifier(prefs);
});

class OnboardedNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  OnboardedNotifier(this._prefs) : super(_prefs.getBool('onboarded') ?? false);

  Future<void> complete() async {
    state = true;
    await _prefs.setBool('onboarded', true);
  }
}

// ─── ACCOUNTS ────────────────────────────────────────────────────────────────

final accountsProvider = AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() => _load();

  Future<List<Account>> _load() async {
    final maps = await DatabaseHelper.instance.getAccounts();
    return maps.map(Account.fromMap).toList();
  }

  Future<void> add(Account account) async {
    await DatabaseHelper.instance.insertAccount(account.toMap()..remove('id'));
    ref.invalidateSelf();
  }

  Future<void> update(int id, Map<String, dynamic> values) async {
    await DatabaseHelper.instance.updateAccount(id, values);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteAccount(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final totalBalanceProvider = FutureProvider<double>((ref) async {
  final accounts = await ref.watch(accountsProvider.future);
  return accounts.fold(0.0, (sum, a) => sum + a.balance);
});

// ─── TRANSACTIONS ─────────────────────────────────────────────────────────────

final transactionFilterProvider = StateProvider<TransactionFilter>((ref) => const TransactionFilter());

class TransactionFilter {
  final String? category;
  final String? type;
  final String? searchQuery;
  final DateTime? startDate;
  final DateTime? endDate;

  const TransactionFilter({
    this.category,
    this.type,
    this.searchQuery,
    this.startDate,
    this.endDate,
  });

  TransactionFilter copyWith({
    String? category,
    String? type,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      TransactionFilter(
        category: category ?? this.category,
        type: type ?? this.type,
        searchQuery: searchQuery ?? this.searchQuery,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
      );
}

final transactionsProvider = AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() => _load();

  Future<List<TransactionModel>> _load() async {
    final filter = ref.watch(transactionFilterProvider);
    final maps = await DatabaseHelper.instance.getTransactions(
      category: filter.category,
      type: filter.type,
      searchQuery: filter.searchQuery,
      startDate: filter.startDate,
      endDate: filter.endDate,
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<void> addExpense({
    required double amount,
    required int fromAccountId,
    required String category,
    required String note,
  }) async {
    await DatabaseHelper.instance.insertExpense(
      amount: amount,
      fromAccountId: fromAccountId,
      category: category,
      note: note,
    );
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> addIncome({
    required double amount,
    required int toAccountId,
    required String note,
    String category = 'Income',
  }) async {
    await DatabaseHelper.instance.insertIncome(
      amount: amount,
      toAccountId: toAccountId,
      note: note,
      category: category,
    );
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> transfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String note = 'Account Transfer',
  }) async {
    await DatabaseHelper.instance.transferMoney(
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      amount: amount,
      note: note,
    );
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> softDelete(int id) async {
    await DatabaseHelper.instance.softDeleteTransaction(id);
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

// ─── DASHBOARD ────────────────────────────────────────────────────────────────

class DashboardData {
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final double todaySpending;
  final double monthlySpending;
  final Map<String, double> categorySpending;

  const DashboardData({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.todaySpending,
    required this.monthlySpending,
    required this.categorySpending,
  });
}

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final now = DateTime.now();
  final db = DatabaseHelper.instance;

  final results = await Future.wait([
    db.getTotalAssets(),
    db.getTotalLiabilities(),
    db.getTodaySpending(),
    db.getTotalSpending(month: now.month, year: now.year),
    db.getCategorySpending(month: now.month, year: now.year),
  ]);

  final assets = results[0] as double;
  final liabilities = results[1] as double;
  final today = results[2] as double;
  final monthly = results[3] as double;
  final categories = results[4] as Map<String, double>;

  return DashboardData(
    totalAssets: assets,
    totalLiabilities: liabilities,
    netWorth: assets - liabilities,
    todaySpending: today,
    monthlySpending: monthly,
    categorySpending: categories,
  );
});

// ─── BUDGETS ─────────────────────────────────────────────────────────────────

final budgetsProvider = AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(
  BudgetsNotifier.new,
);

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  @override
  Future<List<Budget>> build() => _load();

  Future<List<Budget>> _load() async {
    final now = DateTime.now();
    final maps = await DatabaseHelper.instance.getBudgets(month: now.month, year: now.year);
    return maps.map(Budget.fromMap).toList();
  }

  Future<void> add(Budget budget) async {
    await DatabaseHelper.instance.insertBudget(budget.toMap()..remove('id'));
    ref.invalidateSelf();
  }

  Future<void> update(int id, Map<String, dynamic> values) async {
    await DatabaseHelper.instance.updateBudget(id, values);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteBudget(id);
    ref.invalidateSelf();
  }
}

final budgetSpentProvider = FutureProvider.family<double, String>((ref, category) async {
  final now = DateTime.now();
  return DatabaseHelper.instance.getBudgetSpent(category, now.month, now.year);
});

// ─── GOALS ───────────────────────────────────────────────────────────────────

final goalsProvider = AsyncNotifierProvider<GoalsNotifier, List<Goal>>(
  GoalsNotifier.new,
);

class GoalsNotifier extends AsyncNotifier<List<Goal>> {
  @override
  Future<List<Goal>> build() => _load();

  Future<List<Goal>> _load() async {
    final maps = await DatabaseHelper.instance.getGoals();
    return maps.map(Goal.fromMap).toList();
  }

  Future<void> add(Goal goal) async {
    await DatabaseHelper.instance.insertGoal(goal.toMap()..remove('id'));
    ref.invalidateSelf();
  }

  Future<void> contribute(int goalId, double amount) async {
    await DatabaseHelper.instance.contributeToGoal(goalId, amount);
    ref.invalidateSelf();
  }

  Future<void> update(int id, Map<String, dynamic> values) async {
    await DatabaseHelper.instance.updateGoal(id, values);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteGoal(id);
    ref.invalidateSelf();
  }
}

// ─── INVESTMENTS ──────────────────────────────────────────────────────────────

final investmentsProvider = AsyncNotifierProvider<InvestmentsNotifier, List<Investment>>(
  InvestmentsNotifier.new,
);

class InvestmentsNotifier extends AsyncNotifier<List<Investment>> {
  @override
  Future<List<Investment>> build() => _load();

  Future<List<Investment>> _load() async {
    final maps = await DatabaseHelper.instance.getInvestments();
    return maps.map(Investment.fromMap).toList();
  }

  Future<void> add(Investment investment) async {
    await DatabaseHelper.instance.insertInvestment(investment.toMap()..remove('id'));
    ref.invalidateSelf();
  }

  Future<void> update(int id, Map<String, dynamic> values) async {
    await DatabaseHelper.instance.updateInvestment(id, values);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteInvestment(id);
    ref.invalidateSelf();
  }
}

final portfolioValueProvider = FutureProvider<double>((ref) async {
  final investments = await ref.watch(investmentsProvider.future);
  return investments.fold(0.0, (sum, i) => sum + i.currentValue);
});

final portfolioPnLProvider = FutureProvider<double>((ref) async {
  final investments = await ref.watch(investmentsProvider.future);
  return investments.fold(0.0, (sum, i) => sum + i.profitLoss);
});

// ─── DEBTS ───────────────────────────────────────────────────────────────────

final debtsProvider = AsyncNotifierProvider<DebtsNotifier, List<Debt>>(
  DebtsNotifier.new,
);

class DebtsNotifier extends AsyncNotifier<List<Debt>> {
  @override
  Future<List<Debt>> build() => _load();

  Future<List<Debt>> _load() async {
    final maps = await DatabaseHelper.instance.getDebts();
    return maps.map(Debt.fromMap).toList();
  }

  Future<void> add(Debt debt) async {
    await DatabaseHelper.instance.insertDebt(debt.toMap()..remove('id'));
    ref.invalidateSelf();
  }

  Future<void> recordEmi(int debtId, double amount) async {
    await DatabaseHelper.instance.recordEmiPayment(debtId, amount);
    ref.invalidateSelf();
  }

  Future<void> update(int id, Map<String, dynamic> values) async {
    await DatabaseHelper.instance.updateDebt(id, values);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteDebt(id);
    ref.invalidateSelf();
  }
}

final totalOutstandingProvider = FutureProvider<double>((ref) async {
  final debts = await ref.watch(debtsProvider.future);
  return debts.fold(0.0, (sum, d) => sum + d.outstanding);
});

// ─── RECURRING ───────────────────────────────────────────────────────────────

final recurringProvider = AsyncNotifierProvider<RecurringNotifier, List<RecurringTransaction>>(
  RecurringNotifier.new,
);

class RecurringNotifier extends AsyncNotifier<List<RecurringTransaction>> {
  @override
  Future<List<RecurringTransaction>> build() => _load();

  Future<List<RecurringTransaction>> _load() async {
    final maps = await DatabaseHelper.instance.getRecurringTransactions();
    return maps.map(RecurringTransaction.fromMap).toList();
  }

  Future<void> add(RecurringTransaction rec) async {
    await DatabaseHelper.instance.insertRecurring(rec.toMap()..remove('id'));
    ref.invalidateSelf();
  }

  Future<void> update(int id, Map<String, dynamic> values) async {
    await DatabaseHelper.instance.updateRecurring(id, values);
    ref.invalidateSelf();
  }

  Future<void> delete(int id) async {
    await DatabaseHelper.instance.deleteRecurring(id);
    ref.invalidateSelf();
  }
}

// ─── NET WORTH ────────────────────────────────────────────────────────────────

final netWorthSnapshotsProvider = FutureProvider<List<NetWorthSnapshot>>((ref) async {
  final maps = await DatabaseHelper.instance.getNetWorthSnapshots();
  return maps.map(NetWorthSnapshot.fromMap).toList();
});
