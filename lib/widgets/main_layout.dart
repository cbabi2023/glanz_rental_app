import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile.dart';

/// Main Layout with Bottom Navigation Bar
///
/// Wraps main screens (Dashboard, Orders, Customers, Profile) with bottom navigation
/// Uses StatefulShellBranch to maintain state and provide smooth navigation
class MainLayout extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainLayout({super.key, required this.navigationShell});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  /// Get navigation destinations based on user role
  List<NavigationDestination> _getDestinations(UserProfile? profile) {
    final isStaff = profile?.isStaff ?? false;

    if (isStaff) {
      // Staff: Orders, Calendar, Customers, Profile (no Dashboard)
      return const [
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_today_outlined),
          selectedIcon: Icon(Icons.calendar_today),
          label: 'Calendar',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: 'Customers',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    } else {
      // Admin/Branch Admin: All items including Dashboard
      return const [
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
      ];
    }
  }

  /// Map navigation index to actual branch index based on role
  int _mapNavigationIndexToBranchIndex(int navIndex, UserProfile? profile) {
    final isStaff = profile?.isStaff ?? false;

    if (isStaff) {
      // Staff navigation: 0=Orders, 1=Calendar, 2=Customers, 3=Profile
      // Branch indices: 0=Dashboard, 1=Orders, 2=Customers, 3=Calendar, 4=Profile
      switch (navIndex) {
        case 0:
          return 1; // Orders
        case 1:
          return 3; // Calendar
        case 2:
          return 2; // Customers
        case 3:
          return 4; // Profile
        default:
          return navIndex;
      }
    } else {
      // Admin: Direct mapping (0=Dashboard, 1=Orders, 2=Customers, 3=Calendar, 4=Profile)
      return navIndex;
    }
  }

  /// Map branch index to navigation index based on role
  int _mapBranchIndexToNavigationIndex(int branchIndex, UserProfile? profile) {
    final isStaff = profile?.isStaff ?? false;

    if (isStaff) {
      // Branch indices: 0=Dashboard, 1=Orders, 2=Customers, 3=Calendar, 4=Profile
      // Staff navigation: 0=Orders, 1=Calendar, 2=Customers, 3=Profile
      switch (branchIndex) {
        case 1:
          return 0; // Orders
        case 3:
          return 1; // Calendar
        case 2:
          return 2; // Customers
        case 4:
          return 3; // Profile
        default:
          return 0; // Default to Orders for staff
      }
    } else {
      // Admin: Direct mapping
      return branchIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: profileAsync.when(
        data: (profile) {
          final isStaff = profile?.isStaff ?? false;

          // If staff user is on Dashboard branch (index 0), redirect to Orders
          if (isStaff && widget.navigationShell.currentIndex == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.navigationShell.goBranch(1); // Redirect to Orders
            });
          }

          final destinations = _getDestinations(profile);
          final currentNavIndex = _mapBranchIndexToNavigationIndex(
            widget.navigationShell.currentIndex,
            profile,
          );

          return NavigationBar(
            selectedIndex: currentNavIndex.clamp(0, destinations.length - 1),
            onDestinationSelected: (index) {
              final branchIndex = _mapNavigationIndexToBranchIndex(
                index,
                profile,
              );
              // Prevent staff from accessing Dashboard branch
              if (isStaff && branchIndex == 0) {
                return; // Don't navigate to Dashboard
              }
              widget.navigationShell.goBranch(
                branchIndex,
                // If the branch is already active, prevent navigation
                initialLocation:
                    branchIndex == widget.navigationShell.currentIndex,
              );
            },
            destinations: destinations,
          );
        },
        loading: () {
          // While loading, show minimal navigation (Orders, Calendar, Customers, Profile)
          // This prevents Dashboard from showing during load
          return NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex == 0
                ? 0
                : (widget.navigationShell.currentIndex > 0
                          ? widget.navigationShell.currentIndex - 1
                          : 0)
                      .clamp(0, 3),
            onDestinationSelected: (index) {
              // Map to branch indices: 0->1 (Orders), 1->3 (Calendar), 2->2 (Customers), 3->4 (Profile)
              final branchMap = [1, 3, 2, 4];
              final branchIndex = index < branchMap.length
                  ? branchMap[index]
                  : 1;
              widget.navigationShell.goBranch(
                branchIndex,
                initialLocation:
                    branchIndex == widget.navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Customers',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
        error: (_, __) {
          // On error, show staff navigation (no Dashboard) as safe fallback
          return NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex == 0
                ? 0
                : (widget.navigationShell.currentIndex > 0
                          ? widget.navigationShell.currentIndex - 1
                          : 0)
                      .clamp(0, 3),
            onDestinationSelected: (index) {
              // Map to branch indices: 0->1 (Orders), 1->3 (Calendar), 2->2 (Customers), 3->4 (Profile)
              final branchMap = [1, 3, 2, 4];
              final branchIndex = index < branchMap.length
                  ? branchMap[index]
                  : 1;
              // Prevent navigation to Dashboard (branch 0)
              if (branchIndex == 0) {
                return;
              }
              widget.navigationShell.goBranch(
                branchIndex,
                initialLocation:
                    branchIndex == widget.navigationShell.currentIndex,
              );
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Customers',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}
