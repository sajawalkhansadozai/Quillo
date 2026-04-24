import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../widgets/quillo_button.dart';
import '../../widgets/section_header.dart';
import 'skill_level_screen.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final Set<String> _selectedDietary = {};
  final Set<String> _selectedLifestyle = {};
  final Set<String> _selectedCuisines = {};

  final List<_ChipData> _dietaryOptions = const [
    _ChipData(label: 'Vegan', emoji: '🌱'),
    _ChipData(label: 'Vegetarian', emoji: '🥬'),
    _ChipData(label: 'Halal', emoji: '☪️'),
    _ChipData(label: 'Gluten-free', emoji: '🌾'),
    _ChipData(label: 'Dairy-free', emoji: '🥛'),
    _ChipData(label: 'Nut-free', emoji: '🥜'),
    _ChipData(label: 'No alcohol', emoji: '🚫'),
    _ChipData(label: 'Pescatarian', emoji: '🐟'),
  ];

  final List<_ChipData> _lifestyleOptions = const [
    _ChipData(label: 'Low-carb', emoji: '🥩'),
    _ChipData(label: 'Keto', emoji: '🧈'),
    _ChipData(label: 'Paleo', emoji: '🍖'),
    _ChipData(label: 'Raw food', emoji: '🥑'),
    _ChipData(label: 'Mediterranean', emoji: '🫒'),
    _ChipData(label: 'Sugar-free', emoji: '🍬'),
    _ChipData(label: 'High-protein', emoji: '💪'),
  ];

  final List<_ChipData> _cuisineOptions = const [
    _ChipData(label: 'Italian', emoji: '🍝'),
    _ChipData(label: 'Indian', emoji: '🍛'),
    _ChipData(label: 'Mexican', emoji: '🌮'),
    _ChipData(label: 'Japanese', emoji: '🍱'),
    _ChipData(label: 'Middle Eastern', emoji: '🧆'),
    _ChipData(label: 'Thai', emoji: '🍜'),
    _ChipData(label: 'French', emoji: '🥐'),
    _ChipData(label: 'Chinese', emoji: '🥡'),
    _ChipData(label: 'Korean', emoji: '🍲'),
    _ChipData(label: 'Greek', emoji: '🫕'),
  ];

  int get _totalSelected =>
      _selectedDietary.length + _selectedLifestyle.length + _selectedCuisines.length;

  Future<void> _saveAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    final allDietary = [..._selectedDietary, ..._selectedLifestyle].toList();
    await prefs.setStringList('onboarding_dietary', allDietary);
    await prefs.setStringList('onboarding_cuisines', _selectedCuisines.toList());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SkillLevelScreen()),
    );
  }

  void _skipToNext() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SkillLevelScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  const Spacer(),
                  _StepPill(label: '✦ Step 4 of 5'),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SkillLevelScreen()),
                    ),
                    child: Text('Skip',
                        style: TextStyle(fontSize: 14, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      'PERSONALISE YOUR EXPERIENCE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontFamily: 'Nunito'),
                        children: [
                          TextSpan(
                            text: 'Your ',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          TextSpan(
                            text: 'Preference',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                          TextSpan(
                            text: ' 🥗',
                            style: TextStyle(fontSize: 26),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select all that apply. QUILLO will tailor every recipe and suggestion just for you.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _totalSelected == 0
                              ? 'Nothing selected yet'
                              : '$_totalSelected selected',
                          style: TextStyle(
                            fontSize: 13,
                            color: _totalSelected > 0
                                ? AppColors.primary
                                : AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_totalSelected > 0)
                          Text(
                            '$_totalSelected selected',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(label: 'DIETARY RESTRICTIONS'),
                    const SizedBox(height: 10),
                    _ChipGrid(
                      items: _dietaryOptions,
                      selected: _selectedDietary,
                      onToggle: (label) {
                        setState(() {
                          if (_selectedDietary.contains(label)) {
                            _selectedDietary.remove(label);
                          } else {
                            _selectedDietary.add(label);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(label: 'HEALTH & LIFESTYLE'),
                    const SizedBox(height: 10),
                    _ChipGrid(
                      items: _lifestyleOptions,
                      selected: _selectedLifestyle,
                      onToggle: (label) {
                        setState(() {
                          if (_selectedLifestyle.contains(label)) {
                            _selectedLifestyle.remove(label);
                          } else {
                            _selectedLifestyle.add(label);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    SectionHeader(label: 'FAVOURITE CUISINES'),
                    const SizedBox(height: 10),
                    _ChipGrid(
                      items: _cuisineOptions,
                      selected: _selectedCuisines,
                      onToggle: (label) {
                        setState(() {
                          if (_selectedCuisines.contains(label)) {
                            _selectedCuisines.remove(label);
                          } else {
                            _selectedCuisines.add(label);
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                children: [
                  QuilloButton(
                    label: '✦  Continue',
                    onTap: _saveAndContinue,
                    backgroundColor: AppColors.primary,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  QuilloButton(
                    label: 'Skip for now',
                    onTap: _skipToNext,
                    backgroundColor: AppColors.textDark,
                    textColor: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipData {
  final String label;
  final String emoji;
  const _ChipData({required this.label, required this.emoji});
}

class _ChipGrid extends StatelessWidget {
  final List<_ChipData> items;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _ChipGrid({
    required this.items,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => _SelectableChip(
                data: item,
                isSelected: selected.contains(item.label),
                onTap: () => onToggle(item.label),
              ))
          .toList(),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final _ChipData data;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.chipBorder,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(data.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 16, color: AppColors.textDark),
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
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
