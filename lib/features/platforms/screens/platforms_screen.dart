import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/models.dart';
import '../../../shared/providers/auth_providers.dart';

final platformsProvider = StateNotifierProvider<PlatformsNotifier, List<PlatformConnection>>((ref) {
  return PlatformsNotifier();
});

class PlatformsNotifier extends StateNotifier<List<PlatformConnection>> {
  PlatformsNotifier() : super(const [
    PlatformConnection(
      id: 'p-uber', name: 'Uber', slug: 'uber',
      logoEmoji: 'U', logoColor: Color(0xFF000000),
      status: PlatformConnectionStatus.notConnected,
      rating: 4.8, jobCount: 240, jobLabel: 'trips', tier: 'Gold',
    ),
    PlatformConnection(
      id: 'p-zomato', name: 'Zomato', slug: 'zomato',
      logoEmoji: 'Z', logoColor: Color(0xFFCB202D),
      status: PlatformConnectionStatus.notConnected,
      rating: 4.6, jobCount: 180, jobLabel: 'deliveries', tier: 'Gold',
    ),
    PlatformConnection(
      id: 'p-rapido', name: 'Rapido', slug: 'rapido',
      logoEmoji: 'R', logoColor: Color(0xFFF9C111),
      status: PlatformConnectionStatus.notConnected,
      rating: 4.7, jobCount: 155, jobLabel: 'trips', tier: 'Gold',
    ),
    PlatformConnection(
      id: 'p-urbanclap', name: 'Urban Company', slug: 'urban_company',
      logoEmoji: 'UC', logoColor: Color(0xFF000000),
      status: PlatformConnectionStatus.notConnected,
      rating: 4.9, jobCount: 95, jobLabel: 'jobs', tier: 'Gold',
    ),
  ]);

  double _extractScore(Map<String, dynamic>? data, {double fallback = 4.8}) {
    if (data == null) return fallback;
    final val = data['platform_score'] ??
        data['platform_rating'] ??
        data['rating'] ??
        data['avg_rating'] ??
        data['score'] ??
        data['user_score'];
    if (val is num) {
      final d = val.toDouble();
      return d > 0 ? d : fallback;
    }
    if (val is String) {
      final d = double.tryParse(val);
      if (d != null && d > 0) return d;
    }
    return fallback;
  }

