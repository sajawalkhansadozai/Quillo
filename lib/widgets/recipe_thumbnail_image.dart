import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/recipe_image_source.dart';

/// Cached recipe thumbnail that fills its parent.
///
/// Every child is positioned so the widget reports no intrinsic size — callers
/// inside an `IntrinsicHeight` row are sized by their text, not by the decoded
/// image dimensions.
class RecipeThumbnailImage extends StatefulWidget {
  final String? imageUrl;
  final String emoji;
  final Color placeholderColor;
  final bool isImageUpgrading;
  final int cacheWidth;

  const RecipeThumbnailImage({
    super.key,
    required this.imageUrl,
    required this.emoji,
    required this.placeholderColor,
    this.isImageUpgrading = false,
    this.cacheWidth = 480,
  });

  @override
  State<RecipeThumbnailImage> createState() => _RecipeThumbnailImageState();
}

class _RecipeThumbnailImageState extends State<RecipeThumbnailImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = resizedRecipeImageUrl(widget.imageUrl, width: widget.cacheWidth);
    final showUpgradeOverlay = widget.isImageUpgrading;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Positioned.fill(
            child: CachedNetworkImage(
              key: ValueKey(url),
              imageUrl: url,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              memCacheWidth: widget.cacheWidth,
              fadeInDuration: const Duration(milliseconds: 250),
              placeholder: (_, __) => _greenPulseSkeleton(),
              errorWidget: (_, __, ___) => _greenPulseSkeleton(),
            ),
          )
        else
          Positioned.fill(
            child: _greenPulseSkeleton(),
          ),
        if (showUpgradeOverlay)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    return Container(
                      color: AppColors.green.withValues(
                        alpha: 0.18 + (_pulse.value * 0.18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _greenPulseSkeleton() {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = _pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.green.withValues(alpha: 0.18 + t * 0.22),
                AppColors.primary.withValues(alpha: 0.12 + (1 - t) * 0.18),
                AppColors.green.withValues(alpha: 0.20 + (1 - t) * 0.15),
              ],
            ),
          ),
        );
      },
    );
  }
}
