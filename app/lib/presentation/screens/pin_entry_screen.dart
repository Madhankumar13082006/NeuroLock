import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PinEntryDialog extends StatefulWidget {
  final String title;
  const PinEntryDialog({super.key, required this.title});
  @override
  State<PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<PinEntryDialog> {
  String _pin = '';

  void _onKey(String key) {
    if (_pin.length < 4) {
      setState(() => _pin += key);
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          Navigator.of(context).pop(_pin);
        });
      }
    }
  }

  void _delete() {
    if (_pin.isNotEmpty)
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_rounded,
                size: 30, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 17)),
          const SizedBox(height: 24),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                4,
                (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? AppTheme.primary
                            : AppTheme.cardBorder,
                        border: Border.all(
                            color: i < _pin.length
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                            width: 1.5),
                      ),
                    )),
          ),
          const SizedBox(height: 28),
          // Keypad
          ...['1 2 3', '4 5 6', '7 8 9', '  0 ⌫'].map((row) {
            final keys = row.split(' ');
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: keys.map((k) {
                if (k.isEmpty) return const SizedBox(width: 72);
                return GestureDetector(
                  onTap: () => k == '⌫' ? _delete() : _onKey(k),
                  child: Container(
                    width: 72,
                    height: 56,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: k == '⌫'
                          ? AppTheme.danger.withValues(alpha: 0.1)
                          : AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: k == '⌫'
                            ? AppTheme.danger.withValues(alpha: 0.35)
                            : AppTheme.cardBorder,
                      ),
                    ),
                    child: Text(k,
                        style: TextStyle(
                            color: k == '⌫'
                                ? AppTheme.danger
                                : AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
        ]),
      ),
    );
  }
}
