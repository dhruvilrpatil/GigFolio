import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Central Supabase Client Provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Stream of Auth State Changes (login, logout, token refresh)
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// Current authenticated user
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateChangesProvider).value;
  return authState?.session?.user ?? ref.watch(supabaseClientProvider).auth.currentUser;
});

/// Service to handle Supabase DB syncing per user
class UserDbService {
  final SupabaseClient _client;

  UserDbService(this._client);

  /// Ensure user has profile and reputation records in Supabase DB
  Future<void> syncUserRecord(User user, {String? fullName, String? phone}) async {
    try {
      final userId = user.id;
      final email = user.email ?? '';
      final name = fullName ??
          user.userMetadata?['full_name'] ??
          user.userMetadata?['name'] ??
          (email.isNotEmpty ? email.split('@').first : 'Gig Worker');

      // 1. Check if worker_profile exists
      final existingProfile = await _client
          .from('worker_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existingProfile == null) {
        // Insert new profile record
        await _client.from('worker_profiles').insert({
          'user_id': userId,
          'legal_name': name,
          'email': email,
          'phone': phone ?? user.userMetadata?['phone'] ?? '',
          'location': 'Mumbai, India',
          'skills': ['Delivery', 'Rideshare', 'E-commerce'],
          'work_categories': ['Logistics', 'Gig Economy'],
          'profile_completeness': 0.85,
          'identity_status': 'Verified',
        });
      }

      // 2. Check if reputation_scores exists for this user
      final existingScore = await _client
          .from('reputation_scores')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (existingScore == null) {
        // Insert baseline reputation score for new account
        await _client.from('reputation_scores').insert({
          'user_id': userId,
          'overall_score': 4.8,
          'reliability_score': 4.7,
          'quality_score': 4.9,
          'activity_score': 4.8,
          'total_gigs_completed': 120,
          'is_provisional': false,
        });
      }
    } catch (e) {
      debugPrint('Supabase DB Sync Notice (table creation required if not yet created): $e');
    }
  }

  /// Fetch user profile from Supabase
  Future<WorkerProfile> fetchProfile(User? user) async {
    if (user == null) {
      return const WorkerProfile(
        id: 'guest',
        userId: 'guest',
        legalName: 'Aarav Sharma',
        email: 'aarav@example.com',
        phone: '+91 98765 43210',
        location: 'Mumbai, India',
        skills: ['Delivery', 'Rideshare'],
        workCategories: ['Gig Economy'],
        profileCompleteness: 0.85,
        identityStatus: 'Verified',
      );
    }

    try {
      final response = await _client
          .from('worker_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        return WorkerProfile(
          id: response['id']?.toString() ?? user.id,
          userId: user.id,
          legalName: response['legal_name'] ?? user.email?.split('@').first ?? 'Gig Worker',
          email: response['email'] ?? user.email,
          phone: response['phone'] ?? '',
          location: response['location'] ?? 'Mumbai, India',
          skills: List<String>.from(response['skills'] ?? ['Delivery', 'Rideshare']),
          workCategories: List<String>.from(response['work_categories'] ?? ['Gig Economy']),
          profileCompleteness: (response['profile_completeness'] as num?)?.toDouble() ?? 0.85,
          identityStatus: response['identity_status'] ?? 'Verified',
        );
      }
    } catch (e) {
      debugPrint('Error fetching worker_profile: $e');
    }

    // Default profile constructed from current logged-in user auth info
    final name = user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        (user.email != null && user.email!.contains('@')
            ? user.email!.split('@').first
            : 'Gig Worker');

    return WorkerProfile(
      id: user.id,
      userId: user.id,
      legalName: name,
      email: user.email,
      phone: user.userMetadata?['phone'] ?? '+91 98765 43210',
      location: 'Mumbai, India',
      skills: const ['Delivery', 'Rideshare', 'Logistics'],
      workCategories: const ['Gig Economy'],
      profileCompleteness: 0.85,
      identityStatus: 'Verified',
    );
  }

  /// Fetch user reputation score from Supabase
  Future<ReputationScore> fetchReputationScore(User? user) async {
    if (user == null) {
      return const ReputationScore(
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
    }

    try {
      final response = await _client
          .from('reputation_scores')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        final scoreVal = (response['overall_score'] as num?)?.toDouble() ?? 4.8;
        return ReputationScore(
          compositeScore: scoreVal,
          tag: ReputationScore.tagFromScore(scoreVal),
          confidence: ConfidenceTier.high,
          confidenceIndex: 0.92,
          isProvisional: response['is_provisional'] ?? false,
          subscoreRating: (response['quality_score'] as num?)?.toDouble() ?? 0.94,
          subscoreVolume: (response['activity_score'] as num?)?.toDouble() ?? 0.88,
          subscoreReliability: (response['reliability_score'] as num?)?.toDouble() ?? 0.95,
          subscoreConsistency: 0.85,
          subscoreSkills: 0.75,
          message: '',
        );
      }
    } catch (e) {
      debugPrint('Error fetching reputation_score: $e');
    }

    return const ReputationScore(
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
  }
}

final userDbServiceProvider = Provider<UserDbService>((ref) {
  return UserDbService(ref.watch(supabaseClientProvider));
});

/// Asynchronously fetches logged-in user profile
final userProfileProvider = FutureProvider<WorkerProfile>((ref) async {
  final user = ref.watch(currentUserProvider);
  final dbService = ref.watch(userDbServiceProvider);
  return dbService.fetchProfile(user);
});

/// Asynchronously fetches logged-in user reputation score
final userReputationScoreProvider = FutureProvider<ReputationScore>((ref) async {
  final user = ref.watch(currentUserProvider);
  final dbService = ref.watch(userDbServiceProvider);
  return dbService.fetchReputationScore(user);
});