  int _extractJobCount(Map<String, dynamic>? data, {int fallback = 150}) {
    if (data == null) return fallback;
    final val = data['total_reviews'] ??
        data['total_trips'] ??
        data['job_count'] ??
        data['total_jobs'] ??
        data['review_count'] ??
        data['count'];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  String _extractTier(Map<String, dynamic>? data, {String fallback = 'Gold'}) {
    if (data == null) return fallback;
    final val = data['tier'] ?? data['platform_tier'] ?? data['user_tier'];
    return (val != null && val.toString().isNotEmpty) ? val.toString() : fallback;
  }

  Future<void> connectPlatform(String id, {required UserDbService dbService, required String userId, double rating = 4.8, int jobCount = 240}) async {
    // Set to syncing
    state = state.map((p) => p.id == id ? p.copyWith(status: PlatformConnectionStatus.syncing) : p).toList();
    
    // Simulate OAuth handshake & token exchange delay
    await Future.delayed(const Duration(milliseconds: 1500));

    final platform = state.firstWhere((p) => p.id == id, orElse: () => state.first);

    // Fetch initial RPC data if available
    final ratingData = await dbService.getWorkerPlatformRating(
      userId: userId,
      platformName: platform.name,
    );
    final recentReviews = await dbService.getPlatformRecentReviews(
      userId: userId,
      platformName: platform.name,
      limit: 5,
    );

    final platformScore = _extractScore(ratingData, fallback: platform.rating ?? rating);
    final tierStr = _extractTier(ratingData, fallback: platform.tier ?? 'Gold');
    final totalReviews = _extractJobCount(ratingData, fallback: platform.jobCount ?? jobCount);

    // Set to connected with verified RPC data
    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(
          status: PlatformConnectionStatus.connected,
          rating: platformScore,
          tier: tierStr,
          jobCount: totalReviews,
          recentReviews: recentReviews,
          jobLabel: (id == 'p-uber' || id == 'p-rapido') ? 'trips' : 'deliveries/jobs',
        );
      }
      return p;
    }).toList();
  }

  Future<void> syncPlatformWithRpc({
    required UserDbService dbService,
    required String userId,
    required String platformId,
  }) async {
    final platform = state.firstWhere((p) => p.id == platformId, orElse: () => state.first);
    final ratingData = await dbService.getWorkerPlatformRating(
      userId: userId,
      platformName: platform.name,
    );
    final recentReviews = await dbService.getPlatformRecentReviews(
      userId: userId,
      platformName: platform.name,
      limit: 5,
    );

    state = state.map((p) {
      if (p.id == platformId) {
        final platformScore = _extractScore(ratingData, fallback: p.rating ?? 4.8);
        final tierStr = _extractTier(ratingData, fallback: p.tier ?? 'Gold');
        final totalReviews = _extractJobCount(ratingData, fallback: p.jobCount ?? 150);

        return p.copyWith(
          rating: platformScore,
          tier: tierStr,
          jobCount: totalReviews,
          recentReviews: recentReviews,
        );
      }
      return p;
    }).toList();
  }

  void updatePlatformRating(String id, {required double newRating, int? jobCount, String? tier}) {
    state = state.map((p) {
      if (p.id == id) {
        return p.copyWith(
          rating: newRating,
          jobCount: jobCount ?? p.jobCount,
          tier: tier ?? p.tier,
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
          rating: p.rating,
          jobCount: p.jobCount,
          jobLabel: p.jobLabel,
          tier: p.tier,
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
                  if (isConnected)
                    Text(
                      '${(platform.rating ?? 4.8).toStringAsFixed(1)} ★ · ${platform.jobCount ?? 150} ${platform.jobLabel ?? 'trips'} · ${platform.tier ?? 'Gold'}',
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
    final user = ref.read(currentUserProvider);
    final dbService = ref.read(userDbServiceProvider);

    if (user != null) {
      // Refresh platform rating and recent reviews via RPC when opening modal
      ref.read(platformsProvider.notifier).syncPlatformWithRpc(
        dbService: dbService,
        userId: user.id,
        platformId: platform.id,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PlatformDetailsModalSheet(platform: platform),
    );
  }

  void _showOAuthConsentModal(BuildContext context, WidgetRef ref, PlatformConnection platform) {
    final user = ref.read(currentUserProvider);
    final uid = user?.id ?? 'supabase-uid';
    final uidController = TextEditingController(text: uid);
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

                // Input UID
                Text('Connect via UID (Supabase User ID)', style: AppTextStyles.titleMd),
                const SizedBox(height: 8),
                TextField(
                  controller: uidController,
                  readOnly: true, // Typically this would be read-only since it's an SSO flow
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.fingerprint_rounded, color: AppColors.textSecondary),
                    hintText: 'Enter your UID',
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
                            final dbService = ref.read(userDbServiceProvider);
                            await ref.read(platformsProvider.notifier).connectPlatform(
                              platform.id,
                              dbService: dbService,
                              userId: uid,
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

class _PlatformDetailsModalSheet extends ConsumerStatefulWidget {
  final PlatformConnection platform;
  const _PlatformDetailsModalSheet({required this.platform});

  @override
  ConsumerState<_PlatformDetailsModalSheet> createState() => _PlatformDetailsModalSheetState();
}

class _PlatformDetailsModalSheetState extends ConsumerState<_PlatformDetailsModalSheet> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _ratingData;
  List<Map<String, dynamic>> _recentReviews = [];

  double _selectedRating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  final TextEditingController _reviewerNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRpcData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _reviewerNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchRpcData() async {
    final user = ref.read(currentUserProvider);
    final dbService = ref.read(userDbServiceProvider);

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final ratingRes = await dbService.getWorkerPlatformRating(
      userId: user.id,
      platformName: widget.platform.name,
    );
    final reviewsRes = await dbService.getPlatformRecentReviews(
      userId: user.id,
      platformName: widget.platform.name,
      limit: 5,
    );

    if (mounted) {
      setState(() {
        _ratingData = ratingRes;
        _recentReviews = reviewsRes;
        _isLoading = false;
      });

      // Sync back with global platform provider state
      ref.read(platformsProvider.notifier).syncPlatformWithRpc(
        dbService: dbService,
        userId: user.id,
        platformId: widget.platform.id,
      );
    }
  }

  Future<void> _submitReview() async {
    final user = ref.read(currentUserProvider);
    final dbService = ref.read(userDbServiceProvider);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final platformName = widget.platform.name.trim().isEmpty ? 'Direct Client' : widget.platform.name;
    final reviewerName = _reviewerNameController.text.trim().isEmpty ? 'Anonymous' : _reviewerNameController.text;

    final response = await dbService.addUserRating(
      userId: user.id,
      rating: _selectedRating,
      reviewText: _reviewController.text,
      platformName: platformName,
      reviewerName: reviewerName,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response != null && response['success'] == true) {
      // 1. Invalidate reputation score provider to update overall GigFolio score
      ref.invalidate(userReputationScoreProvider);

      // 2. Update platform rating in local state immediately so UI reflects new rating
      final newTotalReviews = (response['total_reviews'] as num?)?.toInt() ?? (widget.platform.jobCount ?? 150) + 1;
      final newTier = response['tier']?.toString() ?? widget.platform.tier ?? 'Gold';

      ref.read(platformsProvider.notifier).updatePlatformRating(
        widget.platform.id,
        newRating: _selectedRating,
        jobCount: newTotalReviews,
        tier: newTier,
      );

      // 3. Refresh platform-specific rating & reviews from RPC
      await _fetchRpcData();

      // 4. Show success toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: AppColors.statusVerifiedText,
          ),
        );
      }

      _reviewController.clear();
      _reviewerNameController.clear();
    } else {
      // Never show success message if response is null or success !== true
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit review. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = widget.platform;

    final scoreVal = _ratingData?['platform_score'] ??
        _ratingData?['platform_rating'] ??
        _ratingData?['rating'] ??
        _ratingData?['avg_rating'] ??
        _ratingData?['score'];
    final double platformScore = (scoreVal is num && scoreVal > 0)
        ? scoreVal.toDouble()
        : (platform.rating ?? 4.8);

    final platformTier = _ratingData?['tier']?.toString() ?? platform.tier ?? 'Gold';
    final totalReviews = (_ratingData?['total_reviews'] as num?)?.toInt() ?? platform.jobCount ?? 150;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: platform.logoColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(platform.logoEmoji, style: AppTextStyles.headlineSm.copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(platform.name, style: AppTextStyles.headlineSm),
                      Text('Connected Partner', style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Verified Data Banner (Platform Specific Rating & Tier)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blockMint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'PLATFORM PERFORMANCE (${platform.name.toUpperCase()})',
                        style: AppTextStyles.eyebrow.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rating: ${platformScore.toStringAsFixed(1)} ★  ·  Tier: $platformTier  ·  $totalReviews Reviews',
                    style: AppTextStyles.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This score is specific to ${platform.name} and is managed independently of your global GigFolio score.',
                    style: AppTextStyles.bodySm.copyWith(color: AppColors.primary.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recent Reviews Section
            Text('RECENT REVIEWS', style: AppTextStyles.eyebrow),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (_recentReviews.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  'No recent reviews yet for ${platform.name}.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              Column(
                children: _recentReviews.map((rev) {
                  final reviewerName = rev['reviewer_name']?.toString() ?? 'Anonymous';
                  final ratingVal = (rev['rating'] as num?)?.toDouble() ?? 5.0;
                  final reviewText = rev['review']?.toString() ?? rev['review_text']?.toString() ?? '';
                  final createdAt = rev['created_at']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(reviewerName, style: AppTextStyles.labelLg),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                const SizedBox(width: 2),
                                Text(
                                  ratingVal.toStringAsFixed(1),
                                  style: AppTextStyles.labelLg.copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (reviewText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(reviewText, style: AppTextStyles.bodySm),
                        ],
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            createdAt.split('T').first,
                            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // Submit Review Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SUBMIT A REVIEW', style: AppTextStyles.eyebrow),
                  const SizedBox(height: 10),
                  Text('Select Rating (1 to 5 Stars)', style: AppTextStyles.labelLg),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(5, (index) {
                      final starVal = index + 1.0;
                      return IconButton(
                        iconSize: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          starVal <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() => _selectedRating = starVal);
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reviewerNameController,
                    decoration: InputDecoration(
                      hintText: 'Reviewer Name (Optional, defaults to Anonymous)',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _reviewController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Review text (Optional)',
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.cardBorder),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitReview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text('Submit Review for ${platform.name}', style: AppTextStyles.button.copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Disconnect Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
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
}
