import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/app_providers.dart';

class AiService {
  final String apiKey;
  final AiProviderType provider;

  AiService(this.apiKey, [this.provider = AiProviderType.claude]);

  bool get isConfigured => apiKey.isNotEmpty;

  String _getModel(bool isComplex) {
    switch (provider) {
      case AiProviderType.openai:
        return 'gpt-4o-mini';
      case AiProviderType.gemini:
        return 'gemini-1.5-flash';
      case AiProviderType.claude:
        return isComplex ? 'claude-sonnet-4-6' : 'claude-haiku-4-5-20251001';
    }
  }

  Future<String> _call({
    required bool isComplex,
    required int maxTokens,
    required List<Map<String, dynamic>> messages,
    String? systemPrompt,
  }) async {
    if (!isConfigured) throw Exception('API key not configured.');

    final model = _getModel(isComplex);

    switch (provider) {
      case AiProviderType.openai:
        return _callOpenAI(model, maxTokens, messages, systemPrompt);
      case AiProviderType.gemini:
        return _callGemini(model, maxTokens, messages, systemPrompt);
      case AiProviderType.claude:
        return _callClaude(model, maxTokens, messages, systemPrompt);
    }
  }

  Future<String> _callOpenAI(String model, int maxTokens, List<Map<String, dynamic>> messages, String? systemPrompt) async {
    final payloadMsgs = <Map<String, dynamic>>[];
    if (systemPrompt != null) {
      payloadMsgs.add({'role': 'system', 'content': systemPrompt});
    }
    payloadMsgs.addAll(messages);

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': payloadMsgs,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('OpenAI Error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  Future<String> _callGemini(String model, int maxTokens, List<Map<String, dynamic>> messages, String? systemPrompt) async {
    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';

    final contents = messages.map((m) {
      return {
        'role': m['role'] == 'assistant' ? 'model' : 'user',
        'parts': [{'text': m['content']}]
      };
    }).toList();

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {'maxOutputTokens': maxTokens},
    };

    if (systemPrompt != null) {
      body['systemInstruction'] = {'parts': [{'text': systemPrompt}]};
    }

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Gemini Error: ${response.statusCode} - ${response.body}');
    }

    final data = jsonDecode(response.body);
    if ((data['candidates'] as List?)?.isEmpty ?? true) {
      throw Exception('Gemini returned empty response');
    }
    
