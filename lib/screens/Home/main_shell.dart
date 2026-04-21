import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    ScanPlaceholderScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _QuilloTabBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == 2) {
            _showScanSheet(context);
            return;
          }
          setState(() => _currentIndex = i);
        },
      ),
    );
  }

  void _showScanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScanSheet(),
    );
  }
}

class _QuilloTabBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _QuilloTabBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(icon: Icons.home_rounded, label: 'Home', index: 0, current: currentIndex, onTap: onTap),
              _TabItem(icon: Icons.explore_rounded, label: 'Explore', index: 1, current: currentIndex, onTap: onTap),
              _ScanTabItem(onTap: () => onTap(2)),
              _TabItem(icon: Icons.bookmark_rounded, label: 'Saved', index: 3, current: currentIndex, onTap: onTap),
              _TabItem(icon: Icons.person_rounded, label: 'Profile', index: 4, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanTabItem extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanTabItem({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF9C8FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _ScanSheet extends StatelessWidget {
  const _ScanSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.chipBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('📸', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text('Scan a Receipt', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark, fontFamily: 'Nunito')),
          const SizedBox(height: 8),
          Text('Point your camera at a grocery receipt\nand QUILLO will suggest delicious recipes.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.textMedium, height: 1.5)),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(16)),
            child: const Center(child: Text('Open Camera', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, fontFamily: 'Nunito'))),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// Placeholder screens
class ScanPlaceholderScreen extends StatelessWidget {
  const ScanPlaceholderScreen({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}


