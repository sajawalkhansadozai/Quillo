import 'package:flutter/material.dart';

import '../models/generated_recipe.dart';
import '../services/recipe_rating_service.dart';

/// Community rating pill for hero images and recipe cards.
class RecipeRatingBadge extends StatefulWidget {
  final GeneratedRecipe recipe;
  final Color accentColor;
  final bool compact;

  const RecipeRatingBadge({
    super.key,
    required this.recipe,
    required this.accentColor,
    this.compact = false,
  });

  @override
  State<RecipeRatingBadge> createState() => _RecipeRatingBadgeState();
}

class _RecipeRatingBadgeState extends State<RecipeRatingBadge> {
  RecipeRatingSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    RecipeRatingService.summaryRevision.addListener(_onRevision);
    _load();
  }

  @override
  void didUpdateWidget(covariant RecipeRatingBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (RecipeRatingService.cacheKeyFor(oldWidget.recipe) !=
        RecipeRatingService.cacheKeyFor(widget.recipe)) {
      _load();
    }
  }

  @override
  void dispose() {
    RecipeRatingService.summaryRevision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => _load();

  Future<void> _load() async {
    final summary = await RecipeRatingService.getSummary(widget.recipe);
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  static String _formatAverage(double value) {
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _summary == null || !_summary!.hasRatings) {
      return const SizedBox.shrink();
    }

    final compact = widget.compact;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 12,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(compact ? 10 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: compact ? 11 : 14,
            color: widget.accentColor,
          ),
          SizedBox(width: compact ? 2 : 4),
          Text(
            _formatAverage(_summary!.averageRating),
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          if (!compact)
            Text(
              ' · ${_summary!.ratingCount}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }
}
