import 'package:flutter/material.dart';
import 'package:quillo/models/recipe_model.dart';
import 'package:quillo/theme/app_theme.dart';

class RecipeDetailScreen extends StatefulWidget {
  final RecipeModel recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  int _servings = 2;
  bool _isSaved = false;
  bool _showVideo = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _servings = widget.recipe.servings;
    _isSaved = widget.recipe.isSaved;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Missing ingredients (hardcoded for demo)
  final List<Map<String, String>> _missingIngredients = const [
    {'name': 'Unsalted Butter', 'amount': '40g', 'emoji': '🧈'},
    {'name': 'Chilli Flakes', 'amount': '1 tsp', 'emoji': '🌶️'},
  ];

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero Image ───────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.textDark),
                  ),
                ),
                actions: [
                  GestureDetector(
                    onTap: () {},
                    child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]), child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.share_rounded, size: 18, color: AppColors.textDark))),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isSaved = !_isSaved),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(_isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 18, color: _isSaved ? AppColors.primary : AppColors.textDark),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: recipe.color.withOpacity(0.12),
                        child: Center(child: Text(recipe.emoji, style: const TextStyle(fontSize: 100))),
                      ),
                      // Rating overlay
                      Positioned(
                        bottom: 14,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                              const SizedBox(width: 4),
                              Text('${recipe.rating}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                              Text(' (${_formatReviews(recipe.reviews)})', style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                      ),
                      // Match badge
                      Positioned(
                        bottom: 14,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(20)),
                          child: const Text('92% match', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags
                      Wrap(
                        spacing: 8,
                        children: recipe.tags.map((t) => _TagChip(label: t)).toList(),
                      ),
                      const SizedBox(height: 10),

                      // Title
                      Text(recipe.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
                      const SizedBox(height: 8),

                      // Meta row
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.textMedium),
                          const SizedBox(width: 4),
                          Text('${recipe.time} min total', style: const TextStyle(fontSize: 13, color: AppColors.textMedium)),
                          const SizedBox(width: 14),
                          const Icon(Icons.people_outline_rounded, size: 14, color: AppColors.textMedium),
                          const SizedBox(width: 4),
                          Text('${recipe.servings} servings', style: const TextStyle(fontSize: 13, color: AppColors.textMedium)),
                          const SizedBox(width: 14),
                          const Icon(Icons.local_fire_department_outlined, size: 14, color: AppColors.textMedium),
                          const SizedBox(width: 4),
                          Text('${recipe.calories} cal', style: const TextStyle(fontSize: 13, color: AppColors.textMedium)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Chef row
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF9C8FFF)]),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('👩‍🍳', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(recipe.chef, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                                Text('146 recipes', style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                            child: const Text('Follow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.divider),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Ingredients ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                          Row(
                            children: [
                              _ServingButton(icon: Icons.remove, onTap: () { if (_servings > 1) setState(() => _servings--); }),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$_servings', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark))),
                              _ServingButton(icon: Icons.add, onTap: () => setState(() => _servings++)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // View all link
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {},
                          child: Text('View all', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.8,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: recipe.ingredients.map((ing) => _IngredientTile(ingredient: ing)).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Missing Ingredients ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Missing Ingredients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
                            child: Text('${_missingIngredients.length} items', style: const TextStyle(fontSize: 12, color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(children: [
                              const Text('⚠️', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              const Text('Almost there!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              const Spacer(),
                              Text('${_missingIngredients.length} ingredients not in your scan', style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
                            ]),
                            const SizedBox(height: 10),
                            ..._missingIngredients.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(children: [
                                Text(item['emoji']!, style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 10),
                                Text(item['name']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                                const Spacer(),
                                Text(item['amount']!, style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                              ]),
                            )),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {},
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(10)),
                                child: const Center(child: Text('+ Add to Shopping List', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary))),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Instructions ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                      GestureDetector(
                        onTap: () => setState(() => _showVideo = !_showVideo),
                        child: Text('Video mode', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _InstructionCard(instruction: recipe.instructions[i]),
                  ),
                  childCount: recipe.instructions.length,
                ),
              ),

              // ── Nutrition ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nutrition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark, fontFamily: 'Nunito')),
                          Text('per serving', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                          GestureDetector(onTap: () {}, child: Text('Full info', style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _NutritionCard(value: '${recipe.nutrition.calories}', unit: 'kcal', label: 'Calories', color: AppColors.accent),
                          const SizedBox(width: 10),
                          _NutritionCard(value: '${recipe.nutrition.carbs}g', unit: '', label: 'Carbs', color: AppColors.primary),
                          const SizedBox(width: 10),
                          _NutritionCard(value: '${recipe.nutrition.fat}g', unit: '', label: 'Fat', color: const Color(0xFFE91E63)),
                          const SizedBox(width: 10),
                          _NutritionCard(value: '${recipe.nutrition.protein}g', unit: '', label: 'Protein', color: const Color(0xFF4CAF50)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Spacer for bottom button
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Bottom CTA ───────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(child: Text('⏱️', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF9C8FFF)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
                        ),
                        child: const Center(
                          child: Text('✦  Start Cooking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Nunito')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatReviews(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
    );
  }
}

class _ServingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ServingButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: AppColors.chipBorder, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.textDark),
      ),
    );
  }
}

class _IngredientTile extends StatelessWidget {
  final IngredientModel ingredient;
  const _IngredientTile({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          Text(ingredient.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ingredient.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark), overflow: TextOverflow.ellipsis),
                Text(ingredient.amount, style: const TextStyle(fontSize: 11, color: AppColors.textMedium)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final InstructionModel instruction;
  const _InstructionCard({required this.instruction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text('${instruction.step}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(instruction.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 4),
                Text(instruction.description, style: const TextStyle(fontSize: 13, color: AppColors.textMedium, height: 1.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text('${instruction.durationMins} min', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color color;
  const _NutritionCard({required this.value, required this.unit, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, fontFamily: 'Nunito')),
            if (unit.isNotEmpty) Text(unit, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMedium, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
