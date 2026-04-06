import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/export_service.dart';
import '../../core/services/notification_service.dart';
import 'categories_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _loading = false;

  Future<void> _exportCSV() async {
    setState(() => _loading = true);
    try {
      await ExportService.instance.exportTransactionsCSV();
    } catch (e) {
      if (mounted) _showError('Export failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _loading = true);
    try {
      await ExportService.instance.exportBackupJSON();
    } catch (e) {
      if (mounted) _showError('Backup failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will add data from the backup file to your current data. '
          'Existing records will not be deleted.\n\nPick a JSON backup file to continue.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pick File')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      setState(() => _loading = true);
      final msg = await ExportService.instance.restoreFromJSON(result.files.single.path!);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) _showError('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setPinEnabled(bool enabled) async {
    if (enabled) {
      final pin = await _showPinSetupDialog();
      if (pin == null) return;
      await ref.read(pinEnabledProvider.notifier).setEnabled(true);
    } else {
      await ref.read(pinEnabledProvider.notifier).setEnabled(false);
    }
  }

  Future<String?> _showPinSetupDialog() async {
    String pin = '';
    String confirm = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final pinCtrl = TextEditingController();
        final confirmCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: '4–6 digit PIN'),
                onChanged: (v) => pin = v,
              ),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
                onChanged: (v) => confirm = v,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (pin.length < 4) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('PIN must be at least 4 digits')));
                  return;
                }
                if (pin != confirm) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('PINs do not match')));
                  return;
                }
                Navigator.pop(ctx, pin);
              },
              child: const Text('Set PIN'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _testBudgetNotification() async {
    await NotificationService.instance.showBudgetAlert(
      category: 'Food',
      spent: 4800,
      limit: 5000,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test notification sent!')),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(darkModeProvider);
    final pinEnabled = ref.watch(pinEnabledProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Preferences ──────────────────────────────────────────────
              _SectionHeader('Preferences'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Dark Mode'),
                      value: isDark,
                      onChanged: (v) => ref.read(darkModeProvider.notifier).set(v),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('Manage Categories'),
                      subtitle: const Text('Add or edit income and expense tags'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Security ────────────────────────────────────────────────
              _SectionHeader('Security'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.lock_outlined),
                      title: const Text('PIN Lock'),
                      subtitle: const Text('Require PIN to open the app'),
                      value: pinEnabled,
                      onChanged: _setPinEnabled,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Notifications ───────────────────────────────────────────
              _SectionHeader('Notifications'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Test Budget Alert'),
                      subtitle: const Text('Send a sample budget notification'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _testBudgetNotification,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Data & Backup ───────────────────────────────────────────
              _SectionHeader('Data & Backup'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.table_chart_outlined),
                      title: const Text('Export Transactions (CSV)'),
                      subtitle: const Text('Share as spreadsheet'),
                      trailing: const Icon(Icons.share_outlined),
                      onTap: _loading ? null : _exportCSV,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.backup_outlined),
                      title: const Text('Create Full Backup (JSON)'),
                      subtitle: const Text('Includes all data — accounts, transactions, goals...'),
                      trailing: const Icon(Icons.share_outlined),
                      onTap: _loading ? null : _exportBackup,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.restore_outlined),
                      title: const Text('Restore from Backup'),
                      subtitle: const Text('Import a JSON backup file'),
                      trailing: const Icon(Icons.folder_open_outlined),
                      onTap: _loading ? null : _restoreBackup,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── About ───────────────────────────────────────────────────
              _SectionHeader('About'),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: Icon(Icons.account_balance_wallet, color: cs.primary, size: 20),
                      ),
                      title: const Text('FinPilot.ai'),
                      subtitle: const Text('v2.0.0 · Personal Finance Manager'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Data Storage'),
                      subtitle: const Text('All data stored locally on device. Nothing shared.'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
          if (_loading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
      );
}
