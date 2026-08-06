enum RecipeImageSource {
  gemini,
  edamam,
  otherProvider,
}

/// Detects whether a recipe hero image is Gemini-hosted or from an external API.
RecipeImageSource? recipeImageSource(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return null;

  final lower = imageUrl.toLowerCase();
  if (lower.contains('/recipe-images/')) return RecipeImageSource.gemini;
  if (lower.contains('edamam')) return RecipeImageSource.edamam;
  if (lower.contains('spoonacular') ||
      lower.contains('bigoven') ||
      lower.contains('themealdb')) {
    return RecipeImageSource.otherProvider;
  }
  return null;
}

String recipeImageSourceLabel(RecipeImageSource source) {
  switch (source) {
    case RecipeImageSource.gemini:
      return 'AI';
    case RecipeImageSource.edamam:
      return 'Edamam';
    case RecipeImageSource.otherProvider:
      return 'API';
  }
}

/// Returns a smaller, compressed variant of an app-hosted recipe image using
/// Supabase Storage image transformations. External provider URLs (Edamam etc.)
/// are returned unchanged. [width] is the target render width in pixels.
String? resizedRecipeImageUrl(String? imageUrl, {int width = 480, int quality = 70}) {
  if (imageUrl == null || imageUrl.isEmpty) return imageUrl;
  // Only transform our own Supabase-hosted images.
  const objectMarker = '/storage/v1/object/public/recipe-images/';
  if (!imageUrl.contains(objectMarker)) return imageUrl;
  // Already a render URL — leave as is.
  if (imageUrl.contains('/storage/v1/render/image/public/')) return imageUrl;

  final base = imageUrl
      .split('?')
      .first
      .replaceFirst(
        '/storage/v1/object/public/',
        '/storage/v1/render/image/public/',
      );
  return '$base?width=$width&quality=$quality&format=webp';
}

bool needsGeminiRecipeImage(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return true;
  // Any app-hosted AI image is acceptable (skip re-upgrading legacy v1 paths).
  if (imageUrl.contains('/recipe-images/')) return false;
  return true;
}

final RegExp _supabaseUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

/// True when [value] is a Supabase `recipes.id` UUID (not a provider-prefixed id).
bool isSupabaseRecipeId(String? value) =>
    value != null && value.isNotEmpty && _supabaseUuidPattern.hasMatch(value);

/// Maps provider-prefixed ids (`edamam_…`) to `(source, sourceId)`.
({String source, String sourceId})? parsePrefixedProviderId(String value) {
  for (final entry in [
    ('edamam_', 'edamam'),
    ('bigoven_', 'bigoven'),
    ('spoon_', 'spoonacular'),
  ]) {
    if (value.startsWith(entry.$1)) {
      final raw = value.substring(entry.$1.length);
      if (raw.isNotEmpty) return (source: entry.$2, sourceId: raw);
    }
  }
  return null;
}

String recipeImageTrackKey({
  String? id,
  String? externalSource,
  String? externalId,
  required String title,
}) {
  if (isSupabaseRecipeId(id)) return 'id:$id';
  if (externalSource != null &&
      externalId != null &&
      externalId.isNotEmpty) {
    return '$externalSource:$externalId';
  }
  return 'title:${title.trim().toLowerCase()}';
}
