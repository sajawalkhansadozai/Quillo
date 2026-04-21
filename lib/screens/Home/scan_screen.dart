import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scan states
// ─────────────────────────────────────────────────────────────────────────────

enum _ScanState { idle, processing, success, error }

// ─────────────────────────────────────────────────────────────────────────────
// ScanScreen
// ─────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  _ScanState _state = _ScanState.idle;

  // Scan line animation
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  // Processing step animation
  late AnimationController _stepCtrl;
  int _completedSteps = 0;
  Timer? _stepTimer;

  // Overlay card slide-in animation
  late AnimationController _cardCtrl;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;

  final _processingSteps = [
    'Image captured',
    'Analysing text...',
    'Identifying ingredients...',
    'Generating recipes...',
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _scanLineCtrl = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanLineAnim = CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut);

    _stepCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _cardCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _scanLineCtrl.dispose();
    _stepCtrl.dispose();
    _cardCtrl.dispose();
    _stepTimer?.cancel();
    super.dispose();
  }

  void _onShutter() {
    if (_state != _ScanState.idle) return;
    setState(() {
      _state = _ScanState.processing;
      _completedSteps = 0;
    });
    _cardCtrl.forward(from: 0);
    _simulateProcessing();
  }

  void _simulateProcessing() {
    int step = 0;
    _stepTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      step++;
      setState(() => _completedSteps = step);
      if (step >= _processingSteps.length) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          // 70% chance success, 30% error (for demo)
          final success = DateTime.now().millisecondsSinceEpoch % 10 < 7;
          _cardCtrl.reverse().then((_) {
            if (!mounted) return;
            setState(() => _state = success ? _ScanState.success : _ScanState.error);
            _cardCtrl.forward(from: 0);
          });
        });
      }
    });
  }

  void _reset() {
    _stepTimer?.cancel();
    _cardCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _state = _ScanState.idle;
        _completedSteps = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: Stack(
        children: [
          // Camera background simulation
          _CameraBackground(),

          // Safe area content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildViewfinder()),
                _buildBottomBar(),
              ],
            ),
          ),

          // State overlay
          if (_state != _ScanState.idle)
            _buildStateOverlay(),
        ],
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
          _DarkCircleBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Nunito', letterSpacing: 1),
              children: [
                TextSpan(text: 'QUILL', style: TextStyle(color: Colors.white)),
                TextSpan(text: 'O', style: TextStyle(color: Color(0xFF6C63FF))),
              ],
            ),
          ),
          _DarkCircleBtn(
            icon: Icons.bolt_rounded,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  // ── Viewfinder ──────────────────────────────────────────────────────────────

  Widget _buildViewfinder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 280,
            height: 200,
            child: Stack(
              children: [
                // Corner brackets
                const _CornerBrackets(),
                // Animated scan line (only when idle)
                if (_state == _ScanState.idle)
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (_, __) {
                      final y = 10 + (_scanLineAnim.value * 180);
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Text(
                'Align receipt within the frame',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  // ── Bottom bar ──────────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final isActive = _state == _ScanState.idle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 16, 40, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Gallery button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.4,
            child: GestureDetector(
              onTap: isActive ? () {} : null,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
              ),
            ),
          ),
          // Shutter button
          GestureDetector(
            onTap: _onShutter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
            ),
          ),
          // Quillo text button
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isActive ? 1.0 : 0.4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Text(
                'Library',
                style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── State overlay ────────────────────────────────────────────────────────────

  Widget _buildStateOverlay() {
    return Positioned(
      left: 24,
      right: 24,
      top: 0,
      bottom: 0,
      child: Center(
        child: FadeTransition(
          opacity: _cardFade,
          child: SlideTransition(
            position: _cardSlide,
            child: switch (_state) {
              _ScanState.processing => _ProcessingCard(
                  steps: _processingSteps,
                  completedSteps: _completedSteps,
                ),
              _ScanState.success => _SuccessCard(
                  ingredientCount: 12,
                  onContinue: () => Navigator.of(context).pop(),
                ),
              _ScanState.error => _ErrorCard(
                  onTryAgain: _reset,
                  onUpload: () {},
                ),
              _ScanState.idle => const SizedBox(),
            },
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
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.receipt_long_rounded, color: Color(0xFF6C63FF), size: 28),
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
            'Hang tight. This will only take a few\nseconds for your ingredients',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5),
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
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                        : active
                            ? const _PulsingDot()
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    steps[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: done ? FontWeight.w700 : FontWeight.w400,
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
// Success card
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  final int ingredientCount;
  final VoidCallback onContinue;
  const _SuccessCard({required this.ingredientCount, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF4CAF50), size: 32),
          ),
          const SizedBox(height: 18),
          const Text(
            'Receipt scanned!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito'),
          ),
          const SizedBox(height: 6),
          Text(
            'Found $ingredientCount ingredients',
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onContinue,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'View Recipes',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error card
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final VoidCallback onTryAgain;
  final VoidCallback onUpload;
  const _ErrorCard({required this.onTryAgain, required this.onUpload});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4), width: 2),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800), size: 28),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              "Couldn't read receipt",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Nunito'),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              "The image was a bit blurry or out of frame.\nLet's give it another shot!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ErrorTip('Make sure the receipt is fully and fully visible'),
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
                      child: Text('Try Again', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Center(
                      child: Text(
                        'Upload instead',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6), height: 1.4),
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
  @override
  Widget build(BuildContext context) {
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
    return CustomPaint(
      painter: _BracketPainter(),
      child: const SizedBox.expand(),
    );
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
    final r = 8.0;

    void drawCorner(Offset origin, bool flipX, bool flipY) {
      final dx = flipX ? -1.0 : 1.0;
      final dy = flipY ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(origin.dx + dx * len, origin.dy)
        ..lineTo(origin.dx + dx * r, origin.dy)
        ..arcToPoint(
          Offset(origin.dx, origin.dy + dy * r),
          radius: Radius.circular(r),
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
// Animated scan line
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
            Color(0xFF6C63FF),
            Color(0xFFAA9FFF),
            Color(0xFF6C63FF),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.8),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing dot for active step
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this)
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
            color: const Color(0xFF6C63FF).withValues(alpha: 0.5 + _ctrl.value * 0.5),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark circle button
// ─────────────────────────────────────────────────────────────────────────────

class _DarkCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DarkCircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
