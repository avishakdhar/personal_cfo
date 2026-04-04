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
  final _apiKeyCtrl = TextEditingController();
  bool _showApiKey = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl.text = ref.read(apiKeyProvider);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    await ref.read(apiKeyProvider.notifier).setKey(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(key.isEmpty ? 'API key cleared' : 'API key saved'),
          backgroundColor: key.isEmpty ? Colors.orange : Colors.green,
        ),
      );
    }
  }

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
      // Prompt to set PIN
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
    final apiKey = ref.watch(apiKeyProvider);
    final aiProvider = ref.watch(aiProviderTypeProvider);
    final cs = Theme.of(context).colorScheme;

    String hint = 'sk-ant-...';
    String label = 'Claude API Key';
    String helper = 'Get your key at console.anthropic.com';
    String providerName = 'Claude';

    if (aiProvider == AiProviderType.openai) {
      hint = 'sk-proj-...';
      label = 'OpenAI API Key';
      helper = 'Get your key at platform.openai.com';
      providerName = 'OpenAI';
    } else if (aiProvider == AiProviderType.gemini) {
      hint = 'AIzaSy...';
      label = 'Gemini API Key';
      helper = 'Get your key at aistudio.google.com';
      providerName = 'Gemini';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── AI Configuration ────────────────────────────────────────
              _SectionHeader('AI Configuration'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            apiKey.isNotEmpty ? Icons.check_circle : Icons.warning_amber_rounded,
                            color: apiKey.isNotEmpty ? Colors.green : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            apiKey.isNotEmpty ? '$providerName API key configured' : 'API key not set — AI features disabled',
                            style: TextStyle(
                              color: apiKey.isNotEmpty ? Colors.green : Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AiProviderType>(
                        initialValue: aiProvider,
                        items: const [
                          DropdownMenuItem(value: AiProviderType.claude, child: Text('Anthropic (Claude)')),
                          DropdownMenuItem(value: AiProviderType.openai, child: Text('OpenAI (GPT-4o)')),
                          DropdownMenuItem(value: AiProviderType.gemini, child: Text('Google Gemini')),
                        ],
                        onChanged: (v) {
                          if (v != null) ref.read(aiProviderTypeProvider.notifier).setType(v);
                        },
                        decoration: const InputDecoration(
                          labelText: 'AI Model Provider',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _apiKeyCtrl,
                        obscureText: !_showApiKey,
                        decoration: InputDecoration(
                          labelText: label,
                          hintText: hint,
                          helperText: helper,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _showApiKey = !_showApiKey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _apiKeyCtrl.clear();
                                _saveApiKey();
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saveApiKey,
                              child: const Text('Save Key'),
                            ),
                          ),
                        ],
                      ),
                      if (apiKey.isEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withAlpha(77)),
                          ),
                          child: const Text(
                            'Without an API key, you can still track transactions, accounts, budgets, goals, investments, and debts manually. AI features (chat, insights, auto-categorization) will be unavailable.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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
                      subtitle: const Text('v2.0.0 · AI-powered personal finance'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: const Text('Data Storage'),
                      subtitle: const Text('All data stored locally on device. Nothing shared.'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security_outlined),
                      title: const Text('Privacy'),
                      subtitle: const Text('AI queries sent to Anthropic API only when API key is set.'),
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
