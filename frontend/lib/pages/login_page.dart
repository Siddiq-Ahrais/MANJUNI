import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

/// Halaman kunci PIN keamanan (atau sambutan cepat saat PIN belum diatur).
/// Autentikasi email & password telah dihapus untuk mode 100% offline.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const Color kGreen = Color(0xFF1E874B);
  final TextEditingController _pinCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _unlockWithPin() {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan PIN keamanan terlebih dahulu!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final ok = ApiService.verifySecurityPin(pin);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN keamanan yang dimasukkan salah!'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _enterWithoutPin() async {
    await ApiService.loginOfflineGuest();
  }

  void _showForgotPinDialog() {
    final name1Ctrl = TextEditingController();
    final name2Ctrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Opsi Lupa Password / PIN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'PIN tidak dapat di-recovery. Masukkan Nama Keamanan 1 dan Nama Keamanan 2 (hanya huruf dan angka) untuk membuka kembali aplikasi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nama Keamanan 1',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: name1Ctrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Ketik Nama Keamanan 1',
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.verified_user_outlined,
                          color: kGreen,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Nama Keamanan 2',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: name2Ctrl,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      ],
                      decoration: InputDecoration(
                        hintText: 'Ketik Nama Keamanan 2',
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.shield_outlined,
                          color: kGreen,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    const Text(
                      'PIN Baru (Opsional — isi jika ingin langsung mengganti PIN)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: newPinCtrl,
                      obscureText: obscureNew,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'Kosongkan jika hanya ingin membuka aplikasi',
                        isDense: true,
                        prefixIcon: const Icon(Icons.pin_outlined, color: kGreen, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                            color: Colors.grey,
                          ),
                          onPressed: () =>
                              setModalState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Konfirmasi PIN Baru (Opsional)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmPinCtrl,
                      obscureText: obscureConfirm,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: 'Masukkan PIN baru yang sama',
                        isDense: true,
                        prefixIcon: const Icon(
                          Icons.lock_reset_rounded,
                          color: kGreen,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                            color: Colors.grey,
                          ),
                          onPressed: () => setModalState(
                            () => obscureConfirm = !obscureConfirm,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        final res = await ApiService.unlockWithSecurityNames(
                          name1: name1Ctrl.text,
                          name2: name2Ctrl.text,
                          newPin: newPinCtrl.text,
                          confirmPin: confirmPinCtrl.text,
                        );
                        if (res['success'] != true) {
                          setModalState(() {
                            errorMessage = res['message']?.toString();
                          });
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Buka Aplikasi dengan Nama Keamanan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPin = ApiService.hasSecurityPin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x221E874B),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          hasPin ? Icons.lock_rounded : Icons.storefront_rounded,
                          color: kGreen,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(
                  child: Text(
                    'MANJUNI POS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    hasPin
                        ? 'Masukkan PIN keamanan untuk membuka aplikasi'
                        : 'Aplikasi Kasir 100% Offline Tanpa Login Password',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF0F0F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: hasPin
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PIN Keamanan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _pinCtrl,
                              obscureText: _obscure,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onSubmitted: (_) => _unlockWithPin(),
                              decoration: InputDecoration(
                                hintText: 'Masukkan PIN Anda',
                                prefixIcon: const Icon(
                                  Icons.pin_outlined,
                                  color: kGreen,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: _unlockWithPin,
                              icon: const Icon(Icons.lock_open_rounded, size: 20),
                              label: const Text(
                                'Buka dengan PIN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: _showForgotPinDialog,
                                child: const Text(
                                  'Lupa Password? Buka dengan Nama Keamanan',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: kGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Akses Cepat Mode Offline',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Anda dapat langsung menggunakan aplikasi tanpa login password, atau mengatur PIN keamanan melalui menu Profil.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF6B7280),
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _enterWithoutPin,
                              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                              label: const Text(
                                'Masuk ke Aplikasi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Mode Offline Aktif \u2022 Data Tersimpan di Perangkat',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
