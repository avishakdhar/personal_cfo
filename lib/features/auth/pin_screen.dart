import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/app_providers.dart';

String _hashPin(String pin) {
  final bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

// ─── PIN SETUP SCREEN ─────────────────────────────────────────────────────────

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String _error = '';

  void _onDigit(String digit) {
    setState(() {
      _error = '';
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) _isConfirming = true;
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) _validateAndSave();
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = '';
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _validateAndSave() async {
    if (_pin != _confirmPin) {
      setState(() {
        _error = 'PINs do not match. Try again.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin_hash', _hashPin(_pin));
    await ref.read(pinEnabledProvider.notifier).setEnabled(true);
    ref.read(isAuthenticatedProvider.notifier).state = true;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final current = _isConfirming ? _confirmPin : _pin;
    return Scaffold(
      appBar: AppBar(title: Text(_isConfirming ? 'Confirm PIN' : 'Set PIN')),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            _isConfirming ? 'Re-enter your PIN' : 'Enter a 4-digit PIN',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => _PinDot(filled: i < current.length)),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_error, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 40),
          _Keypad(onDigit: _onDigit, onDelete: _onDelete),
        ],
      ),
    );
  }
}

// ─── PIN LOCK SCREEN ─────────────────────────────────────────────────────────

class PinLockScreen extends ConsumerStatefulWidget {
  const PinLockScreen({super.key});

  @override
  ConsumerState<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends ConsumerState<PinLockScreen> {
  String _pin = '';
  String _error = '';
  int _attempts = 0;

  void _onDigit(String digit) {
    setState(() {
      _error = '';
      if (_pin.length < 4) {
        _pin += digit;
        if (_pin.length == 4) _validatePin();
      }
    });
  }

  void _onDelete() {
    setState(() {
      if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      _error = '';
    });
  }

  Future<void> _validatePin() async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString('pin_hash') ?? '';
    if (_hashPin(_pin) == storedHash) {
      ref.read(isAuthenticatedProvider.notifier).state = true;
    } else {
      _attempts++;
      setState(() {
        _error = 'Incorrect PIN. ${3 - _attempts} attempts left.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(Icons.lock_outline, size: 60),
            const SizedBox(height: 16),
            Text('Enter PIN', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _PinDot(filled: i < _pin.length)),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 40),
            _Keypad(onDigit: _onDigit, onDelete: _onDelete),
          ],
        ),
      ),
    );
  }
}

// ─── SHARED WIDGETS ───────────────────────────────────────────────────────────

class _PinDot extends StatelessWidget {
  final bool filled;
  const _PinDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Theme.of(context).colorScheme.primary : Colors.transparent,
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onDelete;

  const _Keypad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final digits = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 60),
      childAspectRatio: 1.5,
      children: digits.map((d) {
        if (d.isEmpty) return const SizedBox();
        if (d == '⌫') {
          return IconButton(
            icon: const Icon(Icons.backspace_outlined, size: 24),
            onPressed: onDelete,
          );
        }
        return TextButton(
          onPressed: () => onDigit(d),
          child: Text(d, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
        );
      }).toList(),
    );
  }
}
