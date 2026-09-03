import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gf_text_field.dart';
import '../../../shared/widgets/auth_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isLoading = false;
        _sent = true;
      });
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
              child: Row(children: [AuthBackButton(onTap: () => context.pop())]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: _sent
                    ? _SuccessView()
                    : _FormView(
                        formKey: _formKey,
                        emailCtrl: _emailCtrl,
                        isLoading: _isLoading,
                        onSubmit: _handleReset,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final VoidCallback onSubmit;

  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.blockLilac,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.lock_reset_rounded, size: 30, color: AppColors.primary),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),

          Text('Forgot password?', style: AppTextStyles.displayMd)
              .animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 8),
          Text(
            'Enter your email and we will send you a reset link.',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 32),

          GFTextField(
            controller: emailCtrl,
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
          const SizedBox(height: 28),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? const AuthLoadingButton()
                : ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                    child: Text('Send Reset Link',
                        style: AppTextStyles.button.copyWith(color: Colors.white)),
                  ),
          ).animate(delay: 250.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.statusVerifiedBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.statusVerifiedBorder),
          ),
          child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.statusVerifiedText),
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 24),
        Text(
          'Check your email',
          style: AppTextStyles.headlineLg,
          textAlign: TextAlign.center,
        ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        Text(
          'We sent a password reset link.\nCheck your inbox and follow the instructions.',
          style: AppTextStyles.bodyLg.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => context.pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
          child: Text('Back to Login', style: AppTextStyles.button),
        ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
      ],
    );
  }
}
