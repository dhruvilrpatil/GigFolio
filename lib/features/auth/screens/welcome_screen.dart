import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Logo
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          AppConstants.appName,
                          style: AppTextStyles.headlineLg.copyWith(
                            color: AppColors.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
                    const SizedBox(height: 40),

                    // Hero block — DESIGN.md block-lilac pattern
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppColors.blockLilac,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'YOUR WORK',
                            style: AppTextStyles.eyebrow.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'One portable identity.\nEvery gig platform.',
                            style: AppTextStyles.displayMd.copyWith(
                              color: AppColors.primary,
                              fontSize: 28,
                              height: 1.20,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Prove your track record to anyone — banks, employers, landlords — without giving up control of your data.',
                            style: AppTextStyles.bodyLg.copyWith(
                              color: AppColors.primary.withOpacity(0.75),
                            ),
                          ),
                        ],
                      ),
                    ).animate(delay: 100.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1),
                    const SizedBox(height: 24),

                    // Feature chips row
                    Row(
                      children: [
                        _FeatureChip(emoji: '🔐', label: 'Secure'),
                        const SizedBox(width: 8),
                        _FeatureChip(emoji: '✅', label: 'Verified'),
                        const SizedBox(width: 8),
                        _FeatureChip(emoji: '📊', label: 'Portable'),
                      ],
                    ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 32),

                    // Mini stat blocks — DESIGN.md color blocks
                    Row(
                      children: [
                        Expanded(
                          child: _StatBlock(
                            color: AppColors.blockMint,
                            value: '50K+',
                            label: 'Gig Workers',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBlock(
                            color: AppColors.blockCream,
                            value: '3',
                            label: 'Platforms',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBlock(
                            color: AppColors.blockCoral.withOpacity(0.6),
                            value: '4.9★',
                            label: 'Avg Rating',
                          ),
                        ),
                      ],
                    ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // CTA buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () => context.push(AppConstants.routeRegister),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                    child: Text(
                      'Create your ${AppConstants.gigfolioIdBrand}',
                      style: AppTextStyles.button,
                    ),
                  ).animate(delay: 500.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.push(AppConstants.routeLogin),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                    ),
                    child: Text(
                      'Login using ${AppConstants.gigfolioIdBrand}',
                      style: AppTextStyles.button.copyWith(color: AppColors.primary),
                    ),
                  ).animate(delay: 600.ms).fadeIn(duration: 400.ms).slideY(begin: 0.3),
                  const SizedBox(height: 16),
                  Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                  ).animate(delay: 700.ms).fadeIn(duration: 300.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _FeatureChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text(label, style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final Color color;
  final String value;
  final String label;
  const _StatBlock({required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.7))),
        ],
      ),
    );
  }
}
