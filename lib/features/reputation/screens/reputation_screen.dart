import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/models/models.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/providers/auth_providers.dart';

class ReputationScreen extends ConsumerWidget {
  const ReputationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scoreAsync = ref.watch(userReputationScoreProvider);

    final score = scoreAsync.value ??
        const ReputationScore(
          compositeScore: 4.8,
          tag: ReputationTag.excellent,
          confidence: ConfidenceTier.high,
          confidenceIndex: 0.94,
          isProvisional: false,
          subscoreRating: 0.91,
          subscoreVolume: 0.85,
          subscoreReliability: 0.92,
          subscoreConsistency: 0.78,
          subscoreSkills: 0.60,
          message: '',
        );

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surfaceCanvas,
            toolbarHeight: 60,
            title: Text('Gigfolio Score', style: AppTextStyles.headlineSm),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Hero Score Block (Navy — DESIGN.md block-navy) ─────────────
                _HeroScoreBlock(score: score)
                    .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 20),

                // ── Score Range Bar ────────────────────────────────────────────
                _ScoreRangeBar(score: score.compositeScore)
                    .animate(delay: 100.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Subscores breakdown ────────────────────────────────────────
                _SectionLabel(text: 'SCORE BREAKDOWN'),
                const SizedBox(height: 10),
                _SubscoreCard(score: score)
                    .animate(delay: 150.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Reputation tags reference block (lime — DESIGN.md block-lime) ─
                _ReputationTagsBlock()
                    .animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── What factors count ─────────────────────────────────────────
                _SectionLabel(text: 'WHAT COUNTS'),
                const SizedBox(height: 10),
                _FactorsCard()
                    .animate(delay: 250.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 20),

                // ── Provisional note ───────────────────────────────────────────
                _ProvisionalNote()
                    .animate(delay: 300.ms).fadeIn(duration: 400.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroScoreBlock extends StatelessWidget {
  final ReputationScore score;
  const _HeroScoreBlock({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.blockNavy,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'GIGFOLIO SCORE',
            style: AppTextStyles.eyebrow.copyWith(color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 16),
          Text(
            score.compositeScore.toStringAsFixed(1),
            style: AppTextStyles.scoreDisplay.copyWith(
              color: Colors.white,
              fontSize: 80,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'out of 5.0',
            style: AppTextStyles.bodySm.copyWith(color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),

          // Tag + confidence row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: score.tag.bgColor,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: score.tag.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(color: score.tag.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      score.tag.label,
                      style: AppTextStyles.labelLg.copyWith(color: score.tag.color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, size: 14, color: score.confidence.color),
                    const SizedBox(width: 4),
                    Text(
                      '${score.confidence.label} Confidence',
                      style: AppTextStyles.labelLg.copyWith(color: Colors.white.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRangeBar extends StatelessWidget {
  final double score;
  const _ScoreRangeBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final normalised = score / 5.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score Range (0.0 – 5.0)', style: AppTextStyles.titleMd),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                // Background gradient bar
                Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.reputationWorst,
                        AppColors.reputationPoor,
                        AppColors.reputationAverage,
                        AppColors.reputationGood,
                        AppColors.reputationExcellent,
                      ],
                    ),
                  ),
                ),
                // Marker
                Positioned(
                  left: (MediaQuery.of(context).size.width - 72) * normalised - 1,
                  child: Container(
                    width: 4, height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0.0', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text('5.0', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubscoreCard extends StatelessWidget {
  final ReputationScore score;
  const _SubscoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final subscores = [
      _Subscore('Rating Quality', score.subscoreRating, 0.35, AppColors.reputationExcellent, Icons.star_outline_rounded),
      _Subscore('Job Volume', score.subscoreVolume, 0.20, AppColors.reputationGood, Icons.work_outline_rounded),
      _Subscore('Reliability', score.subscoreReliability, 0.25, AppColors.blockLilac, Icons.verified_outlined),
      _Subscore('Consistency', score.subscoreConsistency, 0.10, AppColors.statusPendingAccent, Icons.timeline_rounded),
      _Subscore('Skills', score.subscoreSkills, 0.10, AppColors.reputationPoor, Icons.psychology_outlined),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: subscores.asMap().entries.map((e) {
          final s = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: s.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s.icon, size: 18, color: s.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.label, style: AppTextStyles.titleMd),
                                  Text(
                                    '${(s.value * 100).toInt()}%  ·  weight ${(s.weight * 100).toInt()}%',
                                    style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: s.value,
                                  minHeight: 6,
                                  backgroundColor: AppColors.hairlineSoft,
                                  valueColor: AlwaysStoppedAnimation<Color>(s.color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (e.key < subscores.length - 1)
                const Divider(height: 1, indent: 64, color: AppColors.hairlineSoft),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _Subscore {
  final String label;
  final double value;
  final double weight;
  final Color color;
  final IconData icon;
  const _Subscore(this.label, this.value, this.weight, this.color, this.icon);
}

class _ReputationTagsBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tags = [
      (ReputationTag.excellent, '4.5 – 5.0'),
      (ReputationTag.good, '4.0 – 4.4'),
      (ReputationTag.average, '3.0 – 3.9'),
      (ReputationTag.poor, '2.0 – 2.9'),
      (ReputationTag.worst, '0.0 – 1.9'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blockLime,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REPUTATION TIERS',
            style: AppTextStyles.eyebrow.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text('Understanding your score', style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary)),
          const SizedBox(height: 16),
          ...tags.map((t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(color: t.$1.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.$1.label, style: AppTextStyles.bodyMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  Text(t.$2, style: AppTextStyles.bodyMd.copyWith(color: AppColors.primary.withOpacity(0.7))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FactorsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final factors = [
      (Icons.star_outline_rounded, 'Rating Quality', '35% of score', 'Bayesian-adjusted average across platforms'),
      (Icons.work_outline_rounded, 'Job Volume', '20% of score', 'Total verified completed jobs'),
      (Icons.verified_outlined, 'Reliability', '25% of score', 'Completion rate with cancellation penalty'),
      (Icons.timeline_rounded, 'Consistency', '10% of score', 'Recent 52-week activity with recency decay'),
      (Icons.psychology_outlined, 'Skills', '10% of score', 'Verified skill certifications weighted by category'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: factors.asMap().entries.map((e) {
          final f = e.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(f.$1, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(f.$2, style: AppTextStyles.titleMd),
                              Text(f.$3, style: AppTextStyles.labelLg.copyWith(color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(f.$4, style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (e.key < factors.length - 1)
                const Divider(height: 1, indent: 64, color: AppColors.hairlineSoft),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ProvisionalNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusPendingBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusPendingBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.statusPendingText),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provisional Score',
                  style: AppTextStyles.titleMd.copyWith(color: AppColors.statusPendingText),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connect your gig platforms to improve your score accuracy. The more verified data, the higher your confidence tier.',
                  style: AppTextStyles.bodySm.copyWith(color: AppColors.statusPendingText),
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
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.eyebrow,
    );
  }
}
