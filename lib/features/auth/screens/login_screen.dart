import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/gf_text_field.dart';
import '../../../shared/widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1200)); // TODO: Supabase auth
    if (mounted) {
      setState(() => _isLoading = false);
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
            // Back button + header
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.blockLilac,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          AppConstants.gigfolioIdBrand,
                          style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),

                      Text(
                        'Welcome back',
                        style: AppTextStyles.displayMd,
                      ).animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
                      const SizedBox(height: 8),
                      Text(
                        'Login using your ${AppConstants.gigfolioIdBrand} to continue.',
                        style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
                      ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
                      const SizedBox(height: 36),

                      // Email
                      GFTextField(
                        controller: _emailCtrl,
                        label: 'Email address',
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.mail_outline_rounded,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),

                      // Password
                      GFTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        hint: '••••••••',
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        onSuffixTap: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Password is required';
                          if (v.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 12),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push(AppConstants.routeForgotPassword),
                          child: Text(
                            'Forgot password?',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 24),

                      // Login button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isLoading
                            ? const AuthLoadingButton()
                            : ElevatedButton(
                                onPressed: _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                ),
                                child: Text('Login using ${AppConstants.gigfolioIdBrand}',
                                    style: AppTextStyles.button),
                              ),
                      ).animate(delay: 350.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),

                      const SizedBox(height: 32),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppConstants.routeRegister),
                            child: Text(
                              'Sign up',
                              style: AppTextStyles.bodyMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
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

// Private widgets removed — use AuthBackButton and AuthLoadingButton from shared/widgets/auth_widgets.dart
