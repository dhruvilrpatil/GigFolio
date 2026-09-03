import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

enum ReputationTag {
  excellent,
  good,
  average,
  poor,
  worst,
}

extension ReputationTagX on ReputationTag {
  String get label {
    switch (this) {
      case ReputationTag.excellent: return 'Excellent';
      case ReputationTag.good: return 'Good';
      case ReputationTag.average: return 'Average';
      case ReputationTag.poor: return 'Poor';
      case ReputationTag.worst: return 'Worst';
    }
  }

  Color get color {
    switch (this) {
      case ReputationTag.excellent: return AppColors.reputationExcellent;
      case ReputationTag.good: return AppColors.reputationGood;
      case ReputationTag.average: return AppColors.reputationAverage;
      case ReputationTag.poor: return AppColors.reputationPoor;
      case ReputationTag.worst: return AppColors.reputationWorst;
    }
  }

  Color get bgColor {
    switch (this) {
      case ReputationTag.excellent: return AppColors.statusVerifiedBg;
      case ReputationTag.good: return const Color(0xFFF0FDFA);
      case ReputationTag.average: return AppColors.statusPendingBg;
      case ReputationTag.poor: return const Color(0xFFFFF7ED);
      case ReputationTag.worst: return AppColors.statusExpiredBg;
    }
  }

  Color get borderColor {
    switch (this) {
      case ReputationTag.excellent: return AppColors.statusVerifiedBorder;
      case ReputationTag.good: return const Color(0xFF99F6E4);
      case ReputationTag.average: return AppColors.statusPendingBorder;
      case ReputationTag.poor: return const Color(0xFFFED7AA);
      case ReputationTag.worst: return AppColors.statusExpiredBorder;
    }
  }
}

enum ConfidenceTier { low, medium, high, provisional }

extension ConfidenceTierX on ConfidenceTier {
  String get label {
    switch (this) {
      case ConfidenceTier.low: return 'Low';
      case ConfidenceTier.medium: return 'Medium';
      case ConfidenceTier.high: return 'High';
      case ConfidenceTier.provisional: return 'Provisional';
    }
  }

  Color get color {
    switch (this) {
      case ConfidenceTier.high: return AppColors.statusVerifiedText;
      case ConfidenceTier.medium: return AppColors.statusPendingText;
      case ConfidenceTier.low: return AppColors.statusInactiveText;
      case ConfidenceTier.provisional: return AppColors.statusPendingText;
    }
  }
}

class ReputationScore {
  final double compositeScore;
  final ReputationTag tag;
  final ConfidenceTier confidence;
  final double confidenceIndex;
  final bool isProvisional;
  final double subscoreRating;
  final double subscoreVolume;
  final double subscoreReliability;
  final double subscoreConsistency;
  final double subscoreSkills;
  final String message;

  const ReputationScore({
    required this.compositeScore,
    required this.tag,
    required this.confidence,
    required this.confidenceIndex,
    required this.isProvisional,
    required this.subscoreRating,
    required this.subscoreVolume,
    required this.subscoreReliability,
    required this.subscoreConsistency,
    required this.subscoreSkills,
    required this.message,
  });

  /// Factory: Provisional Baseline for zero-data workers
  factory ReputationScore.provisional() {
    return const ReputationScore(
      compositeScore: ReputationConfig.provisionalScore,
      tag: ReputationTag.average,
      confidence: ConfidenceTier.provisional,
      confidenceIndex: 0.0,
      isProvisional: true,
      subscoreRating: 0,
      subscoreVolume: 0,
      subscoreReliability: 0,
      subscoreConsistency: 0,
      subscoreSkills: 0,
      message: AppConstants.provisionalMessage,
    );
  }

  static ReputationTag tagFromScore(double score) {
    if (score >= ReputationConfig.thresholdExcellent) return ReputationTag.excellent;
    if (score >= ReputationConfig.thresholdGood) return ReputationTag.good;
    if (score >= ReputationConfig.thresholdAverage) return ReputationTag.average;
    if (score >= ReputationConfig.thresholdPoor) return ReputationTag.poor;
    return ReputationTag.worst;
  }
}

class WorkerProfile {
  final String id;
  final String userId;
  final String legalName;
  final String? photoUrl;
  final String? email;
  final String? phone;
  final String? location;
  final List<String> skills;
  final List<String> workCategories;
  final double profileCompleteness;
  final String identityStatus;
  final String? qrCodeData;
  final String? qrCodeUrl;

  const WorkerProfile({
    required this.id,
    required this.userId,
    required this.legalName,
    this.photoUrl,
    this.email,
    this.phone,
    this.location,
    this.skills = const [],
    this.workCategories = const [],
    this.profileCompleteness = 0.0,
    this.identityStatus = 'Not Verified',
    this.qrCodeData,
    this.qrCodeUrl,
  });

  String get effectiveQrCodeData => qrCodeData ?? 'https://gigfolio.app/verify/$userId';

  String get initials {
    final parts = legalName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  WorkerProfile copyWith({
    String? legalName,
    String? photoUrl,
    String? phone,
    String? location,
    List<String>? skills,
    List<String>? workCategories,
    double? profileCompleteness,
  }) {
    return WorkerProfile(
      id: id,
      userId: userId,
      legalName: legalName ?? this.legalName,
      photoUrl: photoUrl ?? this.photoUrl,
      email: email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      skills: skills ?? this.skills,
      workCategories: workCategories ?? this.workCategories,
      profileCompleteness: profileCompleteness ?? this.profileCompleteness,
      identityStatus: identityStatus,
    );
  }
}

enum PlatformConnectionStatus { connected, notConnected, syncing, error }

class PlatformConnection {
  final String id;
  final String name;
  final String slug;
  final String logoEmoji;
  final Color logoColor;
  final PlatformConnectionStatus status;
  final double? rating;
  final int? jobCount;
  final String? jobLabel;

  const PlatformConnection({
    required this.id,
    required this.name,
    required this.slug,
    required this.logoEmoji,
    required this.logoColor,
    required this.status,
    this.rating,
    this.jobCount,
    this.jobLabel,
  });

  PlatformConnection copyWith({
    PlatformConnectionStatus? status,
    double? rating,
    int? jobCount,
    String? jobLabel,
  }) {
    return PlatformConnection(
      id: id,
      name: name,
      slug: slug,
      logoEmoji: logoEmoji,
      logoColor: logoColor,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      jobCount: jobCount ?? this.jobCount,
      jobLabel: jobLabel ?? this.jobLabel,
    );
  }

  String get statusLabel {
    switch (status) {
      case PlatformConnectionStatus.connected: return 'Connected';
      case PlatformConnectionStatus.notConnected: return 'Not Connected';
      case PlatformConnectionStatus.syncing: return 'Syncing…';
      case PlatformConnectionStatus.error: return 'Error';
    }
  }
}
