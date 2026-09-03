import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/auth_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static final _mockPlatforms = [
    const PlatformConnection(
      id: 'p-uber', name: 'Uber', slug: 'uber',
      logoEmoji: 'U', logoColor: Color(0xFF000000),
      status: PlatformConnectionStatus.notConnected,
    ),
    const PlatformConnection(
      id: 'p-dd', name: 'DoorDash', slug: 'doordash',
      logoEmoji: 'D', logoColor: Color(0xFFFF3008),
      status: PlatformConnectionStatus.notConnected,
    ),
    const PlatformConnection(
      id: 'p-uw', name: 'Upwork', slug: 'upwork',
      logoEmoji: 'W', logoColor: Color(0xFF6FDA44),
      status: PlatformConnectionStatus.notConnected,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final scoreAsync = ref.watch(userReputationScoreProvider);

    final profile = profileAsync.value ??
        const WorkerProfile(
          id: 'temp',
          userId: 'temp',
          legalName: 'Gig Worker',
          location: 'Mumbai, India',
          profileCompleteness: 0.85,
        );

    final score = scoreAsync.value ??
        const ReputationScore(
          compositeScore: 4.8,
          tag: ReputationTag.excellent,
          confidence: ConfidenceTier.high,
          confidenceIndex: 0.92,
          isProvisional: false,
          subscoreRating: 0.94,
          subscoreVolume: 0.88,
          subscoreReliability: 0.95,
          subscoreConsistency: 0.85,
          subscoreSkills: 0.75,
          message: '',
        );

    final greeting = _greeting();
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ─────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surfaceCanvas,
            elevation: 0,
            expandedHeight: 0,
            toolbarHeight: 72,
            flexibleSpace: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              child: Row(
                children: [
                  // Avatar
                  GestureDetector(
                    onTap: () => context.go(AppConstants.routeProfile),
                    child: _Avatar(initials: profile.initials),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting, ${profile.legalName.split(' ').first} 👋',
                          style: AppTextStyles.headlineSm,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          profile.location ?? 'Mumbai, India',
                          style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  // Notification button
                  _NotificationButton(),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Identity Card ──────────────────────────────────────────────
                _IdentityCard(profile: profile, score: score)
                    .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),

                // ── Score quick view ───────────────────────────────────────────
                _ScoreCard(score: score)
                    .animate(delay: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),

                // ── Stats row ──────────────────────────────────────────────────
                _StatsRow()
                    .animate(delay: 150.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Platforms ─────────────────────────────────────────────────
                _SectionHeader(
                  title: 'CONNECTED PLATFORMS',
                  action: 'Manage →',
                  onAction: () => context.go(AppConstants.routePlatforms),
                ),
                const SizedBox(height: 10),
                _PlatformsCard(platforms: _mockPlatforms)
                    .animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Credentials Placeholder ────────────────────────────────────
                _PlaceholderCard(
                  icon: Icons.verified_outlined,
                  color: AppColors.blockLilac,
                  title: 'Credentials',
                  subtitle: '0 Active Credentials',
                  tag: 'COMING SOON',
                ).animate(delay: 250.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 12),

                // ── Sharing Placeholder ────────────────────────────────────────
                _PlaceholderCard(
                  icon: Icons.share_outlined,
                  color: AppColors.blockMint,
                  title: 'Sharing',
                  subtitle: '0 Active Share Links',
                  tag: 'COMING SOON',
                ).animate(delay: 280.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Recent Activity ────────────────────────────────────────────
                _SectionHeader(title: 'RECENT ACTIVITY'),
                const SizedBox(height: 10),
                _ActivityCard()
                    .animate(delay: 320.ms).fadeIn(duration: 400.ms),

                // ── Share CTA ─────────────────────────────────────────────────
                const SizedBox(height: 20),
                _ShareProfileButton()
                    .animate(delay: 360.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _Avatar extends StatelessWidget {
  final String initials;
  const _Avatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.blockLilac,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          ),
          child: Center(
            child: Text(initials, style: AppTextStyles.titleMd.copyWith(color: AppColors.primary)),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.statusVerifiedAccent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceCanvas, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.canvas,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Icon(Icons.notifications_outlined, size: 20, color: AppColors.onSurface),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.statusPendingAccent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surfaceCanvas, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final WorkerProfile profile;
  final ReputationScore score;
  const _IdentityCard({required this.profile, required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x0D4B2E83), blurRadius: 20, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GIGFOLIO IDENTITY',
                  style: AppTextStyles.eyebrow.copyWith(color: AppColors.primary),
                ),
                _StatusPill(
                  label: profile.identityStatus == 'Verified' ? 'VERIFIED' : 'NOT VERIFIED',
                  color: profile.identityStatus == 'Verified'
                      ? AppColors.statusVerifiedText
                      : AppColors.statusInactiveText,
                  bgColor: profile.identityStatus == 'Verified'
                      ? AppColors.statusVerifiedBg
                      : AppColors.statusInactiveBg,
                  borderColor: profile.identityStatus == 'Verified'
                      ? AppColors.statusVerifiedBorder
                      : AppColors.statusInactiveBorder,
                  icon: profile.identityStatus == 'Verified'
                      ? Icons.verified_rounded
                      : Icons.info_outline_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Profile name + QR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.blockLilac,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      profile.initials,
                      style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.legalName, style: AppTextStyles.headlineSm),
                      const SizedBox(height: 2),
                      Text(
                        'Gig Worker · ${profile.location ?? 'India'}',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Mini QR placeholder
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 32),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Stats strip
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCanvas,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.hairlineSoft),
            ),
            child: Row(
              children: [
                _StatCell(value: score.compositeScore.toStringAsFixed(1), label: 'Reputation'),
                _VertDivider(),
                _StatCell(value: '4.8 ★', label: 'Rating'),
                _VertDivider(),
                _StatCell(value: '${(profile.profileCompleteness * 100).toInt()}%', label: 'Profile'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // View profile button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton.icon(
              onPressed: () => context.go(AppConstants.routeProfile),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerLow,
                foregroundColor: AppColors.primary,
                elevation: 0,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_outline_rounded, size: 18),
              label: Text('View Profile', style: AppTextStyles.titleMd.copyWith(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final ReputationScore score;
  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppConstants.routeReputation),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, const Color(0xFF5B3BA0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GIGFOLIO SCORE',
                    style: AppTextStyles.eyebrow.copyWith(color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    score.compositeScore.toStringAsFixed(1),
                    style: AppTextStyles.scoreDisplay.copyWith(color: Colors.white, fontSize: 56),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          score.tag.label,
                          style: AppTextStyles.labelLg.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Confidence: ${score.confidence.label}',
                        style: AppTextStyles.bodySm.copyWith(color: Colors.white.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                const Icon(Icons.trending_up_rounded, color: Colors.white, size: 32),
                const SizedBox(height: 8),
                Text(
                  'View\ndetails',
                  style: AppTextStyles.bodySm.copyWith(color: Colors.white.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniStatCard(
            color: AppColors.blockLime,
            value: '1,240',
            label: 'Completed Jobs',
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStatCard(
            color: AppColors.blockCream,
            value: '₹48.5K',
            label: 'Avg. Monthly',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final Color color;
  final String value;
  final String label;
  final IconData icon;
  const _MiniStatCard({required this.color, required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary)),
              Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.7))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlatformsCard extends StatelessWidget {
  final List<PlatformConnection> platforms;
  const _PlatformsCard({required this.platforms});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: platforms.asMap().entries.map((e) {
          final p = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.logoColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          p.logoEmoji,
                          style: AppTextStyles.titleMd.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: AppTextStyles.titleMd),
                          Text(
                            p.statusLabel,
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(
                      label: p.statusLabel.toUpperCase(),
                      color: AppColors.statusInactiveText,
                      bgColor: AppColors.statusInactiveBg,
                      borderColor: AppColors.statusInactiveBorder,
                      icon: Icons.add_circle_outline_rounded,
                    ),
                  ],
                ),
              ),
              if (e.key < platforms.length - 1)
                const Divider(height: 1, indent: 62, color: AppColors.hairlineSoft),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String tag;
  const _PlaceholderCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMd),
                Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.statusInactiveBg,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.statusInactiveBorder),
            ),
            child: Text(tag, style: AppTextStyles.labelMd.copyWith(color: AppColors.statusInactiveText)),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final activities = [
      _ActivityItem('Profile verified', 'Today', Icons.verified_user_outlined, AppColors.statusVerifiedBg, AppColors.statusVerifiedText),
      _ActivityItem('Work history updated', 'Today', Icons.history_rounded, AppColors.blockMint, AppColors.primary),
      _ActivityItem('Credential generated', 'Yesterday', Icons.card_membership_outlined, AppColors.blockLilac, AppColors.primary),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: activities.asMap().entries.map((e) {
          final a = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: a.bgColor, shape: BoxShape.circle),
                      child: Icon(a.icon, size: 18, color: a.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(a.label, style: AppTextStyles.titleMd),
                    ),
                    Text(a.time, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (e.key < activities.length - 1)
                const Divider(height: 1, indent: 62, color: AppColors.hairlineSoft),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ActivityItem {
  final String label;
  final String time;
  final IconData icon;
  final Color bgColor;
  final Color color;
  _ActivityItem(this.label, this.time, this.icon, this.bgColor, this.color);
}

class _ShareProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.share_rounded, size: 18),
      label: Text('Share Profile', style: AppTextStyles.button),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.eyebrow),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelMd.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  const _StatCell({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headlineSm.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppColors.hairlineSoft);
  }
}
