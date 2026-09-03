import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surfaceCanvas,
            toolbarHeight: 60,
            title: Text('Settings', style: AppTextStyles.headlineSm),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Account ───────────────────────────────────────────────────
                _SectionLabel('ACCOUNT'),
                const SizedBox(height: 10),
                _SettingsGroup(items: [
                  _SettingsRow(
                    icon: Icons.person_outline_rounded,
                    iconBg: AppColors.blockLilac,
                    title: 'Edit Profile',
                    onTap: () => context.push('/profile/edit'),
                  ),
                  _SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    iconBg: AppColors.blockMint,
                    title: 'Change Password',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.phone_outlined,
                    iconBg: AppColors.blockCream,
                    title: 'Update Phone Number',
                    onTap: () {},
                  ),
                ]).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Notifications ─────────────────────────────────────────────
                _SectionLabel('NOTIFICATIONS'),
                const SizedBox(height: 10),
                _SettingsGroup(items: [
                  _SettingsToggleRow(
                    icon: Icons.notifications_outlined,
                    iconBg: AppColors.blockCoral.withOpacity(0.5),
                    title: 'Push Notifications',
                    value: true,
                    onChanged: (v) {},
                  ),
                  _SettingsToggleRow(
                    icon: Icons.mail_outline_rounded,
                    iconBg: AppColors.blockPink,
                    title: 'Email Updates',
                    value: false,
                    onChanged: (v) {},
                  ),
                ]).animate(delay: 80.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Data & Privacy ────────────────────────────────────────────
                _SectionLabel('DATA & PRIVACY'),
                const SizedBox(height: 10),
                _SettingsGroup(items: [
                  _SettingsRow(
                    icon: Icons.download_outlined,
                    iconBg: AppColors.blockLime,
                    title: 'Export My Data',
                    subtitle: 'DPDP / GDPR compliant export',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.delete_outline_rounded,
                    iconBg: AppColors.statusExpiredBg,
                    title: 'Request Account Deletion',
                    subtitle: 'Submit data erasure request',
                    textColor: AppColors.statusExpiredText,
                    onTap: () => _showDeleteConfirm(context),
                  ),
                ]).animate(delay: 160.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── About ─────────────────────────────────────────────────────
                _SectionLabel('ABOUT'),
                const SizedBox(height: 10),
                _SettingsGroup(items: [
                  _SettingsRow(
                    icon: Icons.info_outline_rounded,
                    iconBg: AppColors.surfaceContainerLow,
                    title: 'App Version',
                    subtitle: '1.0.0 (MVP)',
                    onTap: () {},
                    showChevron: false,
                  ),
                  _SettingsRow(
                    icon: Icons.description_outlined,
                    iconBg: AppColors.surfaceContainerLow,
                    title: 'Terms of Service',
                    onTap: () {},
                  ),
                  _SettingsRow(
                    icon: Icons.privacy_tip_outlined,
                    iconBg: AppColors.surfaceContainerLow,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                ]).animate(delay: 240.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 24),

                // ── Logout button ─────────────────────────────────────────────
                _LogoutButton(
                  onTap: () => _handleLogout(context),
                ).animate(delay: 320.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.canvas,
        title: Text('Sign out?', style: AppTextStyles.headlineSm),
        content: Text(
          'You need to login again with your ${AppConstants.gigfolioIdBrand}.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go(AppConstants.routeWelcome);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text('Sign out', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.canvas,
        title: Text('Delete account?', style: AppTextStyles.headlineSm),
        content: Text(
          'This will submit a data erasure request. Your account and data will be permanently deleted within 30 days.',
          style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.bodyMd.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.statusExpiredText,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text('Request Deletion', style: AppTextStyles.button),
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

class _SettingsGroup extends StatelessWidget {
  final List<Widget> items;
  const _SettingsGroup({required this.items});

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
          return Column(
            children: [
              e.value,
              if (e.key < items.length - 1)
                const Divider(height: 1, indent: 64, color: AppColors.hairlineSoft),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Color? textColor;
  final VoidCallback onTap;
  final bool showChevron;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.textColor,
    required this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: textColor ?? AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMd.copyWith(color: textColor ?? AppColors.onSurface),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggleRow extends StatefulWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SettingsToggleRow> createState() => _SettingsToggleRowState();
}

class _SettingsToggleRowState extends State<_SettingsToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: widget.iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(widget.title, style: AppTextStyles.titleMd),
          ),
          Switch.adaptive(
            value: _value,
            activeTrackColor: AppColors.primary,
            onChanged: (v) {
              setState(() => _value = v);
              widget.onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.statusExpiredBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.statusExpiredBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 18, color: AppColors.statusExpiredText),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: AppTextStyles.titleMd.copyWith(
                color: AppColors.statusExpiredText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
