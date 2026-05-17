import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../theme/preference_chip_icons.dart';
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
    _ChipData(label: 'Low-carb', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Keto', color: Color(0xFFF5F5F5)),
    _ChipData(label: 'Paleo', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'Whole30', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Raw food', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Mediterranean', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Sugar-free', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'High-protein', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'High-fibre', color: Color(0xFFF1F8E9)),
    _ChipData(label: 'Low-sodium', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Calorie-conscious', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Anti-inflammatory', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Carnivore', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Intermittent fasting', color: Color(0xFFECEFF1)),
    _ChipData(label: 'DASH diet', color: Color(0xFFE8F5E9)),
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
    _ChipData(label: 'Vegan', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Vegetarian', color: Color(0xFFE8F8F0)),
    _ChipData(label: 'Pescatarian', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Flexitarian', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Halal', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Kosher', color: Color(0xFFFFFDE7)),
    _ChipData(label: 'Gluten-free', color: Color(0xFFFBE9E7)),
    _ChipData(label: 'Wheat-free', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Dairy-free', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Lactose-free', color: Color(0xFFF1F8E9)),
    _ChipData(label: 'Egg-free', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Nut-free', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Peanut-free', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Tree nut-free', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'Soy-free', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Sesame-free', color: Color(0xFFF1F8E9)),
    _ChipData(label: 'Shellfish-free', color: Color(0xFFE0F2F1)),
    _ChipData(label: 'Fish-free', color: Color(0xFFE1F5FE)),
    _ChipData(label: 'No alcohol', color: Color(0xFFF5F5F5)),
    _ChipData(label: 'No red meat', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'No pork', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Low FODMAP', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Diabetic-friendly', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Heart-healthy', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Organic-first', color: Color(0xFFE8F5E9)),
  ];

  final List<_ChipData> _cuisineOptions = const [
    _ChipData(label: 'Italian', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'French', color: Color(0xFFE8F8F0)),
    _ChipData(label: 'Spanish', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Greek', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Turkish', color: Color(0xFFFBE9E7)),
    _ChipData(label: 'Lebanese', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Middle Eastern', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Moroccan', color: Color(0xFFFFE0B2)),
    _ChipData(label: 'Persian', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Indian', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Pakistani', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Bangladeshi', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Thai', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Vietnamese', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Chinese', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Japanese', color: Color(0xFFFCE4EC)),
    _ChipData(label: 'Korean', color: Color(0xFFE8F8F0)),
    _ChipData(label: 'Indonesian', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Malaysian', color: Color(0xFFE0F2F1)),
    _ChipData(label: 'Filipino', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Singaporean', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Mexican', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Tex-Mex', color: Color(0xFFFFE0B2)),
    _ChipData(label: 'Caribbean', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Brazilian', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'Peruvian', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Argentinian', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'American', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Southern US', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'Cajun / Creole', color: Color(0xFFFFE0B2)),
    _ChipData(label: 'British', color: Color(0xFFECEFF1)),
    _ChipData(label: 'Irish', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'German', color: Color(0xFFFFF8E1)),
    _ChipData(label: 'Scandinavian', color: Color(0xFFE3F2FD)),
    _ChipData(label: 'Polish', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'Russian', color: Color(0xFFE8EAF6)),
    _ChipData(label: 'Hungarian', color: Color(0xFFFFEBEE)),
    _ChipData(label: 'Ethiopian', color: Color(0xFFFFF3E0)),
    _ChipData(label: 'West African', color: Color(0xFFE8F5E9)),
    _ChipData(label: 'South African', color: Color(0xFFFBE9E7)),
    _ChipData(label: 'Australian', color: Color(0xFFE0F7FA)),
    _ChipData(label: 'Fusion', color: Color(0xFFF3E5F5)),
    _ChipData(label: 'International', color: Color(0xFFE3F2FD)),
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
// Flow layout — chip width follows label content
// ─────────────────────────────────────────────────────────────────────────────

class _TwoColGrid extends StatelessWidget {
  final List<_ChipData> items;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _TwoColGrid({required this.items, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in items)
          _PastelChip(
            data: item,
            isSelected: selected.contains(item.label),
            onTap: () => onToggle(item.label),
          ),
      ],
    );
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
            Icon(
              preferenceChipIcon(data.label),
              size: 16,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
            const SizedBox(width: 8),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textDark,
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
  final Color color;
  const _ChipData({required this.label, required this.color});
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
