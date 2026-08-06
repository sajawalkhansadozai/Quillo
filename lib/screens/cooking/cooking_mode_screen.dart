import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/generated_recipe.dart';
import '../../theme/app_theme.dart';
import '../../services/recipe_rating_service.dart';
import '../../services/recipe_service.dart';
import '../../widgets/recipe_rating_section.dart';
import '../../widgets/recipe_rating_sheet.dart';
import '../../widgets/recipe_thumbnail_image.dart';

enum _Phase { prep, steps, complete }

/// Step-by-step cooking mode with optional prep checklist and per-step timers.
class CookingModeScreen extends StatefulWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    required this.accentColor,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen> {
  _Phase _phase = _Phase.prep;
  int _stepIndex = 0;
  final Set<int> _preppedIngredients = {};
  late GeneratedRecipe _recipe;
  bool _ratingPromptShown = false;
  int? _userRating;
  bool _imageUpgrading = false;

  Timer? _countdown;
  int? _timerSecondsLeft;
  bool _timerRunning = false;

  Color get _color => widget.accentColor;
  List<RecipeStep> get _steps => _recipe.steps;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _refreshUserRating();
    unawaited(_upgradeHeroImage());
  }

  Future<void> _upgradeHeroImage() async {
    if (!RecipeService.needsGeminiImageUpgrade(_recipe)) return;
    setState(() => _imageUpgrading = true);
    await RecipeService.upgradeRecipeImagesInBackground(
      recipes: [_recipe],
      shouldContinue: () => mounted,
      onUpdated: (old, updated) {
        if (!mounted) return;
        setState(() {
          _recipe = updated;
          _imageUpgrading = false;
        });
      },
      onFinished: (_) {
        if (!mounted) return;
        setState(() => _imageUpgrading = false);
      },
    );
  }

  Future<void> _refreshUserRating() async {
    final rating = await RecipeRatingService.getRating(_recipe);
    if (!mounted) return;
    setState(() => _userRating = rating);
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  List<({String name, String amount})> get _allIngredients {
    final items = <({String name, String amount})>[];
    final seen = <String>{};
    for (final i in _recipe.ingredientsUsed) {
      final key = i.name.toLowerCase();
      if (seen.add(key)) items.add((name: i.name, amount: i.amount));
    }
    for (final i in _recipe.missingIngredients) {
      final key = i.name.toLowerCase();
      if (seen.add(key)) items.add((name: i.name, amount: i.amount));
    }
    return items;
  }

  RecipeStep? get _currentStep =>
      _steps.isEmpty || _stepIndex >= _steps.length ? null : _steps[_stepIndex];

  bool get _hasTimerOnCurrentStep {
    final step = _currentStep;
    return step?.durationMinutes != null && step!.durationMinutes! > 0;
  }

  void _beginSteps() {
    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This recipe has no cooking steps yet.')),
      );
      return;
    }
    setState(() {
      _phase = _Phase.steps;
      _stepIndex = 0;
      _resetTimer();
    });
  }

  void _resetTimer() {
    _countdown?.cancel();
    _timerSecondsLeft = null;
    _timerRunning = false;
  }

  void _startTimer() {
    final mins = _currentStep?.durationMinutes;
    if (mins == null || mins <= 0) return;

    _countdown?.cancel();
    setState(() {
      _timerSecondsLeft = mins * 60;
      _timerRunning = true;
    });

    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timerSecondsLeft == null || _timerSecondsLeft! <= 1) {
        t.cancel();
        setState(() {
          _timerSecondsLeft = 0;
          _timerRunning = false;
        });
        HapticFeedback.heavyImpact();
        _showTimerDoneDialog();
        return;
      }
      setState(() => _timerSecondsLeft = _timerSecondsLeft! - 1);
    });
  }

  void _pauseTimer() {
    _countdown?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resumeTimer() {
    if (_timerSecondsLeft == null || _timerSecondsLeft! <= 0) return;
    _countdown?.cancel();
    setState(() => _timerRunning = true);
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_timerSecondsLeft == null || _timerSecondsLeft! <= 1) {
        t.cancel();
        setState(() {
          _timerSecondsLeft = 0;
          _timerRunning = false;
        });
        HapticFeedback.heavyImpact();
        _showTimerDoneDialog();
        return;
      }
      setState(() => _timerSecondsLeft = _timerSecondsLeft! - 1);
    });
  }

  void _showTimerDoneDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Time's up!"),
        content: Text(
          _stepIndex < _steps.length - 1
              ? 'Ready for the next step?'
              : 'You finished the last timed step.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay here'),
          ),
          if (_stepIndex < _steps.length - 1)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _nextStep();
              },
              child: const Text('Next step'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    if (_phase == _Phase.complete) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave cooking mode?'),
        content: const Text('Your progress on this session will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep cooking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  void _nextStep() {
    _resetTimer();
    if (_stepIndex >= _steps.length - 1) {
      setState(() => _phase = _Phase.complete);
      HapticFeedback.mediumImpact();
      _scheduleRatingPrompt();
      return;
    }
    setState(() => _stepIndex++);
    HapticFeedback.selectionClick();
  }

  Future<void> _scheduleRatingPrompt() async {
    if (_ratingPromptShown) return;
    _ratingPromptShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted || _phase != _Phase.complete) return;
    final existing = await RecipeRatingService.getRating(_recipe);
    if (!mounted || existing != null) return;
    final result = await showRecipeRatingSheet(
      context,
      recipe: _recipe,
      accentColor: _color,
    );
    if (!mounted || result == null) return;
    setState(() {
      _recipe = result.recipe;
      _userRating = result.rating;
    });
  }

  void _prevStep() {
    if (_stepIndex <= 0) return;
    _resetTimer();
    setState(() => _stepIndex--);
    HapticFeedback.selectionClick();
  }

  static (String title, String body) _stepParts(RecipeStep step) {
    final text = step.instruction.trim();
    final dot = text.indexOf('.');
    if (dot > 0 && dot < 55) {
      return (text.substring(0, dot), text.substring(dot + 1).trim());
    }
    return ('Step ${step.order}', text);
  }

  String _formatTimer(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textDark),
            onPressed: _confirmExit,
          ),
          title: Text(
            _recipe.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: switch (_phase) {
          _Phase.prep => _buildPrep(),
          _Phase.steps => _buildSteps(),
          _Phase.complete => _buildComplete(),
        },
      ),
    );
  }

  Widget _buildPrep() {
    final ingredients = _allIngredients;
    final allChecked =
        ingredients.isEmpty || _preppedIngredients.length >= ingredients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 160,
              child: RecipeThumbnailImage(
                imageUrl: _recipe.imageUrl,
                emoji: '👨‍🍳',
                placeholderColor: _color,
                isImageUpgrading: _imageUpgrading,
                cacheWidth: 960,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            'Get everything ready',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Text(
            ingredients.isEmpty
                ? 'Review the steps, then start cooking.'
                : 'Check off ingredients as you gather them.',
            style: const TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.4),
          ),
        ),
        if (ingredients.isNotEmpty)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: ingredients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final item = ingredients[i];
                final checked = _preppedIngredients.contains(i);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (checked) {
                        _preppedIngredients.remove(i);
                      } else {
                        _preppedIngredients.add(i);
                      }
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: checked
                            ? _color.withValues(alpha: 0.5)
                            : AppColors.chipBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: checked ? _color : const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: checked ? _color : const Color(0xFFE0E0E0),
                            ),
                          ),
                          child: checked
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: checked
                                      ? AppColors.textLight
                                      : AppColors.textDark,
                                  decoration:
                                      checked ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (item.amount.isNotEmpty)
                                Text(
                                  item.amount,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        else
          const Spacer(),
        _bottomBar(
          primaryLabel: allChecked && ingredients.isNotEmpty
              ? 'Begin cooking'
              : ingredients.isEmpty
                  ? 'Start steps'
                  : 'Begin anyway',
          onPrimary: _beginSteps,
          showBack: false,
        ),
      ],
    );
  }

  Widget _buildSteps() {
    final step = _currentStep!;
    final (title, body) = _stepParts(step);
    final progress = (_stepIndex + 1) / _steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Step ${_stepIndex + 1} of ${_steps.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMedium,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: _color.withValues(alpha: 0.15),
                  color: _color,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      '${step.order}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                    height: 1.2,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.textMedium,
                      height: 1.55,
                    ),
                  ),
                ],
                if (_hasTimerOnCurrentStep) ...[
                  const SizedBox(height: 28),
                  _buildTimerCard(),
                ],
              ],
            ),
          ),
        ),
        _bottomBar(
          primaryLabel:
              _stepIndex >= _steps.length - 1 ? 'Finish cooking' : 'Next step',
          onPrimary: _nextStep,
          showBack: _stepIndex > 0,
          onBack: _prevStep,
          showTimerButton: _hasTimerOnCurrentStep,
        ),
      ],
    );
  }

  Widget _buildTimerCard() {
    final active = _timerSecondsLeft != null;
    final display = active
        ? _formatTimer(_timerSecondsLeft!)
        : '${_currentStep!.durationMinutes} min';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.timer_outlined, color: _color, size: 28),
          const SizedBox(height: 8),
          Text(
            active ? display : 'Timer · $display',
            style: TextStyle(
              fontSize: active ? 36 : 18,
              fontWeight: FontWeight.w900,
              color: _color,
              fontFamily: 'Nunito',
              fontFeatures: active ? [const FontFeature.tabularFigures()] : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!active)
                _TimerActionBtn(
                  label: 'Start timer',
                  icon: Icons.play_arrow_rounded,
                  color: _color,
                  onTap: _startTimer,
                )
              else ...[
                _TimerActionBtn(
                  label: _timerRunning ? 'Pause' : 'Resume',
                  icon: _timerRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: _color,
                  onTap: _timerRunning ? _pauseTimer : _resumeTimer,
                ),
                const SizedBox(width: 12),
                _TimerActionBtn(
                  label: 'Reset',
                  icon: Icons.refresh_rounded,
                  color: AppColors.textMedium,
                  onTap: () {
                    _resetTimer();
                    setState(() {});
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComplete() {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.restaurant_rounded, color: _color, size: 44),
        ),
        const SizedBox(height: 24),
        const Text(
          'Nice work!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontFamily: 'Nunito',
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'You finished cooking ${_recipe.title}. Enjoy your meal!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_userRating == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: RecipeRatingSection(
              recipe: _recipe,
              accentColor: _color,
              showCommunitySummary: false,
              onRated: (result) => setState(() {
                _recipe = result.recipe;
                _userRating = result.rating;
              }),
            ),
          )
        else
          TextButton(
            onPressed: () async {
              final result = await showRecipeRatingSheet(
                context,
                recipe: _recipe,
                accentColor: _color,
                isEdit: true,
              );
              if (!mounted || result == null) return;
              setState(() {
                _recipe = result.recipe;
                _userRating = result.rating;
              });
            },
            child: Text(
              'Change your rating',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _color,
              ),
            ),
          ),
        const Spacer(),
        _bottomBar(
          primaryLabel: 'Back to recipe',
          onPrimary: () => Navigator.pop(context),
          showBack: false,
        ),
      ],
    );
  }

  Widget _bottomBar({
    required String primaryLabel,
    required VoidCallback onPrimary,
    bool primaryEnabled = true,
    bool showBack = false,
    VoidCallback? onBack,
    bool showTimerButton = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showTimerButton)
            GestureDetector(
              onTap: () {
                if (_timerSecondsLeft == null) {
                  _startTimer();
                } else if (_timerRunning) {
                  _pauseTimer();
                } else {
                  _resumeTimer();
                }
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _timerRunning || _timerSecondsLeft != null
                      ? _color.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _timerRunning ? _color : AppColors.chipBorder,
                  ),
                ),
                child: Icon(
                  _timerRunning
                      ? Icons.pause_rounded
                      : Icons.timer_outlined,
                  color: _timerRunning ? _color : AppColors.textDark,
                  size: 22,
                ),
              ),
            ),
          if (showTimerButton) const SizedBox(width: 12),
          if (showBack) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.chipBorder),
                ),
                child: const Center(
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: primaryEnabled ? onPrimary : null,
              child: Opacity(
                opacity: primaryEnabled ? 1 : 0.45,
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_color, _color.withValues(alpha: 0.72)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'Nunito',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TimerActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
