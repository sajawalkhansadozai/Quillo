import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/generated_recipe.dart';
import '../services/recipe_rating_service.dart';
import '../theme/app_theme.dart';

/// Inline star rating row for recipe detail and cooking complete screens.
class RecipeRatingSection extends StatefulWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;
  final bool compact;
  final bool showCommunitySummary;
  final ValueChanged<RecipeRatingResult>? onRated;

  const RecipeRatingSection({
    super.key,
    required this.recipe,
    required this.accentColor,
    this.compact = false,
    this.showCommunitySummary = true,
    this.onRated,
  });

  @override
  State<RecipeRatingSection> createState() => _RecipeRatingSectionState();
}

class _RecipeRatingSectionState extends State<RecipeRatingSection> {
  int? _rating;
  RecipeRatingSummary? _summary;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecipeRatingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (RecipeRatingService.cacheKeyFor(oldWidget.recipe) !=
        RecipeRatingService.cacheKeyFor(widget.recipe)) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      RecipeRatingService.getRating(widget.recipe),
      if (widget.showCommunitySummary && !widget.compact)
        RecipeRatingService.getSummary(widget.recipe)
      else
        Future<RecipeRatingSummary?>.value(null),
    ]);
    if (!mounted) return;
    setState(() {
      _rating = results[0] as int?;
      _summary = results.length > 1 ? results[1] as RecipeRatingSummary? : null;
      _loading = false;
    });
  }

  Future<void> _setRating(int stars) async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
    try {
      final result =
          await RecipeRatingService.setRating(widget.recipe, stars);
      if (!mounted) return;
      setState(() {
        _rating = result.rating;
        _saving = false;
      });
      widget.onRated?.call(result);
      if (widget.showCommunitySummary && !widget.compact) {
        final summary = await RecipeRatingService.getSummary(result.recipe);
        if (mounted) setState(() => _summary = summary);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your rating. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildStars(starSize: 36);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_summary?.hasRatings == true) ...[
            Row(
              children: [
                Icon(Icons.star_rounded, size: 18, color: widget.accentColor),
                const SizedBox(width: 4),
                Text(
                  _summary!.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.chipBorder),
            const SizedBox(height: 12),
          ],
          const Text(
            'Rate this recipe',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _rating == null
                ? 'How was it? Tap a star to share your feedback'
                : 'You rated this $_rating star${_rating == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMedium,
            ),
          ),
          const SizedBox(height: 10),
          _buildStars(starSize: 32),
        ],
      ),
    );
  }

  Widget _buildStars({required double starSize}) {
    if (_loading) {
      return SizedBox(
        height: starSize,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment:
          widget.compact ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: List.generate(5, (i) {
        final star = i + 1;
        final filled = (_rating ?? 0) >= star;
        return Padding(
          padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
          child: GestureDetector(
            onTap: _saving ? null : () => _setRating(star),
            child: Opacity(
              opacity: _saving ? 0.5 : 1,
              child: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: starSize,
                color: filled ? widget.accentColor : AppColors.textLight,
              ),
            ),
          ),
        );
      }),
    );
  }
}
