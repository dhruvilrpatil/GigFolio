import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/models.dart';

final platformsProvider = StateNotifierProvider<PlatformsNotifier, List<PlatformConnection>>((ref) {
  return PlatformsNotifier();
});

class PlatformsNotifier extends StateNotifier<List<PlatformConnection>> {
  PlatformsNotifier() : super(const [
    PlatformConnection(
      id: 'p-uber', name: 'Uber', slug: 'uber',
      logoEmoji: 'U', logoColor: Color(0xFF000000),
      status: PlatformConnectionStatus.notConnected,
    ),
    PlatformConnection(
      id: 'p-zomato', name: 'Zomato', slug: 'zomato',
      logoEmoji: 'Z', logoColor: Color(0xFFCB202D),
      status: PlatformConnectionStatus.notConnected,
    ),
    PlatformConnection(
      id: 'p-rapido', name: 'Rapido', slug: 'rapido',
      logoEmoji: 'R', logoColor: Color(0xFFF9C111),
      status: PlatformConnectionStatus.notConnected,
    ),
    PlatformConnection(
      id: 'p-urbanclap', name: 'Urban Company', slug: 'urban_company',
      logoEmoji: 'UC', logoColor: Color(0xFF000000),
      status: PlatformConnectionStatus.notConnected,
    ),
  ]);

  Future<void> connectPlatform(String id, {double rating = 4.8, int jobCount = 240}) async {
    // Set to syncing
    state = state.map((p) => p.id == id ? p.copyWith(status: PlatformConnectionStatus.syncing) : p).toList();
    
    // Simulate OAuth handshake & token exchange delay
    await Future.delayed(const Duration(milliseconds: 2200));

    // Set to connected with customized verified data
    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(
          status: PlatformConnectionStatus.connected,
          rating: rating,
          jobCount: jobCount,
          jobLabel: (id == 'p-uber' || id == 'p-rapido') ? 'trips' : 'deliveries/jobs',
        );
      }
      return p;
    }).toList();
  }

  void disconnectPlatform(String id) {
    state = state.map((p) {
      if (p.id == id) {
        return PlatformConnection(
          id: p.id,
          name: p.name,
          slug: p.slug,
          logoEmoji: p.logoEmoji,
          logoColor: p.logoColor,
          status: PlatformConnectionStatus.notConnected,
        );
      }
      return p;
    }).toList();
  }
}

class PlatformsScreen extends ConsumerWidget {
  const PlatformsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(platformsProvider);

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
                // ── Banner ─────────────────────────────────────────────────────
                _ComingSoonBanner()
                    .animate().fadeIn(duration: 400.ms).slideY(begin: -0.1),
                const SizedBox(height: 20),

                // ── Platform catalog ───────────────────────────────────────────
                Text('PLATFORM CATALOG', style: AppTextStyles.eyebrow),
                const SizedBox(height: 10),
                ...platforms.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlatformTile(platform: e.value)
                        .animate(delay: Duration(milliseconds: 100 + e.key * 80))
                        .fadeIn(duration: 300.ms)
                        .slideX(begin: 0.05),
                  );
                }),
                const SizedBox(height: 20),

                // ── How it works ───────────────────────────────────────────────
                _HowItWorksBlock()
                    .animate(delay: 400.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Integration Note ───────────────────────────────────────────
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
                  'Interactive OAuth Mockups Active',
                  style: AppTextStyles.titleMd.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "Connect" on Uber, Zomato, Rapido, or Urban Company to experience the live OAuth authorization flow.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentMagenta,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Text(
              'Live Demo',
              style: AppTextStyles.labelLg.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformTile extends ConsumerWidget {
  final PlatformConnection platform;
  const _PlatformTile({required this.platform});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = platform.status == PlatformConnectionStatus.connected;
    final isSyncing = platform.status == PlatformConnectionStatus.syncing;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? AppColors.statusVerifiedBorder : AppColors.cardBorder,
        ),
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
                  Row(
                    children: [
                      Text(platform.name, style: AppTextStyles.headlineSm),
                      if (isConnected) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.statusVerifiedText),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isConnected && platform.rating != null)
                    Text(
                      '${platform.rating} ★ · ${platform.jobCount} ${platform.jobLabel}',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.statusVerifiedText,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (isSyncing)
                    Text(
                      'Authenticating OAuth...',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                    )
                  else
                    Text(
                      'Ready to connect',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),

            // Action button
            GestureDetector(
              onTap: () {
                if (isSyncing) return;
                if (isConnected) {
                  _showDisconnectOption(context, ref, platform);
                } else {
                  _showOAuthConsentModal(context, ref, platform);
                }
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
                child: isSyncing 
                    ? const SizedBox(
                        width: 16, height: 16, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                      )
                    : Text(
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

  void _showDisconnectOption(BuildContext context, WidgetRef ref, PlatformConnection platform) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: platform.logoColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(platform.logoEmoji, style: AppTextStyles.titleMd.copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(platform.name, style: AppTextStyles.headlineSm),
                    Text('Connected Partner', style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blockMint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verified Data: ${platform.rating} Rating · ${platform.jobCount} Lifetime ${platform.jobLabel}',
                      style: AppTextStyles.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(platformsProvider.notifier).disconnectPlatform(platform.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Disconnected from ${platform.name}'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.link_off_rounded, color: AppColors.error),
                label: Text('Disconnect Platform', style: AppTextStyles.button.copyWith(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOAuthConsentModal(BuildContext context, WidgetRef ref, PlatformConnection platform) {
    final user = ref.read(currentUserProvider);
    final gigId = user?.id ?? 'gig-auth-id';
    final gigIdController = TextEditingController(text: gigId);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: platform.logoColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(platform.logoEmoji, style: AppTextStyles.headlineSm.copyWith(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${platform.name} OAuth Authorization', style: AppTextStyles.headlineSm),
                          Text('Simulated Partner Login', style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Consent Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PERMISSIONS REQUESTED BY GIGFOLIO',
                        style: AppTextStyles.eyebrow.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 10),
                      _PermissionRow(
                        icon: Icons.star_rate_rounded,
                        text: 'Read overall lifetime star rating & total completed jobs',
                      ),
                      const SizedBox(height: 8),
                      _PermissionRow(
                        icon: Icons.verified_rounded,
                        text: 'Verify account active driver/partner status',
                      ),
                      const SizedBox(height: 8),
                      _PermissionRow(
                        icon: Icons.shield_outlined,
                        text: 'Store zero sensitive credentials (OAuth Token only)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Input GigID
                Text('Connect via GigID (Supabase ID)', style: AppTextStyles.titleMd),
                const SizedBox(height: 8),
                TextField(
                  controller: gigIdController,
                  readOnly: true, // Typically this would be read-only since it's an SSO flow
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.fingerprint_rounded, color: AppColors.textSecondary),
                    hintText: 'Enter your GigID',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            
                            // Close bottom sheet
                            Navigator.pop(sheetCtx);

                            // Trigger Riverpod async connection
                            await ref.read(platformsProvider.notifier).connectPlatform(
                              platform.id,
                              rating: 4.8 + (platform.id.length % 3) * 0.1,
                              jobCount: 150 + platform.id.length * 35,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 10),
                                      Text('${platform.name} account successfully linked!'),
                                    ],
                                  ),
                                  backgroundColor: AppColors.statusVerifiedText,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: platform.logoColor == const Color(0xFF000000)
                          ? AppColors.primary
                          : platform.logoColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Authorize & Link ${platform.name}',
                            style: AppTextStyles.button.copyWith(color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PermissionRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTextStyles.bodySm.copyWith(color: AppColors.primary)),
        ),
      ],
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
