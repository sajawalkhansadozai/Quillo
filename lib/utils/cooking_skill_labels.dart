/// Maps onboarding / profile skill labels to a canonical DB value.
class CookingSkillLabels {
  CookingSkillLabels._();

  static const beginner = 'Beginner';
  static const intermediate = 'Intermediate';
  static const advanced = 'Advanced';
  static const expert = 'Expert';

  static const profileOptions = [beginner, intermediate, advanced, expert];

  /// Onboarding titles → profile/DB titles.
  static String normalize(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'beginner':
        return beginner;
      case 'home cook':
      case 'intermediate':
        return intermediate;
      case 'confident cook':
      case 'confident':
      case 'advanced':
        return advanced;
      case 'pro chef':
      case 'expert':
        return expert;
      default:
        return intermediate;
    }
  }
}
