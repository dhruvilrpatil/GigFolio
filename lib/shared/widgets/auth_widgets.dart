import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Reusable circular back button for auth/modal screens
class AuthBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const AuthBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.onSurface),
      ),
    );
  }
}

/// Reusable loading button placeholder
class AuthLoadingButton extends StatelessWidget {
  const AuthLoadingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(50),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}

/// Google Sign-In Button (Apple-style sleek outline)
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  const GoogleSignInButton({super.key, required this.onPressed, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Google G icon representation
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4285F4),
            ),
            child: const Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Continue with Google',
            style: AppTextStyles.button.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Divider with "OR" text for Auth screens
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.hairlineSoft, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: AppTextStyles.eyebrow.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.hairlineSoft, thickness: 1)),
      ],
    );
  }
}
