import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/providers/app_providers.dart';
import '../transactions/add_expense_screen.dart';

class ReceiptScanScreen extends ConsumerStatefulWidget {
  const ReceiptScanScreen({super.key});

  @override
  ConsumerState<ReceiptScanScreen> createState() => _ReceiptScanScreenState();
}

class _ReceiptScanScreenState extends ConsumerState<ReceiptScanScreen> {
  File? _image;
  bool _scanning = false;
  Map<String, dynamic>? _extracted;
  String? _error;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _extracted = null;
        _error = null;
      });
      await _scanReceipt();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _scanReceipt() async {
    if (_image == null) return;

    final apiKey = ref.read(apiKeyProvider);
    if (apiKey.isEmpty) {
      setState(() => _error = 'API key not set. Go to Settings to configure Claude API key.');
      return;
    }

    setState(() { _scanning = true; _error = null; });

    try {
      final bytes = await _image!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final extracted = await ref.read(aiServiceProvider).scanReceipt(
        imageBase64: base64Image,
        mimeType: _getMimeType(_image!.path),
      );

      if (mounted) setState(() { _extracted = extracted; _scanning = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _scanning = false; });
    }
  }

  String _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  void _useExtracted() {
    if (_extracted == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          prefillAmount: (_extracted!['amount'] as num?)?.toDouble(),
          prefillCategory: _extracted!['category'] as String?,
          prefillNote: _extracted!['note'] as String?,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final apiKey = ref.watch(apiKeyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // API key warning
            if (apiKey.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withAlpha(77)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Claude API key not set. Receipt scanning requires AI. Go to Settings.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Image preview or placeholder
            GestureDetector(
              onTap: () => _showSourceDialog(),
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: cs.outline.withAlpha(77),
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: cs.outline),
                          const SizedBox(height: 12),
                          Text('Tap to take/select a receipt photo',
                              style: TextStyle(color: cs.outline)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    onPressed: _scanning ? null : () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    onPressed: _scanning ? null : () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scanning indicator
            if (_scanning)
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Analyzing receipt with AI...',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ),

            // Error
            if (_error != null)
              Card(
                color: Colors.red.withAlpha(26),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              ),

            // Extracted data
            if (_extracted != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text('Receipt Extracted',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const Divider(height: 20),
                      _ExtractedRow(
                        icon: Icons.currency_rupee,
                        label: 'Amount',
                        value: '₹${NumberFormat('#,##,##0.##', 'en_IN').format((_extracted!['amount'] as num?)?.toDouble() ?? 0)}',
                      ),
                      _ExtractedRow(
                        icon: Icons.category_outlined,
                        label: 'Category',
                        value: _extracted!['category'] as String? ?? 'Other',
                      ),
                      _ExtractedRow(
                        icon: Icons.store_outlined,
                        label: 'Merchant',
                        value: _extracted!['merchant'] as String? ?? '—',
                      ),
                      _ExtractedRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: _extracted!['date'] as String? ?? 'Today',
                      ),
                      if ((_extracted!['note'] as String?)?.isNotEmpty == true)
                        _ExtractedRow(
                          icon: Icons.notes_outlined,
                          label: 'Note',
                          value: _extracted!['note'] as String,
                        ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Add as Expense'),
                        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        onPressed: _useExtracted,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Info card
            Card(
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const SizedBox(height: 6),
                    Text(
                      '1. Take a photo or select from gallery\n'
                      '2. AI extracts amount, category, merchant & date\n'
                      '3. Review the data and add as expense\n'
                      '4. Works with bills, restaurant receipts & store slips',
                      style: TextStyle(fontSize: 12, color: cs.outline, height: 1.6),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ExtractedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ExtractedRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      );
}
