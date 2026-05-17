import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quillo_button.dart';
import 'skill_level_screen.dart';

class PreferencesScreen extends StatefulWidget {
  /// When provided, the screen runs in "edit mode":
  /// — pre-fills selections from these lists
  /// — calls [onSaved] with (dietary, cuisines) instead of navigating to SkillLevelScreen
  final List<String>? initialDietary;
  final List<String>? initialCuisines;
  final void Function(List<String> dietary, List<String> cuisines)? onSaved;

  const PreferencesScreen({
    super.key,
    this.initialDietary,
    this.initialCuisines,
    this.onSaved,
  });

  bool get isEditMode => onSaved != null;

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  late final Set<String> _selectedDietary;
  late final Set<String> _selectedLifestyle;
  late final Set<String> _selectedCuisines;

  /// Derived from [_lifestyleChips] — splits combined `dietary_labels` from the DB.
  static final Set<String> _lifestyleLabels = {
    for (final c in _lifestyleChips) c.label,
  };

  static const List<_ChipData> _lifestyleChips = [
    _ChipData(label: 'Low-carb', emoji: '🥩', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Keto', emoji: '🧈', color: Color(0xFFF5F5F5)),
    _ChipData(label: 'Paleo', emoji: '🍖', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'Whole30', emoji: '📅', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Raw food', emoji: '🥑', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Mediterranean', emoji: '🫒', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Sugar-free', emoji: '🍬', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'High-protein', emoji: '💪', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'High-fibre', emoji: '🌾', color: Color(0xFFF1F8E9)),
    _ChipData(label: 'Low-sodium', emoji: '🧂', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Calorie-conscious', emoji: '⚖️', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Anti-inflammatory', emoji: '🫐', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Carnivore', emoji: '🥓', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Intermittent fasting', emoji: '⏱️', color: Color(0xFFECEFF1)),
    _ChipData(label: 'DASH diet', emoji: '🥬', color: Color(0xFFE8F5E9)),
  ];

  @override
  void initState() {
    super.initState();
    final allDietary = widget.initialDietary ?? [];
    _selectedDietary = allDietary.where((l) => !_lifestyleLabels.contains(l)).toSet();
    _selectedLifestyle = allDietary.where((l) => _lifestyleLabels.contains(l)).toSet();
    _selectedCuisines = (widget.initialCuisines ?? []).toSet();
  }

  // Each chip has a unique pastel background colour
  final List<_ChipData> _dietaryOptions = const [
    _ChipData(label: 'Vegan', emoji: '🌱', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Vegetarian', emoji: '🥬', color: Color(0xFFE8F8F0)),
    _ChipData(label: 'Pescatarian', emoji: '🐟', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Flexitarian', emoji: '🥗', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Halal', emoji: '🕌', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Kosher', emoji: '🕎', color: Color(0xFFFFFDE7)),
    _ChipData(label: 'Gluten-free', emoji: '🌾', color: Color(0xFFFBE9E7)),
    _ChipData(label: 'Wheat-free', emoji: '🍞', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Dairy-free', emoji: '🥛', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Lactose-free', emoji: '🧀', color: Color(0xFFF1F8E9)),
    _ChipData(label: 'Egg-free', emoji: '🥚', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Nut-free', emoji: '🛡️', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Peanut-free', emoji: '🫘', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Tree nut-free', emoji: '🌰', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'Soy-free', emoji: '🫛', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Sesame-free', emoji: '🌿', color: Color(0xFFF1F8E9)),
    _ChipData(label: 'Shellfish-free', emoji: '🦐', color: Color(0xFFE0F2F1)),
    _ChipData(label: 'Fish-free', emoji: '🐠', color: Color(0xFFE1F5FE)),
    _ChipData(label: 'No alcohol', emoji: '🚫', color: Color(0xFFF5F5F5)),
    _ChipData(label: 'No red meat', emoji: '🥩', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'No pork', emoji: '🐖', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Low FODMAP', emoji: '🥒', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Diabetic-friendly', emoji: '🩺', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Heart-healthy', emoji: '❤️', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Organic-first', emoji: '🌿', color: Color(0xFFE8F5E9)),
  ];

  final List<_ChipData> _cuisineOptions = const [
    _ChipData(label: 'Italian', emoji: '🍝', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'French', emoji: '🥐', color: Color(0xFFE8F8F0)),
    _ChipData(label: 'Spanish', emoji: '🥘', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Greek', emoji: '🫕', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Turkish', emoji: '🥙', color: Color(0xFFFBE9E7)),
    _ChipData(label: 'Lebanese', emoji: '🧆', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Middle Eastern', emoji: '🫓', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Moroccan', emoji: '🍲', color: Color(0xFFFFE0B2)),
    _ChipData(label: 'Persian', emoji: '🍚', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Indian', emoji: '🍛', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Pakistani', emoji: '🍛', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Bangladeshi', emoji: '🍛', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Thai', emoji: '🍜', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Vietnamese', emoji: '🍜', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Chinese', emoji: '🥡', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Japanese', emoji: '🍱', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'Korean', emoji: '🍲', color: Color(0xFFE8F8F0)),
    _ChipData(label: 'Indonesian', emoji: '🍛', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Malaysian', emoji: '🍜', color: Color(0xFFE0F2F1)),
    _ChipData(label: 'Filipino', emoji: '🍚', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Singaporean', emoji: '🦀', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Mexican', emoji: '🌮', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Tex-Mex', emoji: '🌯', color: Color(0xFFFFE0B2)),
    _ChipData(label: 'Caribbean', emoji: '🥥', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Brazilian', emoji: '🥩', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Peruvian', emoji: '🦙', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Argentinian', emoji: '🥩', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'American', emoji: '🍔', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Southern US', emoji: '🍗', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Cajun / Creole', emoji: '🦞', color: Color(0xFFFFE0B2)),
    _ChipData(label: 'British', emoji: '🫖', color: Color(0xFFECEFF1)),
    _ChipData(label: 'Irish', emoji: '🥔', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'German', emoji: '🥨', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Scandinavian', emoji: '🐟', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Polish', emoji: '🥟', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Russian', emoji: '🥣', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Hungarian', emoji: '🍲', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Ethiopian', emoji: '🫓', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'West African', emoji: '🍚', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'South African', emoji: '🥩', color: Color(0xFFFBE9E7)),
    _ChipData(label: 'Australian', emoji: '🦘', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Fusion', emoji: '✨', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'International', emoji: '🌍', color: Color(0xFFE3F2FD)),
  ];

  int get _totalSelected =>
      _selectedDietary.length + _selectedLifestyle.length + _selectedCuisines.length;

  Future<void> _saveAndContinue() async {
    if (widget.isEditMode) {
      // Edit mode: return selections via callback and pop
      widget.onSaved!(
        [..._selectedDietary, ..._selectedLifestyle],
        _selectedCuisines.toList(),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // Onboarding mode: save to SharedPreferences and go to next step
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'onboarding_dietary', [..._selectedDietary, ..._selectedLifestyle]);
    await prefs.setStringList('onboarding_cuisines', _selectedCuisines.toList());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SkillLevelScreen()),
    );
  }

  void _skipToNext() {
    if (widget.isEditMode) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SkillLevelScreen()),
    );
  }

  void _toggle(Set<String> set, String label) =>
      setState(() => set.contains(label) ? set.remove(label) : set.add(label));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top nav ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  _CircleBack(onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  if (!widget.isEditMode) _StepPill(label: '• Step 4 of 5'),
                  if (widget.isEditMode)
                    const Text('Edit Preferences',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                            color: AppColors.textDark, fontFamily: 'Nunito')),
                  const Spacer(),
                  TextButton(
                    onPressed: _skipToNext,
                    child: Text(widget.isEditMode ? 'Cancel' : 'Skip',
                        style: const TextStyle(fontSize: 14, color: AppColors.textMedium,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Eyebrow ────────────────────────────────────────
                    Row(children: [
                      Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('PERSONALISE YOUR EXPERIENCE',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: AppColors.textLight, letterSpacing: 1.2)),
                      ),
                      Expanded(child: Divider(color: AppColors.divider, thickness: 1)),
                    ]),
                    const SizedBox(height: 10),
                    // ── Title ──────────────────────────────────────────
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontFamily: 'Nunito'),
                        children: [
                          TextSpan(
                            text: 'Your ',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                                color: AppColors.textDark),
                          ),
                          TextSpan(
                            text: 'Preference',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
                                color: AppColors.primary),
                          ),
                          TextSpan(text: ' 🥦', style: TextStyle(fontSize: 26)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select all that apply. QUILLO will tailor every recipe and\nsuggestion just for you.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5),
                    ),
                    const SizedBox(height: 16),

                    // ── Selection summary bar ──────────────────────────
                    _SelectionBar(totalSelected: _totalSelected),
                    const SizedBox(height: 24),

                    // ── Dietary Restrictions ───────────────────────────
                    _SectionLabel(label: 'DIETARY RESTRICTIONS'),
                    const SizedBox(height: 12),
                    _TwoColGrid(
                      items: _dietaryOptions,
                      selected: _selectedDietary,
                      onToggle: (l) => _toggle(_selectedDietary, l),
                    ),
                    const SizedBox(height: 24),

                    // ── Health & Lifestyle ─────────────────────────────
                    _SectionLabel(label: 'HEALTH & LIFESTYLE'),
                    const SizedBox(height: 12),
                    _TwoColGrid(
                      items: _lifestyleChips,
                      selected: _selectedLifestyle,
                      onToggle: (l) => _toggle(_selectedLifestyle, l),
                    ),
                    const SizedBox(height: 24),

                    // ── Favourite Cuisines ─────────────────────────────
                    _SectionLabel(label: 'FAVOURITE CUISINES'),
                    const SizedBox(height: 12),
                    _TwoColGrid(
                      items: _cuisineOptions,
                      selected: _selectedCuisines,
                      onToggle: (l) => _toggle(_selectedCuisines, l),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Bottom buttons ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                children: [
                  QuilloButton(
                    label: widget.isEditMode ? '✓  Save Preferences' : '→  Continue',
                    onTap: _saveAndContinue,
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                  ),
                  if (!widget.isEditMode) ...[
                    const SizedBox(height: 12),
                    QuilloButton(
                      label: 'Skip for now',
                      onTap: _skipToNext,
                      backgroundColor: AppColors.textDark,
                      textColor: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection summary bar
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  final int totalSelected;
  const _SelectionBar({required this.totalSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.chipBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: totalSelected > 0 ? AppColors.primaryLight : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              totalSelected > 0 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: totalSelected > 0 ? AppColors.primary : AppColors.textLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              totalSelected == 0 ? 'Nothing selected yet' : '$totalSelected item${totalSelected == 1 ? '' : 's'} selected',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: totalSelected > 0 ? AppColors.textDark : AppColors.textLight,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: totalSelected > 0 ? AppColors.primaryLight : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalSelected selected',
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: totalSelected > 0 ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label with side dividers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800,
        color: AppColors.textLight, letterSpacing: 1.2,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Two-column grid of selectable chips
// ─────────────────────────────────────────────────────────────────────────────

class _TwoColGrid extends StatelessWidget {
  final List<_ChipData> items;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _TwoColGrid({required this.items, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Build rows of 2
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: _PastelChip(
                  data: items[i],
                  isSelected: selected.contains(items[i].label),
                  onTap: () => onToggle(items[i].label),
                ),
              ),
              const SizedBox(width: 10),
              if (i + 1 < items.length)
                Expanded(
                  child: _PastelChip(
                    data: items[i + 1],
                    isSelected: selected.contains(items[i + 1].label),
                    onTap: () => onToggle(items[i + 1].label),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pastel selectable chip
// ─────────────────────────────────────────────────────────────────────────────

class _PastelChip extends StatelessWidget {
  final _ChipData data;
  final bool isSelected;
  final VoidCallback onTap;
  const _PastelChip({required this.data, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : data.color,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? AppColors.primary : data.color.withValues(alpha: 0.0),
            width: 2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                data.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ChipData {
  final String label;
  final String emoji;
  final Color color;
  const _ChipData({required this.label, required this.emoji, required this.color});
}

class _CircleBack extends StatelessWidget {
  final VoidCallback onTap;
  const _CircleBack({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textDark),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  const _StepPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }
}
