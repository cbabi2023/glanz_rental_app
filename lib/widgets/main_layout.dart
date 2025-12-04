import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Main Layout with Bottom Navigation Bar
///
/// Wraps main screens (Dashboard, Orders, Customers, Profile) with bottom navigation
/// Uses StatefulShellBranch to maintain state and provide smooth navigation
class MainLayout extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({super.key, required this.navigationShell});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static const _exitInterval = Duration(seconds: 2);
  DateTime? _lastBackPressTime;
  Timer? _backPressTimer;

  @override
  void dispose() {
    _backPressTimer?.cancel();
    super.dispose();
  }

  /// Handles back button press with double-back-to-exit mechanism
  Future<void> _handleBackPress() async {
    // If we're not on the dashboard (branch index 0), navigate back to dashboard first
    final currentIndex = widget.navigationShell.currentIndex;
    if (currentIndex != 0) {
      // Navigate back to dashboard branch
      widget.navigationShell.goBranch(0);
      // Reset the exit timer since we navigated
      _lastBackPressTime = null;
      _backPressTimer?.cancel();
      return;
    }

    // We're on the dashboard - implement double-back-to-exit
    final now = DateTime.now();

    // Check if this is the second back press within the exit interval
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < _exitInterval) {
      // Second back press within interval - exit the app
      _backPressTimer?.cancel();
      SystemNavigator.pop();
      return;
    }

    // First back press - show toast message and start timer
    _lastBackPressTime = now;

    // Show toast message
    ScaffoldMessenger.of(context).showSnackBar(
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

    // Reset timer after exit interval expires
    _backPressTimer?.cancel();
    _backPressTimer = Timer(_exitInterval, () {
      if (mounted) {
        setState(() {
          _lastBackPressTime = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // Handle both button back and gesture back
        // Using onPopInvokedWithResult for better gesture back support
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: (index) {
            widget.navigationShell.goBranch(
              index,
              // If the branch is already active, prevent navigation
              initialLocation: index == widget.navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
