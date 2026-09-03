/// GigFolio Score calculation constants
class ReputationConfig {
  ReputationConfig._();

  // Bayesian prior parameters
  static const double priorMean = 0.85; // m
  static const double priorWeight = 25.0; // C (confidence threshold)

  // Score range
  static const double scoreMin = 0.0;
  static const double scoreMax = 5.0;
  static const double scoreRange = 5.0;

  // Provisional baseline (new worker)
  static const double provisionalScore = 2.5;

  // Subscore weights
  static const double weightRating = 0.35;
  static const double weightVolume = 0.20;
  static const double weightReliability = 0.25;
  static const double weightConsistency = 0.10;
  static const double weightSkills = 0.10;

  // Volume benchmark
  static const double volumeBenchmark = 1000.0;

  // Confidence TTL (seconds)
  static const int scoreTtlSeconds = 300;

  // Reputation tag thresholds
  static const double thresholdExcellent = 4.5;
  static const double thresholdGood = 4.0;
  static const double thresholdAverage = 3.0;
  static const double thresholdPoor = 2.0;
  // Below 420 → Worst

  // Confidence tiers
  static const double confidenceLowMax = 0.34;
  static const double confidenceMediumMax = 0.67;
  // >= 0.67 → High

  // Provisional threshold
  static const int provisionalReviewCount = 5;
}

/// App-level constants
class AppConstants {
  AppConstants._();

  static const String appName = 'GigFolio';
  static const String appTagline = 'Your Portable Work Identity';
  static const String gigfolioIdBrand = 'Gigfolio ID';

  // API versioning
  static const String apiVersion = 'v1';
  static const String apiBase = '/api/$apiVersion';

  // Route names
  static const String routeSplash = '/';
  static const String routeWelcome = '/welcome';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeOnboarding = '/onboarding';
  static const String routeDashboard = '/dashboard';
  static const String routeProfile = '/profile';
  static const String routeReputation = '/reputation';
  static const String routePlatforms = '/platforms';
  static const String routeSettings = '/settings';

  // Platform catalog
  static const List<String> platformSlugs = ['uber', 'doordash', 'upwork'];

  // Score placeholder message
  static const String provisionalMessage =
      'Your Gigfolio Score will improve as verified activity is added to your profile.';
}
