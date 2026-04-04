import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class ExportService {
  static final ExportService instance = ExportService._();
  ExportService._();

  final _dateFormat = DateFormat('dd MMM yyyy HH:mm');
  final _fileDate = DateFormat('yyyy-MM-dd');

  /// Exports all transactions as CSV and shares the file.
  Future<void> exportTransactionsCSV() async {
    final transactions = await DatabaseHelper.instance.getAllTransactionsRaw();
    final accounts = await DatabaseHelper.instance.getAccounts();

    // Build account ID → name map
    final accountMap = {for (final a in accounts) a['id'] as int: a['name'] as String};

    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Amount', 'Category', 'Note', 'From Account', 'To Account'],
    ];

    for (final tx in transactions) {
      final date = DateTime.parse(tx['date'] as String);
      rows.add([
        _dateFormat.format(date),
        tx['type'] ?? '',
        tx['amount'],
        tx['category'] ?? '',
        tx['note'] ?? '',
        tx['from_account'] != null ? (accountMap[tx['from_account']] ?? '') : '',
        tx['to_account'] != null ? (accountMap[tx['to_account']] ?? '') : '',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final filePath = await _writeTempFile(
      'transactions_${_fileDate.format(DateTime.now())}.csv',
      csv,
    );

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/csv')],
      subject: 'FinPilot.ai — Transactions Export',
    );
  }

  /// Exports full database as JSON backup and shares it.
  Future<void> exportBackupJSON() async {
    final db = DatabaseHelper.instance;

    final backup = {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': await db.getAccounts(),
      'transactions': await db.getAllTransactionsRaw(),
      'budgets': await db.getBudgets(),
      'goals': await db.getGoals(),
      'investments': await db.getInvestments(),
      'debts': await db.getDebts(),
      'recurring': await db.getRecurringTransactions(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(backup);
    final filePath = await _writeTempFile(
      'personal_cfo_backup_${_fileDate.format(DateTime.now())}.json',
      json,
    );

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'application/json')],
      subject: 'FinPilot.ai — Full Backup',
    );
  }

  /// Restores data from a JSON backup file path.
  Future<String> restoreFromJSON(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Backup file not found');

    final content = await file.readAsString();
    final backup = jsonDecode(content) as Map<String, dynamic>;

    final version = backup['version'] ?? 1;
    if (version < 1 || version > 2) throw Exception('Unsupported backup version: $version');

    final db = DatabaseHelper.instance;
    int restored = 0;

    final accounts = backup['accounts'] as List? ?? [];
    for (final a in accounts) {
      try {
        await db.insertAccount(Map<String, dynamic>.from(a)..remove('id'));
        restored++;
      } catch (e) {
        debugPrint('Restore: failed to insert account: $e');
      }
    }

    // Note: transactions and other tables would need more careful handling
    // to avoid duplicate IDs. This is a simplified restore.

    return 'Restored $restored accounts from backup. Transactions and other data may need manual review.';
  }

  /// Generates a monthly report string.
  Future<String> generateMonthlyReportText({required int month, required int year}) async {
    final db = DatabaseHelper.instance;
    final spending = await db.getCategorySpending(month: month, year: year);
    final total = await db.getTotalSpending(month: month, year: year);
    final accounts = await db.getAccounts();

    double totalBalance = 0;
    for (final a in accounts) {
      totalBalance += (a['balance'] as num).toDouble();
    }

    final monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));
    final sb = StringBuffer();
    sb.writeln('FinPilot.ai — Monthly Report');
    sb.writeln('Period: $monthName');
    sb.writeln('Generated: ${_dateFormat.format(DateTime.now())}');
    sb.writeln('');
    sb.writeln('SUMMARY');
    sb.writeln('Total Spending: ₹${total.toStringAsFixed(2)}');
    sb.writeln('Current Net Balance: ₹${totalBalance.toStringAsFixed(2)}');
    sb.writeln('');
    sb.writeln('SPENDING BY CATEGORY');
    final sorted = spending.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(1) : '0.0';
      sb.writeln('  ${e.key}: ₹${e.value.toStringAsFixed(2)} ($pct%)');
    }

    return sb.toString();
  }

  Future<void> shareMonthlyReport({required int month, required int year}) async {
    final report = await generateMonthlyReportText(month: month, year: year);
    final monthName = DateFormat('MMM_yyyy').format(DateTime(year, month));
    final filePath = await _writeTempFile('report_$monthName.txt', report);
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/plain')],
      subject: 'FinPilot.ai — Monthly Report',
    );
  }

  Future<String> _writeTempFile(String filename, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    return file.path;
  }
}
