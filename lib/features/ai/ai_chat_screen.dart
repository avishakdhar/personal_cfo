import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../core/database/database_helper.dart';
import '../../core/providers/app_providers.dart';
import 'receipt_scan_screen.dart';

class _Message {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime time;
  _Message({required this.role, required this.content, DateTime? time})
      : time = time ?? DateTime.now();
}

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Message> _messages = [];
  bool _loading = false;
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _messages.add(_Message(
      role: 'assistant',
      content:
          "Hi! I'm FinPilot.ai. Ask me about your finances, or say something like \"spent ₹500 on dinner\" to add a transaction quickly.",
    ));
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
    );
    if (mounted) setState(() {});
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device')),
      );
      return;
    }

    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
    } else {
      setState(() => _listening = true);
      await _speech.listen(
        onResult: (result) {
          setState(() => _msgCtrl.text = result.recognizedWords);
          if (result.finalResult) {
            setState(() => _listening = false);
            if (result.recognizedWords.isNotEmpty) _sendMessage();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_IN',
      );
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    if (_listening) _speech.stop();
    super.dispose();
  }

  Future<String> _buildFinancialContext() async {
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    final accounts = await db.getAccounts();
    final monthlySpend =
        await db.getTotalSpending(month: now.month, year: now.year);
    final categorySpend =
        await db.getCategorySpending(month: now.month, year: now.year);
    final assets = await db.getTotalAssets();
    final liabilities = await db.getTotalLiabilities();

    final accList =
        accounts.map((a) => '${a['name']}: ₹${a['balance']}').join(', ');
    final catList = categorySpend.entries
        .map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}')
        .join(', ');

    return "Accounts: $accList\n"
        "This month's spending: ₹${monthlySpend.toStringAsFixed(0)}\n"
        "Category breakdown: $catList\n"
        "Total assets: ₹${assets.toStringAsFixed(0)}\n"
        "Total liabilities: ₹${liabilities.toStringAsFixed(0)}\n"
        "Net worth: ₹${(assets - liabilities).toStringAsFixed(0)}\n";
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Message(role: 'user', content: text));
      _loading = true;
      _msgCtrl.clear();
    });
    _scrollToBottom();

    try {
      final ai = ref.read(aiServiceProvider);
      if (!ai.isConfigured) {
        setState(() {
          _messages.add(_Message(
            role: 'assistant',
            content:
                '⚠️ Claude API key not set. Go to Settings → API Key to configure it.',
          ));
          _loading = false;
        });
        return;
      }

      // Check if it's a natural language transaction entry
      final lowerText = text.toLowerCase();
      final isTransaction = (lowerText.contains('spent') ||
              lowerText.contains('paid') ||
              lowerText.contains('bought') ||
              lowerText.contains('received') ||
              lowerText.contains('earned') ||
              lowerText.contains('got')) &&
          RegExp(r'\d+').hasMatch(text);

      if (isTransaction) {
        // Parse and create transaction
        final parsed = await ai.parseNaturalLanguage(text);
        final amount = parsed['amount'] as double;
        final category = parsed['category'] as String;
        final note = parsed['note'] as String;
        final type = parsed['type'] as String;

        if (amount > 0) {
          final accounts = await DatabaseHelper.instance.getAccounts();
          if (accounts.isNotEmpty) {
            final accountId = accounts.first['id'] as int;
            if (type == 'income') {
              await DatabaseHelper.instance.insertIncome(
                  amount: amount,
                  toAccountId: accountId,
                  note: note,
                  category: category);
            } else {
              await DatabaseHelper.instance.insertExpense(
                  amount: amount,
                  fromAccountId: accountId,
                  category: category,
                  note: note);
            }
            ref.invalidate(accountsProvider);
            ref.invalidate(dashboardProvider);
            ref.invalidate(transactionsProvider);

            setState(() {
              _messages.add(_Message(
                role: 'assistant',
                content:
                    '✅ Added ${type == 'income' ? 'income' : 'expense'}: ₹${amount.toStringAsFixed(0)} for $category ($note). Deducted from "${accounts.first['name']}".',
              ));
              _loading = false;
            });
            _scrollToBottom();
            return;
          }
        }
      }

      // Regular chat
      final context = await _buildFinancialContext();
      final history = _messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final response =
          await ai.chat(messages: history, financialContext: context);
      setState(() {
        _messages.add(_Message(role: 'assistant', content: response));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_Message(role: 'assistant', content: '❌ Error: $e'));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, size: 20),
            SizedBox(width: 8),
            Text('AI Financial Advisor'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Receipt',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReceiptScanScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _loading) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                              radius: 12,
                              child: Icon(Icons.smart_toy, size: 14)),
                          SizedBox(width: 8),
                          SizedBox(
                              width: 50,
                              height: 20,
                              child: LinearProgressIndicator()),
                        ],
                      ),
                    ),
                  );
                }
                final msg = _messages[i];
                final isUser = msg.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight:
                            isUser ? const Radius.circular(4) : null,
                        bottomLeft:
                            !isUser ? const Radius.circular(4) : null,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.content,
                          style: TextStyle(
                              color: isUser
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('HH:mm').format(msg.time),
                          style: TextStyle(
                            fontSize: 10,
                            color: (isUser ? cs.onPrimary : cs.onSurfaceVariant)
                                .withAlpha(153),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withAlpha(13),
                    blurRadius: 8,
                    offset: const Offset(0, -2))
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Voice input button
                  if (_speechAvailable)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: Icon(
                          _listening ? Icons.mic : Icons.mic_none,
                          color: _listening ? Colors.red : cs.primary,
                        ),
                        tooltip: _listening ? 'Stop listening' : 'Voice input',
                        onPressed: _loading ? null : _toggleListening,
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: _listening
                            ? 'Listening...'
                            : '"spent 500 on dinner" or ask anything...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _loading ? null : _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
