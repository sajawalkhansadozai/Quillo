import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/scan_service.dart';
import '../../services/scan_limit_service.dart';
import '../../services/analytics_service.dart';
import '../../services/crash_reporting_service.dart';
import '../../utils/app_settings_launcher.dart';
import '../../widgets/scan_limit_sheet.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/scan_usage_banner.dart';
import '../scan/ingredient_review_screen.dart';
import '../scan/receipt_preview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scan states
// ─────────────────────────────────────────────────────────────────────────────

enum _ScanState { idle, processing, error }

// ─────────────────────────────────────────────────────────────────────────────
// ScanScreen
// ─────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  _ScanState _state = _ScanState.idle;
  String? _errorMessage;

  // Camera
  CameraController? _cameraCtrl;
  bool _cameraReady = false;
  bool _cameraPermissionDenied = false;
  bool _flashOn = false;
  bool _isCapturing = false;

  // Scan line animation
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  // Processing step animation
  int _completedSteps = 0;

  // Overlay card slide-in animation
  late AnimationController _cardCtrl;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  // Step ticker for visual feedback
  Timer? _stepTimer;

  final _processingSteps = [
    'Image captured',
    'Uploading to server...',
    'Reading your receipt...',
    'Identifying ingredients...',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _scanLineCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _scanLineAnim = CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut);

    _cardCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));

    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _cameraPermissionDenied) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final status = await requestCameraPermission();
      if (!status.isGranted) {
        if (!mounted) return;
        setState(() {
          _cameraPermissionDenied = true;
          _cameraReady = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraPermissionDenied = true;
          _cameraReady = false;
        });
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _cameraCtrl = ctrl;
        _cameraReady = true;
        _cameraPermissionDenied = false;
      });
    } on CameraException catch (e) {
      debugPrint('Camera init failed: ${e.code} ${e.description}');
      if (!mounted) return;
      setState(() {
        _cameraPermissionDenied = true;
        _cameraReady = false;
      });
    } catch (e) {
      debugPrint('Camera init failed: $e');
      if (!mounted) return;
      setState(() {
        _cameraPermissionDenied = true;
        _cameraReady = false;
      });
    }
  }

  Future<void> _openCameraSettings() async {
    final opened = await openSystemAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open Settings → Quillo → enable Camera so we can photograph receipts.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _scanLineCtrl.dispose();
    _cardCtrl.dispose();
    _stepTimer?.cancel();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  // ── Shutter: capture in-place from live preview ─────────────────────────────

  Future<void> _onShutter() async {
    if (_state != _ScanState.idle || _isCapturing) return;
    if (!await _checkLimit()) return;

    final ctrl = _cameraCtrl;
    if (ctrl == null || !_cameraReady || !ctrl.value.isInitialized) {
      if (mounted) {
        if (_cameraPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Camera access is required to photograph receipts. Enable it in Settings.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Camera is still starting — please wait a moment.')),
          );
        }
      }
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final file = await ctrl.takePicture();
      await _openPreviewThenScan(file);
    } catch (_) {
      if (mounted) {
        _showError('Could not capture photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final ctrl = _cameraCtrl;
    if (ctrl == null || !_cameraReady || !ctrl.value.isInitialized) return;
    final next = _flashOn ? FlashMode.off : FlashMode.torch;
    try {
      await ctrl.setFlashMode(next);
      if (mounted) setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  // ── Gallery: pick existing photo ────────────────────────────────────────────

  Future<void> _onGallery() async {
    if (_state != _ScanState.idle) return;
    if (!await _checkLimit()) return;
    final file = await ScanService.pickFromGallery();
    if (file == null) return;
    await _openPreviewThenScan(file);
  }

  /// Brightness preview (§04) — Retake returns null and stays on camera.
  Future<void> _openPreviewThenScan(XFile file) async {
    if (!mounted) return;
    final prepared = await Navigator.of(context).push<XFile?>(
      MaterialPageRoute(
        builder: (_) => ReceiptPreviewScreen(imageFile: file),
      ),
    );
    if (prepared == null || !mounted) return;
    await _processScan(prepared);
  }

  // ── Daily limit gate ─────────────────────────────────────────────────────────

  Future<bool> _checkLimit() async {
    final allowed = await ScanLimitService.canScan();
    if (!allowed && mounted) {
      await showScanLimitSheet(context);
    }
    return allowed;
  }

  // ── Core pipeline ───────────────────────────────────────────────────────────

  Future<void> _processScan(XFile file) async {
    setState(() {
      _state = _ScanState.processing;
      _completedSteps = 0;
    });
    _cardCtrl.forward(from: 0);
    _startStepTicker();

    try {
      final result = await ScanService.runScan(file).timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw const ScanException(
            'Scan is taking too long — please check your connection and try again.'),
      );

      _stepTimer?.cancel();
      if (!mounted) return;

      // Partial / empty: still open review so user can add ingredients (§06).
      // Credit only when server says so (≥3 food items) (§05).
      if (result.isPartial || result.ingredients.length < 3) {
        await CrashReportingService.capture(
          StateError('partial_ocr'),
          context: 'ocr_partial',
          extras: {
            'ingredient_count': result.ingredients.length,
            'best_pass': result.bestPass ?? 0,
            'credit_consumed': result.creditConsumed,
            'width': result.meta?['width'] ?? 0,
            'height': result.meta?['height'] ?? 0,
            'mean_brightness': result.meta?['meanBrightness'] ?? 0,
          },
        );
      }

      if (result.creditConsumed) {
        await ScanLimitService.recordScan();
        await AnalyticsService.capture(AnalyticsService.scannedReceipt);
      }

      await _cardCtrl.reverse();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IngredientReviewScreen(
            scanId: result.scanId,
            ingredients: result.ingredients,
            receiptAlreadyCounted: result.creditConsumed,
            isPartial: result.isPartial || result.ingredients.length < 3,
            partialMessage: result.message,
          ),
        ),
      );
    } on RateLimitException catch (e) {
      _showError(e.message);
    } on ScanException catch (e) {
      await CrashReportingService.capture(e, context: 'ocr_failure');
      _showError(
        '${e.message}\n\nThis scan did not use one of your credits.',
      );
    } catch (e, st) {
      await CrashReportingService.capture(
        e,
        stackTrace: st,
        context: 'ocr_failure',
      );
      _showError(
        'We could not read this receipt. Try placing it flat in better lighting.\n\n'
        'This scan did not use one of your credits.',
      );
    }
  }

  void _startStepTicker() {
    int step = 0;
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      if (step < _processingSteps.length) {
        setState(() => _completedSteps = step);
      } else {
        timer.cancel();
      }
    });
  }

  void _showError(String message) {
    _stepTimer?.cancel();
    _cardCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.error;
        _errorMessage = message;
        _completedSteps = 0;
      });
      _cardCtrl.forward(from: 0);
    });
  }

  void _reset() {
    _stepTimer?.cancel();
    _cardCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.idle;
        _errorMessage = null;
        _completedSteps = 0;
      });
    });
  }

  Future<void> _openManualEntry() async {
    if (!await _checkLimit()) return;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const IngredientReviewScreen(
          scanId: '',
          ingredients: [],
          receiptAlreadyCounted: false,
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      bottomNavigationBar: const AdBannerWidget(),
      body: Stack(
        children: [
          _CameraBackground(controller: _cameraReady ? _cameraCtrl : null),
          if (_cameraReady)
            const Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const ScanUsageBanner(),
                Expanded(
                  child: _cameraPermissionDenied
                      ? _buildCameraPermissionCard()
                      : _buildViewfinder(),
                ),
                _buildBottomBar(),
              ],
            ),
          ),
          if (_state != _ScanState.idle) _buildStateOverlay(),
        ],
      ),
    );
  }

  Widget _buildCameraPermissionCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_camera_outlined,
                  color: Color(0xFFFFC107), size: 40),
              const SizedBox(height: 14),
              const Text(
                'Camera access needed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Quillo needs the camera to photograph your receipt and find recipes from the ingredients. Enable Camera in Settings, then return here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openCameraSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _initCamera,
                child: Text(
                  'I enabled Camera — try again',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'You can still pick a receipt from your gallery below.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ScanToolbarButton(
            onTap: () => Navigator.of(context).pop(),
            child: const CustomPaint(
              size: Size(20, 20),
              painter: _BackArrowPainter(),
            ),
          ),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                letterSpacing: 1,
              ),
              children: [
                TextSpan(text: 'QUILL', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'O', style: TextStyle(color: Color(0xFFFFC107))),
              ],
            ),
          ),
          _ScanToolbarButton(
            onTap: _toggleFlash,
            active: _flashOn,
            child: CustomPaint(
              size: const Size(18, 22),
              painter: _FlashIconPainter(
                color: _flashOn ? Colors.white : Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Viewfinder ──────────────────────────────────────────────────────────────

  static const double _viewfinderWidth = 260;
  static const double _viewfinderHeight = 360;

  Widget _buildViewfinder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_state == _ScanState.idle) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: const [
                  _CameraTip('Place the receipt on a dark flat surface'),
                  SizedBox(height: 6),
                  _CameraTip('Avoid shadows and direct sunlight'),
                  SizedBox(height: 6),
                  _CameraTip('Hold your phone directly above the receipt'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: _viewfinderWidth,
            height: _viewfinderHeight,
            child: Stack(
              children: [
                const _CornerBrackets(),
                if (_state == _ScanState.idle)
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (_, __) {
                      final y = 10 +
                          (_scanLineAnim.value * (_viewfinderHeight - 20));
                      return Positioned(
                        left: 16,
                        right: 16,
                        top: y,
                        child: _ScanLine(),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_state == _ScanState.idle)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4DA3FF),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Align receipt within the frame',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isActive = _state == _ScanState.idle && !_isCapturing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.4,
            child: GestureDetector(
              onTap: isActive ? _onGallery : null,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8DCC8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF5C5348), size: 26),
              ),
            ),
          ),
          GestureDetector(
            onTap: isActive ? _onShutter : null,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isActive ? 1.0 : 0.45,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF2A2A38),
                    ),
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, color: Colors.black, size: 14),
                  SizedBox(width: 6),
                  Text(
                    'AUTO',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── State overlay ────────────────────────────────────────────────────────────

  Widget _buildStateOverlay() {
    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
              position: _cardSlide,
              child: switch (_state) {
                _ScanState.processing => _ProcessingCard(
                    steps: _processingSteps,
                    completedSteps: _completedSteps,
                  ),
                _ScanState.error => _ErrorCard(
                    message: _errorMessage,
                    onTryAgain: _reset,
                    onUpload: _onGallery,
                    onAddManually: _openManualEntry,
                  ),
                _ScanState.idle => const SizedBox(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Processing card
// ─────────────────────────────────────────────────────────────────────────────

class _ProcessingCard extends StatelessWidget {
  final List<String> steps;
  final int completedSteps;
  const _ProcessingCard({required this.steps, required this.completedSteps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.receipt_long_rounded,
                  color: Color(0xFF6C63FF), size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Reading your receipt...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hang tight. This will only take a few seconds.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.5),
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            final done = i < completedSteps;
            final active = i == completedSteps;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: done
                          ? const Color(0xFF4CAF50)
                          : active
                              ? const Color(0xFF6C63FF).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 13)
                        : active
                            ? const _PulsingDot()
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          done ? FontWeight.w700 : FontWeight.w400,
                      color: done
                          ? Colors.white
                          : active
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error card
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String? message;
  final VoidCallback onTryAgain;
  final VoidCallback onUpload;
  final VoidCallback onAddManually;
  const _ErrorCard({
    this.message,
    required this.onTryAgain,
    required this.onUpload,
    required this.onAddManually,
  });

  @override
  Widget build(BuildContext context) {
    final isRateLimit = message?.toLowerCase().contains('limit') ?? false;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9800).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.4),
                  width: 2),
            ),
            child: const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFF9800), size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            "Couldn't read receipt",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamily: 'Nunito'),
          ),
          const SizedBox(height: 8),
          Text(
            message ??
                "We could not read this receipt. Try placing it flat in better lighting, or add ingredients manually.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5),
          ),
          const SizedBox(height: 20),
          if (!isRateLimit) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  _ErrorTip('Make sure the receipt is fully visible'),
                  _ErrorTip('Hold the camera steady in good lighting'),
                  _ErrorTip('Avoid shadows or glare on the paper'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTryAgain,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('Try Again',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onUpload,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Center(
                        child: Text(
                          'Upload instead',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onAddManually,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.55)),
                  color: const Color(0xFFFFC107).withValues(alpha: 0.12),
                ),
                child: const Center(
                  child: Text(
                    'Add ingredients manually',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFC107),
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onTryAgain,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text('Got it',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorTip extends StatelessWidget {
  final String text;
  const _ErrorTip(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 4,
            height: 4,
            decoration: const BoxDecoration(
              color: Color(0xFFFF9800),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraTip extends StatelessWidget {
  final String text;
  const _CameraTip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: 14, color: Colors.white.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera background
// ─────────────────────────────────────────────────────────────────────────────

class _CameraBackground extends StatelessWidget {
  final CameraController? controller;
  const _CameraBackground({this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller != null && controller!.value.isInitialized) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller!.value.previewSize!.height,
            height: controller!.value.previewSize!.width,
            child: CameraPreview(controller!),
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.2,
          colors: [Color(0xFF12122A), Color(0xFF07070F)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Corner brackets
// ─────────────────────────────────────────────────────────────────────────────

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BracketPainter(), child: const SizedBox.expand());
  }
}

class _BracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const len = 24.0;
    const r = 8.0;

    void drawCorner(Offset origin, bool flipX, bool flipY) {
      final dx = flipX ? -1.0 : 1.0;
      final dy = flipY ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(origin.dx + dx * len, origin.dy)
        ..lineTo(origin.dx + dx * r, origin.dy)
        ..arcToPoint(
          Offset(origin.dx, origin.dy + dy * r),
          radius: const Radius.circular(r),
          clockwise: !(flipX ^ flipY),
        )
        ..lineTo(origin.dx, origin.dy + dy * len);
      canvas.drawPath(path, paint);
    }

    drawCorner(Offset.zero, false, false);
    drawCorner(Offset(size.width, 0), true, false);
    drawCorner(Offset(0, size.height), false, true);
    drawCorner(Offset(size.width, size.height), true, true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan line
// ─────────────────────────────────────────────────────────────────────────────

class _ScanLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Colors.transparent,
            Color(0xFF4DA3FF),
            Color(0xFF8CC4FF),
            Color(0xFF4DA3FF),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DA3FF).withValues(alpha: 0.8),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Center(
        child: Container(
          width: 6 + _ctrl.value * 4,
          height: 6 + _ctrl.value * 4,
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF)
                .withValues(alpha: 0.5 + _ctrl.value * 0.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewfinder grid
// ─────────────────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.5;

    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan toolbar buttons (matches design squircles)
// ─────────────────────────────────────────────────────────────────────────────

class _ScanToolbarButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final bool active;

  const _ScanToolbarButton({
    required this.onTap,
    required this.child,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF35373D) : const Color(0xFF2C2E33),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3A3D44), width: 1),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _BackArrowPainter extends CustomPainter {
  const _BackArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final tip = Offset(cx - 5, cy);
    canvas.drawLine(Offset(cx + 1, cy - 6), tip, paint);
    canvas.drawLine(tip, Offset(cx + 1, cy + 6), paint);
    canvas.drawLine(tip, Offset(cx + 7, cy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _FlashIconPainter extends CustomPainter {
  final Color color;
  const _FlashIconPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.54, h * 0.08)
      ..lineTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.34, h * 0.94)
      ..lineTo(w * 0.72, h * 0.38)
      ..lineTo(w * 0.52, h * 0.38);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlashIconPainter old) => old.color != color;
}
