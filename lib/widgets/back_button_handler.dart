import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Navigation Observer that handles double-back-to-exit
class BackButtonNavigationObserver extends NavigatorObserver {
  static const _exitInterval = Duration(seconds: 2);
  DateTime? _lastBackPressTime;
  Timer? _backPressTimer;
  BuildContext? _context;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _context = route.navigator?.context;
  }

  bool handlePopInvoked(bool didPop, BuildContext? context) {
    if (didPop) return true;

    final ctx = context ?? _context;
    if (ctx == null) return false;

    // Check if we're in the main shell (dashboard, orders, etc.)
    final router = GoRouter.of(ctx);
    final location = router.routerDelegate.currentConfiguration.uri.path;

    // Only handle back for main shell routes
    if (!location.startsWith('/dashboard') &&
        !location.startsWith('/orders') &&
        !location.startsWith('/customers') &&
        !location.startsWith('/calendar') &&
        !location.startsWith('/profile')) {
      return false; // Let normal navigation handle it
    }

    // Check if we're on dashboard or another screen
    final isOnDashboard =
        location == '/dashboard' || location.startsWith('/dashboard?');

    // If not on dashboard, navigate back to dashboard
    if (!isOnDashboard) {
      router.go('/dashboard');
      _lastBackPressTime = null;
      _backPressTimer?.cancel();
      return true; // Prevent default back
    }

    // We're on dashboard - implement double-back-to-exit
    final now = DateTime.now();

    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < _exitInterval) {
      // Second back press - exit app
      _backPressTimer?.cancel();
      SystemNavigator.pop();
      return true; // Prevent default back
    }

    // First back press - show message
    _lastBackPressTime = now;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text(
          'Press back again to exit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: _exitInterval,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    _backPressTimer?.cancel();
    _backPressTimer = Timer(_exitInterval, () {
      _lastBackPressTime = null;
    });

    return true; // Prevent default back
  }

  void dispose() {
    _backPressTimer?.cancel();
  }
}
