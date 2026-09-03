import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/gf_text_field.dart';
import '../../../shared/widgets/auth_widgets.dart';
import '../../../shared/providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (response.user != null) {
        // Sync user profile & score in Supabase DB per individual account
        await ref.read(userDbServiceProvider).syncUserRecord(response.user!);
        
        // Refresh local cache for logged-in user
        ref.invalidate(userProfileProvider);
        ref.invalidate(userReputationScoreProvider);

        if (mounted) {
          context.go(AppConstants.routeDashboard);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'https://kblhngnyyaxphzecftet.supabase.co/auth/v1/callback',
      );
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Auth Error (${e.statusCode ?? '400'}): ${e.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          children: [
            // Back button
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
                        'Login to access your individual GigFolio profile and score.',
                        style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
                      ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
                      const SizedBox(height: 28),

                      // Google Sign In Button
                      GoogleSignInButton(
                        onPressed: _handleGoogleSignIn,
                        isLoading: _isLoading,
                      ).animate(delay: 180.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 24),

                      const OrDivider().animate(delay: 200.ms).fadeIn(duration: 300.ms),
                      const SizedBox(height: 24),

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
                      ).animate(delay: 230.ms).fadeIn(duration: 300.ms),
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
                      ).animate(delay: 260.ms).fadeIn(duration: 300.ms),
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
                                child: Text('Login with Email', style: AppTextStyles.button),
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
