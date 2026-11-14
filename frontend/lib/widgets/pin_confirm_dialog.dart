import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// Meminta verifikasi PIN keamanan sebelum mengeksekusi aksi destruktif.
/// Apabila PIN keamanan belum diatur ([ApiService.hasSecurityPin] == false),
/// langsung mengembalikan `true` tanpa menampilkan dialog tambahan.
Future<bool> confirmSecurityPinForAction(
  BuildContext context, {
  required String actionTitle,
  String? actionDescription,
}) async {
  if (!ApiService.hasSecurityPin) return true;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PinConfirmAlertDialog(
      actionTitle: actionTitle,
      actionDescription: actionDescription,
    ),
  );
  return result == true;
}

class _PinConfirmAlertDialog extends StatefulWidget {
  final String actionTitle;
  final String? actionDescription;

  const _PinConfirmAlertDialog({
    required this.actionTitle,
    this.actionDescription,
  });

  @override
  State<_PinConfirmAlertDialog> createState() => _PinConfirmAlertDialogState();
}

class _PinConfirmAlertDialogState extends State<_PinConfirmAlertDialog> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Masukkan PIN keamanan terlebih dahulu!');
      return;
    }
    setState(() => _submitting = true);
    final res = await ApiService.verifySecurityPinDetailed(
      pin,
      unlockSession: false,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _submitting = false;
      _errorMessage = (res['message'] ?? 'PIN keamanan salah!').toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFFEF4444), size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.actionTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.actionDescription ??
                'Masukkan PIN keamanan saat ini untuk mengonfirmasi tindakan ini.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('confirm_action_pin_field'),
            controller: _pinCtrl,
            obscureText: _obscure,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Masukkan PIN keamanan',
              isDense: true,
              prefixIcon: const Icon(Icons.pin_outlined, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context, false),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          key: const Key('confirm_action_pin_submit'),
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Verifikasi & Lanjutkan'),
        ),
      ],
    );
  }
}
