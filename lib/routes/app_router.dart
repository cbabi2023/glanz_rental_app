import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/orders/orders_list_screen.dart';
import '../screens/orders/create_order_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/edit_order_screen.dart';
import '../screens/orders/order_return_screen.dart';
import '../screens/customers/customers_list_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/customers/create_customer_screen.dart';
import '../screens/customers/edit_customer_screen.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/branches/branches_list_screen.dart';
import '../screens/staff/staff_list_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/profile_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/main_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App Router Configuration
///
/// Defines all routes and navigation logic for the app
/// Uses StatefulShellRoute for smooth bottom navigation
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull?.session != null;
      final isGoingToLogin = state.matchedLocation == '/login';

      // If not authenticated and not going to login, redirect to login
      if (!isAuthenticated && !isGoingToLogin) {
        return '/login';
      }

      // If authenticated and going to login, redirect to dashboard
      if (isAuthenticated && isGoingToLogin) {
        return '/dashboard';
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Main navigation shell with bottom nav bar
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayout(navigationShell: navigationShell);
        },
        branches: [
          // Dashboard branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          // Orders branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                name: 'orders',
                builder: (context, state) => const OrdersListScreen(),
              ),
            ],
          ),
          // Customers branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/customers',
                name: 'customers',
                builder: (context, state) => const CustomersListScreen(),
              ),
            ],
          ),
          // Calendar branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                name: 'calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          // Profile branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Detail and edit routes outside shell (full-screen navigation)
      GoRoute(
        path: '/orders/new',
        name: 'create-order',
        builder: (context, state) => const CreateOrderScreen(),
      ),
      GoRoute(
        path: '/orders/:id',
        name: 'order-detail',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          final scrollToItems = state.uri.queryParameters['scrollToItems'] == 'true';
          return OrderDetailScreen(
            orderId: orderId,
            scrollToItems: scrollToItems,
          );
        },
      ),
      GoRoute(
        path: '/orders/:id/return',
        name: 'order-return',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return OrderReturnScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/orders/:id/edit',
        name: 'edit-order',
        builder: (context, state) {
          final orderId = state.pathParameters['id']!;
          return EditOrderScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/customers/new',
        name: 'create-customer',
        builder: (context, state) => const CreateCustomerScreen(),
      ),
      GoRoute(
        path: '/customers/:id',
        name: 'customer-detail',
        builder: (context, state) {
          final customerId = state.pathParameters['id']!;
          return CustomerDetailScreen(customerId: customerId);
        },
      ),
      GoRoute(
        path: '/customers/:id/edit',
        name: 'edit-customer',
        builder: (context, state) {
          final customerId = state.pathParameters['id']!;
          return EditCustomerScreen(customerId: customerId);
        },
      ),
      // Branch Management Routes
      GoRoute(
        path: '/branches',
        name: 'branches',
        builder: (context, state) => const BranchesListScreen(),
      ),
      // Staff Management Routes
      GoRoute(
        path: '/staff',
        name: 'staff',
        builder: (context, state) => const StaffListScreen(),
      ),
      // Reports Routes
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
    ],
  );
});
