import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dialog pembayaran QRIS dengan 2 metode:
/// 1. GENERATE: Menampilkan QR Code QRIS dinamis & Barcode 1D untuk discan pelanggan.
/// 2. SCAN: Memindai QR / Barcode pelanggan (CPM / E-wallet) dengan kamera / scanner gun.
class QrisPaymentDialog extends StatefulWidget {
  final int totalAmount;
  final String customerName;
  final String itemsSummary;
  final Future<bool> Function({
    required String barcodeOrQr,
    required String methodDetail,
  }) onConfirmPayment;

  const QrisPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.customerName,
    required this.itemsSummary,
    required this.onConfirmPayment,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int totalAmount,
    required String customerName,
    required String itemsSummary,
    required Future<bool> Function({
      required String barcodeOrQr,
      required String methodDetail,
    }) onConfirmPayment,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QrisPaymentDialog(
        totalAmount: totalAmount,
        customerName: customerName,
        itemsSummary: itemsSummary,
        onConfirmPayment: onConfirmPayment,
      ),
    );
  }

  @override
  State<QrisPaymentDialog> createState() => _QrisPaymentDialogState();
}

class _QrisPaymentDialogState extends State<QrisPaymentDialog>
    with SingleTickerProviderStateMixin {
  static const Color kGreen = Color(0xFF1E874B);

  // Tab mode: 0 = Generate (Toko tampilkan), 1 = Scan (Kasir pindai)
  int _activeTab = 0;

  // Generate Mode state
  bool _useBarcode1D = false; // false = QR 2D, true = Barcode 1D
  late final String _invoiceNumber;
  late final String _qrisPayload;
  String _storeName = 'Warung Maju Jaya';
  int _countdownSeconds = 300; // 5 menit
  Timer? _countdownTimer;
  Timer? _closeTimer;
  bool _isPaymentVerified = false;
  bool _isProcessingPayment = false;

  // Scan Mode state
  late final AnimationController _laserAnimController;
  late final Animation<double> _laserAnim;
  final TextEditingController _barcodeInputCtrl = TextEditingController();
  final FocusNode _barcodeFocusNode = FocusNode();
  bool _isTorchOn = false;
  bool _isRearCamera = true;
  String? _detectedBarcode;
  String? _detectedProvider;
  bool _isScanSuccess = false;

  @override
  void initState() {
    super.initState();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final randomSuffix = (1000 + (DateTime.now().microsecond % 9000)).toString();
    _invoiceNumber = 'INV-${timestamp.substring(timestamp.length - 6)}-$randomSuffix';
    
    // Format standar QRIS Nasional (EMVCo format dinamis)
    _qrisPayload =
        '00020101021226580016ID.CO.QRIS.WWW011893600812849102480215ID10200234050303UMI'
        '51440014ID.LINKAJA.WWW011893600911002233440215'
        '520454115303360540${widget.totalAmount.toString().length}${widget.totalAmount}'
        '5802ID5916WARUNG MAJU JAYA6007JAKARTA62${_invoiceNumber.length + 4}01${_invoiceNumber.length}$_invoiceNumber'
        '6304ABCD';

    _loadStoreName();
    _startCountdown();

    // Laser Animation for Scanner Viewfinder
    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _laserAnim = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadStoreName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('store_name');
      if (name != null && name.trim().isNotEmpty && mounted) {
        setState(() => _storeName = name.trim());
      }
    } catch (_) {}
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _closeTimer?.cancel();
    _laserAnimController.dispose();
    _barcodeInputCtrl.dispose();
    _barcodeFocusNode.dispose();
    super.dispose();
  }

  String _formatRp(int value) {
    if (value <= 0) return 'Rp0';
    String s = value.toString();
    String result = '';
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result = '.$result';
      result = s[i] + result;
      count++;
    }
    return 'Rp$result';
  }

  String _formatTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Identifikasi penyedia e-wallet dari kode barcode / QR
  String _identifyProvider(String code) {
    final upper = code.toUpperCase();
    if (upper.contains('GOPAY') || upper.startsWith('9360')) return 'GoPay';
    if (upper.contains('DANA') || upper.startsWith('93600')) return 'DANA';
    if (upper.contains('OVO') || upper.startsWith('0812')) return 'OVO Cash';
    if (upper.contains('SHOPEE') || upper.startsWith('8892')) return 'ShopeePay';
    if (upper.contains('BCA') || upper.startsWith('014')) return 'BCA Mobile';
    if (upper.contains('MANDIRI') || upper.startsWith('008')) return 'Livin Mandiri';
    return 'E-Wallet CPM / QRIS';
  }

  // Trigger barcode discan
  void _onBarcodeScanned(String rawCode) {
    final code = rawCode.trim();
    if (code.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _detectedBarcode = code;
      _detectedProvider = _identifyProvider(code);
      _isScanSuccess = true;
    });
  }

  // Eksekusi penyelesaian transaksi pembayaran
  Future<void> _processFinalPayment({
    required String barcodeOrQr,
    required String methodDetail,
  }) async {
    setState(() => _isProcessingPayment = true);
    final success = await widget.onConfirmPayment(
      barcodeOrQr: barcodeOrQr,
      methodDetail: methodDetail,
    );
    if (!mounted) return;
    setState(() {
      _isProcessingPayment = false;
      _isPaymentVerified = success;
    });
    if (success) {
      HapticFeedback.heavyImpact();
      _closeTimer?.cancel();
      _closeTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.pop(context, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.92,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle pill
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),

          // Dialog Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: kGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pembayaran QRIS & Barcode',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Total Tagihan: ${_formatRp(widget.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Segmented Switcher (2 Metode: Generate vs Scan)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      index: 0,
                      icon: Icons.qr_code_rounded,
                      label: 'Tampilkan QRIS / Barcode',
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      index: 1,
                      icon: Icons.document_scanner_rounded,
                      label: 'Pindai Barcode Pelanggan',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tab Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _activeTab == 0
                  ? _buildGenerateView()
                  : _buildScannerView(),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
          if (index == 1) {
            _barcodeFocusNode.requestFocus();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: isSelected ? kGreen : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF111827) : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // METODE 1: GENERATE QRIS / BARCODE (Toko Tampilkan Kode)
  // ===========================================================================
  Widget _buildGenerateView() {
    return Column(
      children: [
        // Sub-toggle: QR Code (2D) vs Barcode (1D)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('QR Code (2D)'),
              avatar: const Icon(Icons.qr_code_2_rounded, size: 16),
              selected: !_useBarcode1D,
              selectedColor: const Color(0xFFD1F2D9),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: !_useBarcode1D ? kGreen : const Color(0xFF6B7280),
              ),
              onSelected: (val) => setState(() => _useBarcode1D = false),
            ),
            const SizedBox(width: 10),
            ChoiceChip(
              label: const Text('Barcode (1D)'),
              avatar: const Icon(Icons.line_weight_rounded, size: 16),
              selected: _useBarcode1D,
              selectedColor: const Color(0xFFD1F2D9),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _useBarcode1D ? kGreen : const Color(0xFF6B7280),
              ),
              onSelected: (val) => setState(() => _useBarcode1D = true),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // QRIS Card Container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              // QRIS Header Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E874B),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'QRIS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _storeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _countdownSeconds > 60
                          ? const Color(0xFFF3F4F6)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: _countdownSeconds > 60
                              ? const Color(0xFF4B5563)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimer(_countdownSeconds),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _countdownSeconds > 60
                                ? const Color(0xFF111827)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Visual Display: QR Code 2D or Barcode 1D
              if (!_useBarcode1D)
                _buildQrCodeWidget()
              else
                _buildBarcode1DWidget(),

              const SizedBox(height: 14),

              // Invoice & Total Amount Details
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'No. Invoice',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        Row(
                          children: [
                            Text(
                              _invoiceNumber,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _invoiceNumber));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Nomor Invoice disalin ke clipboard'),
                                    duration: Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                size: 14,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nominal Bayar',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                        Text(
                          _formatRp(widget.totalAmount),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: kGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Status Indicator Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _isPaymentVerified
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isPaymentVerified)
                      const Icon(Icons.check_circle_rounded, color: kGreen, size: 16)
                    else
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _isPaymentVerified
                          ? 'Pembayaran QRIS Berhasil Diterima!'
                          : 'Menunggu pelanggan memindai QRIS...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _isPaymentVerified ? kGreen : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action Buttons:
        // 1. "Simulasi Pelanggan Bayar" (Auto-test trigger)
        // 2. "Konfirmasi Pembayaran Manual"
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessingPayment
                    ? null
                    : () {
                        // Simulasi webhook / pelanggan scan dan bayar
                        _processFinalPayment(
                          barcodeOrQr: _invoiceNumber,
                          methodDetail: 'QRIS Dinamis ($_invoiceNumber)',
                        );
                      },
                icon: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFF2563EB)),
                label: const Text(
                  'Simulasi Bayar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isProcessingPayment
                    ? null
                    : () {
                        _processFinalPayment(
                          barcodeOrQr: _invoiceNumber,
                          methodDetail: 'QRIS Terverifikasi Manual',
                        );
                      },
                icon: _isProcessingPayment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  _isProcessingPayment ? 'Memproses...' : 'Konfirmasi Diterima',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQrCodeWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          QrImageView(
            data: _qrisPayload,
            version: QrVersions.auto,
            size: 195,
            padding: const EdgeInsets.all(4),
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F172A),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF1E293B),
            ),
          ),
          // Logo in the center of QR code
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: kGreen, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'MJ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: kGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcode1DWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: [
          CustomPaint(
            size: const Size(260, 80),
            painter: _Barcode128Painter(code: _invoiceNumber),
          ),
          const SizedBox(height: 8),
          Text(
            _invoiceNumber,
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // METODE 2: SCAN BARCODE / QR PELANGGAN (Kasir Pindai Kode)
  // ===========================================================================
  Widget _buildScannerView() {
    return Column(
      children: [
        // Camera Viewfinder Screen
        Container(
          width: double.infinity,
          height: 230,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Simulated live camera background pattern
              CustomPaint(
                painter: _CameraGridBackgroundPainter(),
              ),

              // Viewfinder overlay with corner reticles
              Center(
                child: Container(
                  width: 200,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _isScanSuccess
                          ? const Color(0xFF22C55E)
                          : Colors.white.withAlpha(120),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // 4 Corner brackets
                      ..._buildCornerBrackets(),

                      // Animated Laser Beam
                      if (!_isScanSuccess)
                        AnimatedBuilder(
                          animation: _laserAnim,
                          builder: (context, _) {
                            return Positioned(
                              top: 150 * _laserAnim.value,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF22C55E).withAlpha(180),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                      // Success badge inside reticle
                      if (_isScanSuccess)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFF22C55E),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Top camera controls (Torch & Flip)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _isScanSuccess
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isScanSuccess ? 'KODE TERDETEKSI' : 'KAMERA AKTIF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Flashlight Button
                        IconButton(
                          onPressed: () => setState(() => _isTorchOn = !_isTorchOn),
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            color: _isTorchOn ? const Color(0xFFFBBF24) : Colors.white,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(120),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Flip Camera Button
                        IconButton(
                          onPressed: () => setState(() => _isRearCamera = !_isRearCamera),
                          icon: const Icon(
                            Icons.cameraswitch_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(120),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Instruction text at bottom of camera
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isScanSuccess
                          ? 'Kode barcode berhasil dipindai'
                          : 'Arahkan kamera ke barcode / QR pelanggan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Result Card if scanned
        if (_isScanSuccess && _detectedBarcode != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_detectedProvider Terdeteksi',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF166534),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _detectedBarcode!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF15803D),
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isScanSuccess = false;
                      _detectedBarcode = null;
                      _barcodeInputCtrl.clear();
                    });
                  },
                  child: const Text('Scan Ulang', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Quick Scan Preset Buttons (Untuk simulasi / uji cepat barcode pelanggan)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Uji Cepat Barcode E-Wallet (Preset)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '1-Klik Simulasi',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('GoPay CPM', '9360081284910248', const Color(0xFF00AED6)),
                  _buildPresetChip('DANA QRIS', 'DANA-CPM-882194', const Color(0xFF118EEA)),
                  _buildPresetChip('ShopeePay', 'SHOPEEPAY-99318', const Color(0xFFEE4D2D)),
                  _buildPresetChip('OVO Cash', 'OVO-08129841234', const Color(0xFF4C3494)),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Input Manual / Hardware Barcode Scanner Gun
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcodeInputCtrl,
                focusNode: _barcodeFocusNode,
                decoration: InputDecoration(
                  hintText: 'Input barcode manual / Gun scanner...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.barcode_reader, size: 20, color: Color(0xFF6B7280)),
                  suffixIcon: _barcodeInputCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _barcodeInputCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                ),
                style: const TextStyle(fontSize: 13),
                onSubmitted: (val) => _onBarcodeScanned(val),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _barcodeInputCtrl.text.trim().isEmpty
                  ? null
                  : () => _onBarcodeScanned(_barcodeInputCtrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Pindai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Tombol Konfirmasi Pembayaran setelah Scan
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: (!_isScanSuccess || _isProcessingPayment)
                ? null
                : () {
                    _processFinalPayment(
                      barcodeOrQr: _detectedBarcode ?? 'SCAN-UNKNOWN',
                      methodDetail:
                          'QRIS/Barcode Scan (${_detectedProvider ?? 'Pelanggan'} - ${_detectedBarcode ?? ''})',
                    );
                  },
            icon: _isProcessingPayment
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 20),
            label: Text(
              _isProcessingPayment
                  ? 'Memproses Pembayaran...'
                  : _isScanSuccess
                      ? 'Proses Pembayaran (${_formatRp(widget.totalAmount)})'
                      : 'Pindai Barcode Terlebih Dahulu',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              disabledForegroundColor: const Color(0xFF94A3B8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String title, String code, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: CircleAvatar(
          backgroundColor: color,
          radius: 6,
        ),
        label: Text(title),
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
        backgroundColor: color.withAlpha(25),
        side: BorderSide(color: color.withAlpha(80)),
        onPressed: () {
          _barcodeInputCtrl.text = code;
          _onBarcodeScanned(code);
        },
      ),
    );
  }

  List<Widget> _buildCornerBrackets() {
    const size = 18.0;
    const thickness = 3.5;
    const color = Color(0xFF22C55E);

    return [
      // Top Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Top Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Bottom Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
      // Bottom Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
          ),
        ),
      ),
    ];
  }
}

/// Custom painter untuk menggambar 1D Barcode (Code-128 / Retail Barcode style)
class _Barcode128Painter extends CustomPainter {
  final String code;

  _Barcode128Painter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final random = math.Random(code.hashCode);
    double currentX = 10;
    final double maxY = size.height;

    // Guard bar awal
    canvas.drawRect(Rect.fromLTWH(currentX, 0, 2.5, maxY), paint);
    currentX += 4.5;
    canvas.drawRect(Rect.fromLTWH(currentX, 0, 2.5, maxY), paint);
    currentX += 6;

    // Modulasi baris berdasarkan karakter
    final chars = code.codeUnits;
    for (int i = 0; i < chars.length; i++) {
      final val = (chars[i] + random.nextInt(10)) % 4;
      final barWidth = (val == 0) ? 1.5 : (val == 1) ? 2.5 : (val == 2) ? 4.0 : 5.5;
      final gap = 2.0 + (random.nextInt(3) * 1.5);

      if (currentX + barWidth > size.width - 20) break;

      canvas.drawRect(Rect.fromLTWH(currentX, 0, barWidth, maxY), paint);
      currentX += barWidth + gap;
    }

    // Guard bar akhir
    canvas.drawRect(Rect.fromLTWH(size.width - 15, 0, 2.5, maxY), paint);
    canvas.drawRect(Rect.fromLTWH(size.width - 10, 0, 2.5, maxY), paint);
  }

  @override
  bool shouldRepaint(covariant _Barcode128Painter oldDelegate) =>
      oldDelegate.code != code;
}

/// Custom painter untuk pola grid kamera latar belakang
class _CameraGridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF090D16);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final linePaint = Paint()
      ..color = Colors.white.withAlpha(10)
      ..strokeWidth = 1;

    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

