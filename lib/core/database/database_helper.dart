import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('personal_cfo.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL DEFAULT 0,
        currency TEXT NOT NULL DEFAULT 'INR',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        from_account INTEGER,
        to_account INTEGER,
        category TEXT,
        note TEXT,
        date TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount_limit REAL NOT NULL,
        period TEXT NOT NULL DEFAULT 'monthly',
        month INTEGER NOT NULL,
        year INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        target_amount REAL NOT NULL,
        current_amount REAL NOT NULL DEFAULT 0,
        target_date TEXT,
        description TEXT,
        icon_name TEXT NOT NULL DEFAULT 'star',
        is_completed INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        symbol TEXT,
        quantity REAL NOT NULL DEFAULT 0,
        buy_price REAL NOT NULL,
        current_price REAL NOT NULL,
        buy_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        principal REAL NOT NULL,
        outstanding REAL NOT NULL,
        interest_rate REAL NOT NULL DEFAULT 0,
        emi_amount REAL NOT NULL DEFAULT 0,
        emi_day INTEGER NOT NULL DEFAULT 1,
        start_date TEXT NOT NULL,
        end_date TEXT,
        lender TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        from_account INTEGER,
        to_account INTEGER,
        category TEXT,
        note TEXT,
        frequency TEXT NOT NULL,
        next_due_date TEXT NOT NULL,
        last_processed_date TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE net_worth_snapshots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        total_assets REAL NOT NULL,
        total_liabilities REAL NOT NULL,
        net_worth REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Create default categories
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color_hex TEXT NOT NULL DEFAULT '#6750A4',
        icon_name TEXT NOT NULL DEFAULT 'category'
      )
    ''');
    
    // Seed default expense categories
    for (var cat in ['Food', 'Housing', 'Transport', 'Utilities', 'Entertainment', 'Health', 'Other']) {
      await db.insert('categories', {'name': cat, 'type': 'expense'});
    }
    // Seed default income categories
    for (var cat in ['Salary', 'Business', 'Investments', 'Freelance', 'Other']) {
      await db.insert('categories', {'name': cat, 'type': 'income'});
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate accounts
      for (final col in [
        "ALTER TABLE accounts ADD COLUMN currency TEXT NOT NULL DEFAULT 'INR'",
        "ALTER TABLE accounts ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1",
        "ALTER TABLE accounts ADD COLUMN created_at TEXT NOT NULL DEFAULT ''",
      ]) {
        try { await db.execute(col); } catch (_) {}
      }

      // Migrate transactions
      for (final col in [
        "ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'",
        "ALTER TABLE transactions ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0",
      ]) {
        try { await db.execute(col); } catch (_) {}
      }

      // Fix types for existing records
      try {
        await db.execute(
          "UPDATE transactions SET type='income' WHERE from_account IS NULL AND to_account IS NOT NULL");
        await db.execute(
          "UPDATE transactions SET type='transfer' WHERE from_account IS NOT NULL AND to_account IS NOT NULL");
      } catch (_) {}

      try { await db.execute("DROP TABLE IF EXISTS categories"); } catch (_) {}

      // Create new tables
      final newTables = [
        '''CREATE TABLE IF NOT EXISTS budgets (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL, amount_limit REAL NOT NULL,
          period TEXT NOT NULL DEFAULT 'monthly',
          month INTEGER NOT NULL, year INTEGER NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, target_amount REAL NOT NULL,
          current_amount REAL NOT NULL DEFAULT 0,
          target_date TEXT, description TEXT,
          icon_name TEXT NOT NULL DEFAULT 'star',
          is_completed INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS investments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, type TEXT NOT NULL,
          symbol TEXT, quantity REAL NOT NULL DEFAULT 0,
          buy_price REAL NOT NULL, current_price REAL NOT NULL,
          buy_date TEXT NOT NULL, notes TEXT,
          created_at TEXT NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS debts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, type TEXT NOT NULL,
          principal REAL NOT NULL, outstanding REAL NOT NULL,
          interest_rate REAL NOT NULL DEFAULT 0,
          emi_amount REAL NOT NULL DEFAULT 0,
          emi_day INTEGER NOT NULL DEFAULT 1,
          start_date TEXT NOT NULL, end_date TEXT,
          lender TEXT, notes TEXT, created_at TEXT NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS recurring_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL, amount REAL NOT NULL,
          from_account INTEGER, to_account INTEGER,
          category TEXT, note TEXT,
          frequency TEXT NOT NULL, next_due_date TEXT NOT NULL,
          last_processed_date TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS net_worth_snapshots (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL, total_assets REAL NOT NULL,
          total_liabilities REAL NOT NULL, net_worth REAL NOT NULL)''',
        '''CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
      ];
      for (final sql in newTables) {
        try { await db.execute(sql); } catch (_) {}
      }
    }
    
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL, type TEXT NOT NULL,
            color_hex TEXT NOT NULL DEFAULT '#6750A4',
            icon_name TEXT NOT NULL DEFAULT 'category'
          )
        ''');
        
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM categories')) ?? 0;
        if (count == 0) {
          for (var cat in ['Food', 'Housing', 'Transport', 'Utilities', 'Entertainment', 'Health', 'Other']) {
            await db.insert('categories', {'name': cat, 'type': 'expense'});
          }
          for (var cat in ['Salary', 'Business', 'Investments', 'Freelance', 'Other']) {
            await db.insert('categories', {'name': cat, 'type': 'income'});
          }
        }
      } catch (_) {}
    }
  }

  // ─── ACCOUNTS ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await database;
    return db.query('accounts', where: 'is_active = 1', orderBy: 'name ASC');
  }

  Future<Map<String, dynamic>?> getAccount(int id) async {
    final db = await database;
    final rows = await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertAccount(Map<String, dynamic> account) async {
    final db = await database;
    final row = Map<String, dynamic>.from(account);
    row.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    row.putIfAbsent('currency', () => 'INR');
    row.putIfAbsent('is_active', () => 1);
    return db.insert('accounts', row);
  }

  Future<void> updateAccount(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('accounts', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAccount(int id) async {
    final db = await database;
    await db.update('accounts', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  // ─── TRANSACTIONS ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTransactions({
    String? category,
    String? type,
    String? searchQuery,
    int? accountId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final conditions = <String>['is_deleted = 0'];
    final args = <dynamic>[];

    if (category != null) { conditions.add('category = ?'); args.add(category); }
    if (type != null) { conditions.add('type = ?'); args.add(type); }
    if (accountId != null) {
      conditions.add('(from_account = ? OR to_account = ?)');
      args.addAll([accountId, accountId]);
    }
    if (startDate != null) { conditions.add('date >= ?'); args.add(startDate.toIso8601String()); }
    if (endDate != null) { conditions.add('date <= ?'); args.add(endDate.toIso8601String()); }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('(note LIKE ? OR category LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%']);
    }

    return db.query(
      'transactions',
      where: conditions.join(' AND '),
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> insertExpense({
    required double amount,
    required int fromAccountId,
    required String category,
    required String note,
  }) async {
    final db = await database;
    int txId = 0;
    await db.transaction((txn) async {
      txId = await txn.insert('transactions', {
        'type': 'expense',
        'amount': amount,
        'from_account': fromAccountId,
        'to_account': null,
        'category': category,
        'note': note,
        'date': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      });
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [amount, fromAccountId],
      );
    });
    return txId;
  }

  Future<int> insertIncome({
    required double amount,
    required int toAccountId,
    required String note,
    String category = 'Income',
  }) async {
    final db = await database;
    int txId = 0;
    await db.transaction((txn) async {
      txId = await txn.insert('transactions', {
        'type': 'income',
        'amount': amount,
        'from_account': null,
        'to_account': toAccountId,
        'category': category,
        'note': note,
        'date': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      });
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [amount, toAccountId],
      );
    });
    return txId;
  }

  Future<void> transferMoney({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String note = 'Account Transfer',
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'type': 'transfer',
        'amount': amount,
        'from_account': fromAccountId,
        'to_account': toAccountId,
        'category': 'Transfer',
        'note': note,
        'date': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      });
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [amount, fromAccountId],
      );
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [amount, toAccountId],
      );
    });
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('transactions', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTransactionFull({
    required int id,
    required String type,
    required double oldAmount,
    required int? oldAccountId,
    required double newAmount,
    required int? newAccountId,
    required String newDate,
    required String newCategory,
    required String newNote,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // Reverse old balance effect
      if (type == 'expense' && oldAccountId != null) {
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [oldAmount, oldAccountId]);
      } else if (type == 'income' && oldAccountId != null) {
        await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [oldAmount, oldAccountId]);
      }
      // Apply new balance effect
      if (type == 'expense' && newAccountId != null) {
        await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE id = ?', [newAmount, newAccountId]);
      } else if (type == 'income' && newAccountId != null) {
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE id = ?', [newAmount, newAccountId]);
      }
      // Update transaction record
      await txn.update('transactions', {
        'amount': newAmount,
        if (type == 'expense') 'from_account': newAccountId,
        if (type == 'income') 'to_account': newAccountId,
        'date': newDate,
        'category': newCategory,
        'note': newNote,
      }, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> softDeleteTransaction(int id) async {
    final db = await database;
    final rows = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    final tx = rows.first;
    final amount = (tx['amount'] as num).toDouble();
    final type = tx['type'] as String;

    await db.transaction((txn) async {
      await txn.update('transactions', {'is_deleted': 1}, where: 'id = ?', whereArgs: [id]);
      if (type == 'expense' && tx['from_account'] != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [amount, tx['from_account']],
        );
      } else if (type == 'income' && tx['to_account'] != null) {
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance - ? WHERE id = ?',
          [amount, tx['to_account']],
        );
      } else if (type == 'transfer') {
        if (tx['from_account'] != null) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance + ? WHERE id = ?',
            [amount, tx['from_account']],
          );
        }
        if (tx['to_account'] != null) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance = balance - ? WHERE id = ?',
            [amount, tx['to_account']],
          );
        }
      }
    });
  }

  Future<Map<String, double>> getCategorySpending({required int month, required int year}) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final rows = await db.query(
      'transactions',
      where: "type = 'expense' AND is_deleted = 0 AND date >= ? AND date < ?",
      whereArgs: [start, end],
    );
    final result = <String, double>{};
    for (final row in rows) {
      final cat = (row['category'] as String?) ?? 'Other';
      result[cat] = (result[cat] ?? 0) + (row['amount'] as num).toDouble();
    }
    return result;
  }

  Future<double> getTotalSpending({required int month, required int year}) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND is_deleted=0 AND date>=? AND date<?",
      [start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTotalIncome({required int month, required int year}) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type='income' AND is_deleted=0 AND date>=? AND date<?",
      [start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> getTodaySpending() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND is_deleted=0 AND date>=? AND date<?",
      [start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  // ─── BUDGETS ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBudgets({int? month, int? year}) async {
    final db = await database;
    if (month != null && year != null) {
      return db.query('budgets', where: 'month=? AND year=?', whereArgs: [month, year]);
    }
    return db.query('budgets');
  }

  Future<int> insertBudget(Map<String, dynamic> budget) async {
    final db = await database;
    return db.insert('budgets', budget);
  }

  Future<void> updateBudget(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('budgets', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteBudget(int id) async {
    final db = await database;
    await db.delete('budgets', where: 'id=?', whereArgs: [id]);
  }

  Future<double> getBudgetSpent(String category, int month, int year) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE category=? AND type='expense' AND is_deleted=0 AND date>=? AND date<?",
      [category, start, end],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0;
  }

  // ─── GOALS ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getGoals() async {
    final db = await database;
    return db.query('goals', orderBy: 'is_completed ASC, created_at DESC');
  }

  Future<int> insertGoal(Map<String, dynamic> goal) async {
    final db = await database;
    final row = Map<String, dynamic>.from(goal);
    row.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    return db.insert('goals', row);
  }

  Future<void> updateGoal(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('goals', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> contributeToGoal(int goalId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE goals SET current_amount = MIN(current_amount + ?, target_amount) WHERE id = ?',
      [amount, goalId],
    );
    await db.rawUpdate(
      'UPDATE goals SET is_completed = 1 WHERE id = ? AND current_amount >= target_amount',
      [goalId],
    );
  }

  Future<void> deleteGoal(int id) async {
    final db = await database;
    await db.delete('goals', where: 'id=?', whereArgs: [id]);
  }

  // ─── INVESTMENTS ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInvestments() async {
    final db = await database;
    return db.query('investments', orderBy: 'name ASC');
  }

  Future<int> insertInvestment(Map<String, dynamic> investment) async {
    final db = await database;
    final row = Map<String, dynamic>.from(investment);
    row.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    return db.insert('investments', row);
  }

  Future<void> updateInvestment(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('investments', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteInvestment(int id) async {
    final db = await database;
    await db.delete('investments', where: 'id=?', whereArgs: [id]);
  }

  // ─── DEBTS ───────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await database;
    return db.query('debts', orderBy: 'name ASC');
  }

  Future<int> insertDebt(Map<String, dynamic> debt) async {
    final db = await database;
    final row = Map<String, dynamic>.from(debt);
    row.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    return db.insert('debts', row);
  }

  Future<void> reduceDebtOutstanding(int debtId, double amount) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE debts SET outstanding = MAX(0, outstanding - ?) WHERE id = ?',
      [amount, debtId],
    );
  }

  Future<void> updateDebt(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('debts', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> recordEmiPayment(int debtId, double emiAmount, int fromAccountId, String debtName) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE debts SET outstanding = MAX(0, outstanding - ?) WHERE id = ?',
        [emiAmount, debtId],
      );
      await txn.rawUpdate(
        'UPDATE accounts SET balance = balance - ? WHERE id = ?',
        [emiAmount, fromAccountId],
      );
      await txn.insert('transactions', {
        'type': 'expense',
        'amount': emiAmount,
        'from_account': fromAccountId,
        'to_account': null,
        'category': 'Debt Repayment',
        'note': 'EMI: $debtName',
        'date': DateTime.now().toIso8601String(),
        'is_deleted': 0,
      });
    });
  }

  Future<void> deleteDebt(int id) async {
    final db = await database;
    await db.delete('debts', where: 'id=?', whereArgs: [id]);
  }

  // ─── RECURRING TRANSACTIONS ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecurringTransactions() async {
    final db = await database;
    return db.query('recurring_transactions', where: 'is_active=1', orderBy: 'next_due_date ASC');
  }

  Future<int> insertRecurring(Map<String, dynamic> recurring) async {
    final db = await database;
    final row = Map<String, dynamic>.from(recurring);
    row.putIfAbsent('created_at', () => DateTime.now().toIso8601String());
    return db.insert('recurring_transactions', row);
  }

  Future<void> updateRecurring(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('recurring_transactions', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteRecurring(int id) async {
    final db = await database;
    await db.update('recurring_transactions', {'is_active': 0}, where: 'id=?', whereArgs: [id]);
  }

  Future<int> processDueRecurring() async {
    final db = await database;
    final now = DateTime.now();
    final due = await db.query(
      'recurring_transactions',
      where: 'is_active=1 AND next_due_date<=?',
      whereArgs: [now.toIso8601String()],
    );
    int processed = 0;
    for (final rec in due) {
      final type = rec['type'] as String;
      final amount = (rec['amount'] as num).toDouble();
      final frequency = rec['frequency'] as String;
      await db.transaction((txn) async {
        await txn.insert('transactions', {
          'type': type,
          'amount': amount,
          'from_account': rec['from_account'],
          'to_account': rec['to_account'],
          'category': rec['category'],
          'note': '${rec['note'] ?? ''} (Auto)',
          'date': now.toIso8601String(),
          'is_deleted': 0,
        });
        if (type == 'expense' && rec['from_account'] != null) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance=balance-? WHERE id=?', [amount, rec['from_account']]);
        } else if (type == 'income' && rec['to_account'] != null) {
          await txn.rawUpdate(
            'UPDATE accounts SET balance=balance+? WHERE id=?', [amount, rec['to_account']]);
        } else if (type == 'transfer') {
          if (rec['from_account'] != null) {
            await txn.rawUpdate(
              'UPDATE accounts SET balance=balance-? WHERE id=?', [amount, rec['from_account']]);
          }
          if (rec['to_account'] != null) {
            await txn.rawUpdate(
              'UPDATE accounts SET balance=balance+? WHERE id=?', [amount, rec['to_account']]);
          }
        }
        await txn.update(
          'recurring_transactions',
          {
            'last_processed_date': now.toIso8601String(),
            'next_due_date': _nextDueDate(now, frequency).toIso8601String(),
          },
          where: 'id=?',
          whereArgs: [rec['id']],
        );
      });
      processed++;
    }
    return processed;
  }

  DateTime _nextDueDate(DateTime from, String frequency) {
    switch (frequency) {
      case 'daily': return from.add(const Duration(days: 1));
      case 'weekly': return from.add(const Duration(days: 7));
      case 'monthly': return DateTime(from.year, from.month + 1, from.day);
      case 'yearly': return DateTime(from.year + 1, from.month, from.day);
      default: return from.add(const Duration(days: 30));
    }
  }

  // ─── NET WORTH SNAPSHOTS ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNetWorthSnapshots() async {
    final db = await database;
    return db.query('net_worth_snapshots', orderBy: 'date ASC', limit: 24);
  }

  Future<void> saveNetWorthSnapshot() async {
    final accounts = await getAccounts();
    final investments = await getInvestments();
    final debts = await getDebts();
    final db = await database;

    double assets = 0;
    for (final a in accounts) { assets += (a['balance'] as num).toDouble(); }
    for (final i in investments) {
      assets += (i['quantity'] as num).toDouble() * (i['current_price'] as num).toDouble();
    }
    double liabilities = 0;
    for (final d in debts) { liabilities += (d['outstanding'] as num).toDouble(); }

    await db.insert('net_worth_snapshots', {
      'date': DateTime.now().toIso8601String(),
      'total_assets': assets,
      'total_liabilities': liabilities,
      'net_worth': assets - liabilities,
    });
  }

  Future<double> getTotalAssets() async {
    final accounts = await getAccounts();
    final investments = await getInvestments();
    double total = 0;
    for (final a in accounts) { total += (a['balance'] as num).toDouble(); }
    for (final i in investments) {
      total += (i['quantity'] as num).toDouble() * (i['current_price'] as num).toDouble();
    }
    return total;
  }

  Future<double> getTotalLiabilities() async {
    final debts = await getDebts();
    double total = 0;
    for (final d in debts) { total += (d['outstanding'] as num).toDouble(); }
    return total;
  }

  Future<List<Map<String, dynamic>>> getMonthlySpendingHistory({int months = 6}) async {
    final db = await database;
    final result = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final start = date.toIso8601String();
      final end = DateTime(date.year, date.month + 1, 1).toIso8601String();
      final rows = await db.rawQuery(
        "SELECT SUM(amount) as total FROM transactions WHERE type='expense' AND is_deleted=0 AND date>=? AND date<?",
        [start, end],
      );
      result.add({
        'month': date.month,
        'year': date.year,
        'total': (rows.first['total'] as num?)?.toDouble() ?? 0,
      });
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getAllTransactionsRaw() async {
    final db = await database;
    return db.query('transactions', where: 'is_deleted=0', orderBy: 'date DESC');
  }

  // ─── SETTINGS ────────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key=?', whereArgs: [key]);
    return rows.isNotEmpty ? rows.first['value'] as String : null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ─── CATEGORIES ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.query('categories', orderBy: 'name ASC');
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    final db = await database;
    return db.insert('categories', category);
  }

  Future<void> updateCategory(int id, Map<String, dynamic> values) async {
    final db = await database;
    await db.update('categories', values, where: 'id=?', whereArgs: [id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id=?', whereArgs: [id]);
  }

}
