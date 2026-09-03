import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/gf_text_field.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController(text: 'Aarav Sharma');
  final _phoneCtrl = TextEditingController(text: '+91 98765 43210');
  final _cityCtrl = TextEditingController(text: 'Bangalore');
  final _countryCtrl = TextEditingController(text: 'India');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900)); // TODO: PATCH /api/v1/profile
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated!', style: AppTextStyles.bodyMd.copyWith(color: Colors.white)),
          backgroundColor: AppColors.blockNavy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceCanvas,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('Edit Profile', style: AppTextStyles.headlineSm),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: Text(
              'Save',
              style: AppTextStyles.bodyMd.copyWith(
                color: _isLoading ? AppColors.textSecondary : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Photo
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppColors.blockLilac,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 3),
                        ),
                        child: Center(
                          child: Text('AS', style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary)),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceCanvas, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 8),
                Text(
                  'Tap to update photo',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                ).animate(delay: 100.ms).fadeIn(),
                const SizedBox(height: 28),

                GFTextField(
                  controller: _nameCtrl,
                  label: 'Full Legal Name',
                  prefixIcon: Icons.badge_outlined,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                ).animate(delay: 150.ms).fadeIn(duration: 300.ms),
                const SizedBox(height: 16),

                GFTextField(
                  controller: _phoneCtrl,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                ).animate(delay: 200.ms).fadeIn(duration: 300.ms),
                const SizedBox(height: 16),

                GFTextField(
                  controller: _cityCtrl,
                  label: 'City',
                  prefixIcon: Icons.location_city_outlined,
                ).animate(delay: 250.ms).fadeIn(duration: 300.ms),
                const SizedBox(height: 16),

                GFTextField(
                  controller: _countryCtrl,
                  label: 'Country',
                  prefixIcon: Icons.flag_outlined,
                ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
                const SizedBox(height: 32),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _isLoading
                      ? Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          ),
                          child: Text('Save Changes', style: AppTextStyles.button),
                        ),
                ).animate(delay: 350.ms).fadeIn(duration: 300.ms).slideY(begin: 0.2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
