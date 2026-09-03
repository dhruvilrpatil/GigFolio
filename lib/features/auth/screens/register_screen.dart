import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/gf_text_field.dart';
import '../../../shared/widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
      context.go(AppConstants.routeOnboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  AuthBackButton(onTap: () => context.pop()),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.blockLime,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          'Create your ${AppConstants.gigfolioIdBrand}',
                          style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),

                      Text('Join GigFolio', style: AppTextStyles.displayMd)
                          .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
                      const SizedBox(height: 6),
                      Text(
                        'Build your portable work identity in minutes.',
                        style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
                      ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 28),

                      GFTextField(
                        controller: _nameCtrl,
                        label: 'Full Legal Name',
                        hint: 'Aarav Sharma',
                        prefixIcon: Icons.badge_outlined,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),

                      GFTextField(
                        controller: _emailCtrl,
                        label: 'Email address',
                        hint: 'aarav@example.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ).animate(delay: 230.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),

                      GFTextField(
                        controller: _phoneCtrl,
                        label: 'Phone number',
                        hint: '+91 98765 43210',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Phone number is required' : null,
                      ).animate(delay: 260.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),

                      GFTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        hint: 'Min. 8 characters',
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 8) return 'Password must be at least 8 characters';
                          return null;
                        },
                      ).animate(delay: 290.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 14),

                      GFTextField(
                        controller: _confirmCtrl,
                        label: 'Confirm Password',
                        hint: 'Re-enter password',
                        obscureText: _obscureConfirm,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm your password';
                          if (v != _passwordCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ).animate(delay: 320.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 28),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isLoading
                            ? const AuthLoadingButton()
                            : ElevatedButton(
                                onPressed: _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                child: Text(
                                  'Create ${AppConstants.gigfolioIdBrand}',
                                  style: AppTextStyles.button,
                                ),
                              ),
                      ).animate(delay: 370.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppConstants.routeLogin),
                            child: Text(
                              'Sign in',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ).animate(delay: 420.ms).fadeIn(duration: 300.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
