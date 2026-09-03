import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/models.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static final _mockProfile = const WorkerProfile(
    id: 'w-001',
    userId: 'u-001',
    legalName: 'Aarav Sharma',
    email: 'aarav@example.com',
    phone: '+91 98765 43210',
    location: 'Bangalore, IN',
    skills: ['Delivery', 'Driving', 'Customer Support'],
    workCategories: ['Transport & Delivery'],
    profileCompleteness: 0.96,
    identityStatus: 'Not Verified',
  );

  @override
  Widget build(BuildContext context) {
    final profile = _mockProfile;
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surfaceCanvas,
            toolbarHeight: 60,
            title: Text('Profile', style: AppTextStyles.headlineSm),
            actions: [
              TextButton(
                onPressed: () => context.push('/profile/edit'),
                child: Text(
                  'Edit',
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Profile Hero ───────────────────────────────────────────────
                _ProfileHero(profile: profile)
                    .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),

                // ── Completeness bar (lime block) ──────────────────────────────
                _CompletenessBlock(completeness: profile.profileCompleteness)
                    .animate(delay: 100.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Contact info ───────────────────────────────────────────────
                _SectionLabel('CONTACT INFO'),
                const SizedBox(height: 10),
                _InfoCard(items: [
                  _InfoRow(Icons.mail_outline_rounded, 'Email', profile.email ?? 'Not set'),
                  _InfoRow(Icons.phone_outlined, 'Phone', profile.phone ?? 'Not set'),
                  _InfoRow(Icons.location_on_outlined, 'Location', profile.location ?? 'Not set'),
                ]).animate(delay: 150.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Skills ─────────────────────────────────────────────────────
                _SectionLabel('SKILLS'),
                const SizedBox(height: 10),
                _SkillsBlock(skills: profile.skills)
                    .animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Work Categories ────────────────────────────────────────────
                _SectionLabel('WORK CATEGORIES'),
                const SizedBox(height: 10),
                _InfoCard(items: profile.workCategories.map((c) =>
                    _InfoRow(Icons.category_outlined, c, 'Active category')).toList())
                    .animate(delay: 250.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Identity placeholder (cream block) ─────────────────────────
                _IdentityPlaceholder()
                    .animate(delay: 300.ms).fadeIn(duration: 400.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final WorkerProfile profile;
  const _ProfileHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0D4B2E83), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Photo slot + name
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.blockLilac,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 3),
                ),
                child: Center(
                  child: Text(
                    profile.initials,
                    style: AppTextStyles.headlineLg.copyWith(color: AppColors.primary),
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.canvas, width: 2),
                ),
                child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(profile.legalName, style: AppTextStyles.headlineMd),
          const SizedBox(height: 4),
          Text(
            profile.location ?? '',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // Gigfolio ID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.fingerprint_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'GF-${profile.id.toUpperCase()}',
                  style: AppTextStyles.credentialMono.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletenessBlock extends StatelessWidget {
  final double completeness;
  const _CompletenessBlock({required this.completeness});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blockLime,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profile Completeness', style: AppTextStyles.titleMd.copyWith(color: AppColors.primary)),
              Text(
                '${(completeness * 100).toInt()}%',
                style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completeness,
              minHeight: 8,
              backgroundColor: AppColors.primary.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            completeness >= 0.9
                ? 'Great! Your profile is nearly complete.'
                : 'Complete your profile to improve your Gigfolio Score.',
            style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.75)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final item = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.label, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 2),
                          Text(item.value, style: AppTextStyles.titleMd),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key < items.length - 1)
                const Divider(height: 1, indent: 64, color: AppColors.hairlineSoft),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);
}

class _SkillsBlock extends StatelessWidget {
  final List<String> skills;
  const _SkillsBlock({required this.skills});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills.map((s) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(s, style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
          );
        }).toList(),
      ),
    );
  }
}

class _IdentityPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blockCream,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.how_to_reg_outlined, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Identity Verification', style: AppTextStyles.titleMd.copyWith(color: AppColors.primary)),
                const SizedBox(height: 3),
                Text(
                  'Coming soon — DigiLocker / Aadhaar integration will be available in a future update.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.eyebrow);
  }
}
