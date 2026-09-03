import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/reputation/screens/reputation_screen.dart';
import '../../features/platforms/screens/platforms_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../constants/app_constants.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: false,
    routes: [
      // ─── Splash ────────────────────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeSplash,
        builder: (_, __) => const SplashScreen(),
      ),

      // ─── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeWelcome,
        pageBuilder: (_, state) => _fadeTransition(state, const WelcomeScreen()),
      ),
      GoRoute(
        path: AppConstants.routeLogin,
        pageBuilder: (_, state) => _slideTransition(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppConstants.routeRegister,
        pageBuilder: (_, state) => _slideTransition(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppConstants.routeForgotPassword,
        pageBuilder: (_, state) => _slideTransition(state, const ForgotPasswordScreen()),
      ),

      // ─── Onboarding ────────────────────────────────────────────────────────
      GoRoute(
        path: AppConstants.routeOnboarding,
        pageBuilder: (_, state) => _fadeTransition(state, const OnboardingScreen()),
      ),

      // ─── Main Shell (Bottom Nav) ────────────────────────────────────────────
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (_, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppConstants.routeDashboard,
            pageBuilder: (_, state) => _noTransition(state, const DashboardScreen()),
          ),
          GoRoute(
            path: AppConstants.routeReputation,
            pageBuilder: (_, state) => _noTransition(state, const ReputationScreen()),
          ),
          GoRoute(
            path: AppConstants.routePlatforms,
            pageBuilder: (_, state) => _noTransition(state, const PlatformsScreen()),
          ),
          GoRoute(
            path: AppConstants.routeProfile,
            pageBuilder: (_, state) => _noTransition(state, const ProfileScreen()),
          ),
          GoRoute(
            path: AppConstants.routeSettings,
            pageBuilder: (_, state) => _noTransition(state, const SettingsScreen()),
          ),
        ],
      ),

      // ─── Edit Profile (Full-screen push) ───────────────────────────────────
      GoRoute(
        path: '/profile/edit',
        parentNavigatorKey: _rootKey,
        pageBuilder: (_, state) => _slideTransition(state, const EditProfileScreen()),
      ),
    ],
  );
});

CustomTransitionPage<void> _fadeTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, widget) =>
        FadeTransition(opacity: animation, child: widget),
    transitionDuration: const Duration(milliseconds: 280),
  );
}

CustomTransitionPage<void> _slideTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, animation, __, widget) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: widget);
    },
    transitionDuration: const Duration(milliseconds: 340),
  );
}

CustomTransitionPage<void> _noTransition(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (_, __, ___, widget) => widget,
    transitionDuration: Duration.zero,
  );
}