    final candidate = data['candidates'][0];
    if (candidate['content'] == null || candidate['content']['parts'] == null) {
      throw Exception('Gemini blocked or returned invalid format');
    }
    return candidate['content']['parts'][0]['text'] as String;
  }

  Future<String> _callClaude(String model, int maxTokens, List<Map<String, dynamic>> messages, String? systemPrompt) async {
    final body = <String, dynamic>{
      'model': model,
      'max_tokens': maxTokens,
      'messages': messages,
    };
    if (systemPrompt != null) body['system'] = systemPrompt;

    final response = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['error']?['message'] ?? 'Claude API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return (data['content'] as List).first['text'] as String;
  }

  // ──────────────────────────────────────────────────────────────────────────

  Future<String> categorizeTransaction(String note) async {
    const categories = [
      'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment',
      'Health', 'Travel', 'Education', 'Groceries', 'Utilities',
      'Rent', 'Insurance', 'Subscriptions', 'Personal Care', 'Other',
    ];

    final result = await _call(
      isComplex: false,
      maxTokens: 20,
      systemPrompt: 'You are a transaction categorizer. Reply with ONLY the category name from this list: ${categories.join(", ")}. No explanation.',
      messages: [{'role': 'user', 'content': 'Categorize this transaction: "$note"'}],
    );
    final cleaned = result.trim();
    return categories.contains(cleaned) ? cleaned : 'Other';
  }

  Future<Map<String, dynamic>> parseNaturalLanguage(String text) async {
    const categories = [
      'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment',
      'Health', 'Travel', 'Education', 'Groceries', 'Utilities',
      'Rent', 'Insurance', 'Subscriptions', 'Personal Care',
      'Salary', 'Freelance', 'Business', 'Other',
    ];

    final result = await _call(
      isComplex: false,
      maxTokens: 150,
      systemPrompt: '''Extract transaction details from natural language and return ONLY valid JSON with these exact keys:
{
  "amount": <number>,
  "category": "<one of: ${categories.join(", ")}>",
  "note": "<brief description>",
  "type": "<income or expense>"
}
No markdown, no explanation, pure JSON only.''',
      messages: [{'role': 'user', 'content': text}],
    );
    try {
      final cleaned = result.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return {
        'amount': (parsed['amount'] as num?)?.toDouble() ?? 0.0,
        'category': parsed['category'] ?? 'Other',
        'note': parsed['note'] ?? text,
        'type': parsed['type'] ?? 'expense',
      };
    } catch (_) {
      return {'amount': 0.0, 'category': 'Other', 'note': text, 'type': 'expense'};
    }
  }

  Future<String> generateInsights({
    required Map<String, double> categorySpending,
    required double totalSpending,
    required double totalIncome,
    required Map<String, double> budgets,
  }) async {
    final spendingJson = categorySpending.entries.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(', ');
    final budgetJson = budgets.entries.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(', ');

    return await _call(
      isComplex: true,
      maxTokens: 400,
      systemPrompt: 'You are a concise personal finance advisor. Give actionable insights in 3-4 bullet points. Use ₹ for currency.',
      messages: [
        {
          'role': 'user',
          'content': '''This month's finances:
Income: ₹${totalIncome.toStringAsFixed(0)}
Total spending: ₹${totalSpending.toStringAsFixed(0)}
Spending by category: $spendingJson
Budget limits: ${budgetJson.isEmpty ? 'None set' : budgetJson}

Give me key insights and one actionable tip.''',
        },
      ],
    );
  }

  Future<List<String>> detectAnomalies({
    required Map<String, double> currentMonthSpending,
    required Map<String, double> avgMonthlySpending,
  }) async {
    if (currentMonthSpending.isEmpty || avgMonthlySpending.isEmpty) return [];

    final comparison = currentMonthSpending.entries.map((e) {
      final avg = avgMonthlySpending[e.key] ?? 0;
      final pct = avg > 0 ? ((e.value - avg) / avg * 100).toStringAsFixed(0) : 'N/A';
      return '${e.key}: current ₹${e.value.toStringAsFixed(0)}, avg ₹${avg.toStringAsFixed(0)}, change: $pct%';
    }).join('\n');

    final result = await _call(
      isComplex: false,
      maxTokens: 300,
      systemPrompt: 'You are a spending anomaly detector. List only significant anomalies (>30% above average) as short bullet points. If none, say "No significant anomalies". Use ₹.',
      messages: [{'role': 'user', 'content': 'Spending comparison:\n$comparison'}],
    );
    return result.split('\n')
        .where((l) => l.trim().startsWith(RegExp(r'[•\-\*]')))
        .map((l) => l.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
        .where((l) => l.isNotEmpty).toList();
  }

  Future<List<String>> detectSubscriptions(List<Map<String, dynamic>> transactions) async {
    if (transactions.isEmpty) return [];
    final txList = transactions.take(100).map((t) =>
      '${t['note'] ?? ''} | ₹${t['amount']} | ${t['date']?.toString().substring(0, 10) ?? ''}'
    ).join('\n');

    final result = await _call(
      isComplex: false,
      maxTokens: 300,
      systemPrompt: 'Identify recurring subscription payments from transaction history. List them as bullet points with name and likely monthly cost. If none found, say "None detected".',
      messages: [{'role': 'user', 'content': 'Transactions:\n$txList'}],
    );
    return result.split('\n')
        .where((l) => l.trim().startsWith(RegExp(r'[•\-\*]')))
        .map((l) => l.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim())
        .where((l) => l.isNotEmpty).toList();
  }

  Future<String> predictCashFlow({
    required List<Map<String, dynamic>> monthlyHistory,
    required double currentBalance,
  }) async {
    final history = monthlyHistory.map((m) =>
      'Month ${m['month']}/${m['year']}: ₹${(m['total'] as num).toStringAsFixed(0)}'
    ).join(', ');

    return await _call(
      isComplex: true,
      maxTokens: 300,
      systemPrompt: 'You are a cash flow predictor. Be concise. Give a 2-3 sentence prediction with specific numbers. Use ₹.',
      messages: [
        {
          'role': 'user',
          'content': 'Current balance: ₹${currentBalance.toStringAsFixed(0)}\nMonthly spending history: $history\n\nPredict next month\'s cash flow and ending balance.',
        },
      ],
    );
  }

  Future<Map<String, double>> suggestBudgets(Map<String, double> avgCategorySpending) async {
    if (avgCategorySpending.isEmpty) return {};

    final spendingText = avgCategorySpending.entries.map((e) => '${e.key}: ₹${e.value.toStringAsFixed(0)}').join(', ');

    final result = await _call(
      isComplex: false,
      maxTokens: 400,
      systemPrompt: '''Suggest monthly budget limits as JSON. Return ONLY valid JSON object like:
{"Food": 5000, "Transport": 2000}
Suggest amounts that are slightly below average to encourage savings. No markdown, pure JSON.''',
      messages: [{'role': 'user', 'content': 'Average monthly spending by category: $spendingText\nSuggest budget limits.'}],
    );
    try {
      final cleaned = result.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return parsed.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  Future<String> chat({
    required List<Map<String, String>> messages,
    required String financialContext,
  }) async {
    return await _call(
      isComplex: true,
      maxTokens: 600,
      systemPrompt: '''You are a personal financial advisor AI named "CFO". Be friendly, concise, and actionable.
You have access to the user's financial data:
$financialContext

Answer questions about their finances, give advice, and help them understand their spending patterns.
Use ₹ for currency amounts. Keep responses under 150 words unless asked for detail.''',
      messages: messages.map((m) => {'role': m['role']!, 'content': m['content']!}).toList(),
    );
  }

  Future<String> generateMonthlySummary({
    required double income,
    required double expenses,
    required Map<String, double> categoryBreakdown,
    required double netWorth,
    required List<String> budgetAlerts,
  }) async {
    final breakdown = categoryBreakdown.entries.map((e) => '  ${e.key}: ₹${e.value.toStringAsFixed(0)}').join('\n');

    return await _call(
      isComplex: true,
      maxTokens: 500,
      systemPrompt: 'Generate a brief, encouraging monthly financial summary report. Use bullet points. Be positive but honest about overspending. Use ₹.',
      messages: [
        {
          'role': 'user',
          'content': '''Monthly Data:
Income: ₹${income.toStringAsFixed(0)}
Expenses: ₹${expenses.toStringAsFixed(0)}
Savings: ₹${(income - expenses).toStringAsFixed(0)}
Net Worth: ₹${netWorth.toStringAsFixed(0)}
Category Breakdown:
$breakdown
Budget Alerts: ${budgetAlerts.isEmpty ? 'None' : budgetAlerts.join(', ')}

Write a monthly summary report.''',
        },
      ],
    );
  }

  /// Vision API for receipts.
  Future<Map<String, dynamic>> scanReceipt({
    required String imageBase64,
    required String mimeType,
  }) async {
    if (!isConfigured) throw Exception('API key not configured.');

    final model = _getModel(false);
    const categories = [
      'Food', 'Transport', 'Shopping', 'Bills', 'Entertainment',
      'Health', 'Travel', 'Education', 'Groceries', 'Utilities',
      'Rent', 'Insurance', 'Subscriptions', 'Personal Care', 'Other',
    ];

    final sysPrompt = '''Extract transaction details from this receipt image and return ONLY valid JSON with these exact keys:
{
  "amount": <total amount as number, no currency symbol>,
  "category": "<one of: ${categories.join(", ")}>",
  "merchant": "<store name>",
  "date": "<date in DD/MM/YYYY format, or 'Today' if unclear>",
  "note": "<brief description>"
}
No markdown, no explanation, pure JSON only.''';

    String responseText = '';

    if (provider == AiProviderType.openai) {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'max_tokens': 300,
          'messages': [
            {'role': 'system', 'content': sysPrompt},
            {'role': 'user', 'content': [
              {'type': 'text', 'text': 'Extract transaction details from this receipt.'},
              {'type': 'image_url', 'image_url': {'url': 'data:$mimeType;base64,$imageBase64'}}
            ]}
          ]
        }),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('OpenAI Error: ${response.body}');
      responseText = jsonDecode(response.body)['choices'][0]['message']['content'] as String;

    } else if (provider == AiProviderType.gemini) {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {'parts': [{'text': sysPrompt}]},
          'contents': [{
            'role': 'user',
            'parts': [
              {'text': 'Extract transaction details from this receipt.'},
              {'inlineData': {'mimeType': mimeType, 'data': imageBase64}}
            ]
          }],
          'generationConfig': {'maxOutputTokens': 300}
        }),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('Gemini Error: ${response.statusCode}');
      responseText = jsonDecode(response.body)['candidates'][0]['content']['parts'][0]['text'] as String;

    } else {
      // Claude
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'max_tokens': 300,
          'system': sysPrompt,
          'messages': [{
            'role': 'user',
            'content': [
              {'type': 'image', 'source': {'type': 'base64', 'media_type': mimeType, 'data': imageBase64}},
              {'type': 'text', 'text': 'Extract transaction details from this receipt.'}
            ]
          }]
        }),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('Claude Error: ${response.body}');
      responseText = (jsonDecode(response.body)['content'] as List).first['text'] as String;
    }

    try {
      final cleaned = responseText.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return {
        'amount': (parsed['amount'] as num?)?.toDouble() ?? 0.0,
        'category': parsed['category'] ?? 'Other',
        'merchant': parsed['merchant'] ?? '',
        'date': parsed['date'] ?? 'Today',
        'note': parsed['note'] ?? (parsed['merchant'] ?? ''),
      };
    } catch (_) {
      return {'amount': 0.0, 'category': 'Other', 'merchant': '', 'date': 'Today', 'note': ''};
    }
  }
}
