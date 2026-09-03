import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/models.dart';

class PlatformsScreen extends StatelessWidget {
  const PlatformsScreen({super.key});

  static const List<PlatformConnection> _platforms = [
    PlatformConnection(
      id: 'p-uber', name: 'Uber', slug: 'uber',
      logoEmoji: 'U', logoColor: Color(0xFF000000),
      status: PlatformConnectionStatus.notConnected,
    ),
    PlatformConnection(
      id: 'p-dd', name: 'DoorDash', slug: 'doordash',
      logoEmoji: 'D', logoColor: Color(0xFFFF3008),
      status: PlatformConnectionStatus.notConnected,
    ),
    PlatformConnection(
      id: 'p-uw', name: 'Upwork', slug: 'upwork',
      logoEmoji: 'W', logoColor: Color(0xFF14A800),
      status: PlatformConnectionStatus.notConnected,
    ),
  ];

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
            title: Text('Platforms', style: AppTextStyles.headlineSm),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Coming soon banner (lilac — DESIGN.md promo-banner-lilac) ──
                _ComingSoonBanner()
                    .animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                const SizedBox(height: 20),

                // ── Platform catalog ───────────────────────────────────────────
                Text('PLATFORM CATALOG', style: AppTextStyles.eyebrow),
                const SizedBox(height: 10),
                ..._platforms.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlatformTile(platform: e.value)
                        .animate(delay: Duration(milliseconds: 100 + e.key * 80))
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05),
                  );
                }),
                const SizedBox(height: 20),

                // ── How it works (mint block — DESIGN.md block-mint) ───────────
                _HowItWorksBlock()
                    .animate(delay: 400.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Placeholder note ───────────────────────────────────────────
                _PlatformIntegrationNote()
                    .animate(delay: 500.ms).fadeIn(duration: 400.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blockLilac,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live integrations coming soon',
                  style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Platform connections will be enabled when OAuth access becomes available.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.75)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentMagenta,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              'Stay Tuned',
              style: AppTextStyles.labelLg.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformTile extends StatelessWidget {
  final PlatformConnection platform;
  const _PlatformTile({required this.platform});

  @override
  Widget build(BuildContext context) {
    final isConnected = platform.status == PlatformConnectionStatus.connected;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x054B2E83), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: platform.logoColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  platform.logoEmoji,
                  style: AppTextStyles.headlineMd.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(platform.name, style: AppTextStyles.headlineSm),
                  const SizedBox(height: 4),
                  if (isConnected && platform.rating != null)
                    Text(
                      '${platform.rating} ★ · ${platform.jobCount} ${platform.jobLabel}',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    )
                  else
                    Text(
                      'Not connected · Coming soon',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),

            // Action button
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${platform.name} integration coming soon.',
                      style: AppTextStyles.bodyMd.copyWith(color: Colors.white),
                    ),
                    backgroundColor: AppColors.blockNavy,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.statusVerifiedBg : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isConnected ? AppColors.statusVerifiedBorder : AppColors.cardBorder,
                  ),
                ),
                child: Text(
                  isConnected ? 'Connected' : 'Connect',
                  style: AppTextStyles.labelLg.copyWith(
                    color: isConnected ? AppColors.statusVerifiedText : AppColors.primary,
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

class _HowItWorksBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.link_rounded, 'Connect Platform', 'Authorize GigFolio to read your ratings and job history.'),
      (Icons.sync_rounded, 'Data Sync', 'Your data is normalized and added to your GigFolio profile.'),
      (Icons.speed_rounded, 'Score Updated', 'Your Gigfolio Score recalculates with the new verified data.'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blockMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HOW IT WORKS',
            style: AppTextStyles.eyebrow.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text('Platform integration flow', style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary)),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final step = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: AppTextStyles.titleMd.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.$2, style: AppTextStyles.titleMd.copyWith(color: AppColors.primary)),
                        const SizedBox(height: 2),
                        Text(step.$3, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.7))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlatformIntegrationNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusInactiveBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.statusInactiveBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.statusInactiveText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '// TODO(design): replace with live platform integrations — see Platform Provider interface (PlatformProvider.connect())',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.statusInactiveText,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
