import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/gf_text_field.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final List<String> _selectedSkills = [];
  final List<String> _selectedCategories = [];

  static const List<String> _allSkills = [
    'Delivery', 'Driving', 'Freelancing', 'Home Services',
    'Graphic Design', 'Writing', 'Programming', 'Customer Support',
    'Photography', 'Teaching', 'Cooking', 'Cleaning',
  ];

  static const List<String> _allCategories = [
    'Transport & Delivery', 'Freelance & Knowledge Work',
    'Home Services', 'Food & Hospitality',
    'Creative & Media', 'Tech & IT',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.go(AppConstants.routeDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: List.generate(3, (i) {
                      final active = i <= _currentPage;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary : AppColors.hairline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentPage + 1} of 3',
                        style: AppTextStyles.labelLg.copyWith(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppConstants.routeDashboard),
                        child: Text(
                          'Skip',
                          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _LocationPage(cityCtrl: _cityCtrl, countryCtrl: _countryCtrl),
                  _SkillsPage(
                    allSkills: _allSkills,
                    selectedSkills: _selectedSkills,
                    onToggle: (skill) => setState(() {
                      if (_selectedSkills.contains(skill)) {
                        _selectedSkills.remove(skill);
                      } else {
                        _selectedSkills.add(skill);
                      }
                    }),
                  ),
                  _CategoriesPage(
                    allCategories: _allCategories,
                    selectedCategories: _selectedCategories,
                    onToggle: (cat) => setState(() {
                      if (_selectedCategories.contains(cat)) {
                        _selectedCategories.remove(cat);
                      } else {
                        _selectedCategories.add(cat);
                      }
                    }),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: Text(
                  _currentPage < 2 ? 'Continue' : 'Go to Dashboard',
                  style: AppTextStyles.button,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPage extends StatelessWidget {
  final TextEditingController cityCtrl;
  final TextEditingController countryCtrl;
  const _LocationPage({required this.cityCtrl, required this.countryCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blockMint,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.location_on_rounded, size: 36, color: AppColors.primary),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text('Where are you based?', style: AppTextStyles.displayMd)
              .animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'This helps verifiers understand your work location.',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          ).animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 32),
          GFTextField(
            controller: cityCtrl,
            label: 'City',
            hint: 'Bangalore',
            prefixIcon: Icons.location_city_outlined,
          ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 14),
          GFTextField(
            controller: countryCtrl,
            label: 'Country',
            hint: 'India',
            prefixIcon: Icons.flag_outlined,
          ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

class _SkillsPage extends StatelessWidget {
  final List<String> allSkills;
  final List<String> selectedSkills;
  final ValueChanged<String> onToggle;

  const _SkillsPage({
    required this.allSkills,
    required this.selectedSkills,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blockLilac,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.psychology_rounded, size: 36, color: AppColors.primary),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text('What are your skills?', style: AppTextStyles.displayMd)
              .animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'Select all that apply. You can edit these later.',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          ).animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allSkills.map((skill) {
              final selected = selectedSkills.contains(skill);
              return GestureDetector(
                onTap: () => onToggle(skill),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.canvas,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    skill,
                    style: AppTextStyles.labelLg.copyWith(
                      color: selected ? Colors.white : AppColors.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }
}

class _CategoriesPage extends StatelessWidget {
  final List<String> allCategories;
  final List<String> selectedCategories;
  final ValueChanged<String> onToggle;

  const _CategoriesPage({
    required this.allCategories,
    required this.selectedCategories,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.blockLime, AppColors.blockMint, AppColors.blockCream,
      AppColors.blockPink, AppColors.blockCoral.withOpacity(0.5), AppColors.blockLilac,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.blockCoral.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.category_rounded, size: 36, color: AppColors.primary),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text('Work categories', style: AppTextStyles.displayMd)
              .animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'What types of gig work do you do?',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          ).animate(delay: 150.ms).fadeIn(),
          const SizedBox(height: 24),
          ...allCategories.asMap().entries.map((entry) {
            final cat = entry.value;
            final idx = entry.key;
            final selected = selectedCategories.contains(cat);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => onToggle(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : colors[idx % colors.length],
                    borderRadius: BorderRadius.circular(14),
                    border: selected
                        ? null
                        : Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat,
                          style: AppTextStyles.headlineSm.copyWith(
                            color: selected ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ).animate(delay: Duration(milliseconds: 200 + idx * 50)).fadeIn(duration: 300.ms).slideX(begin: 0.1);
          }),
        ],
      ),
    );
  }
}
