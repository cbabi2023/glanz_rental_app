import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/orders/orders_list_screen.dart';
import '../screens/orders/create_order_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/orders/edit_order_screen.dart';
import '../screens/customers/customers_list_screen.dart';
import '../screens/customers/customer_detail_screen.dart';
import '../screens/customers/create_customer_screen.dart';
import '../screens/customers/edit_customer_screen.dart';
import '../screens/profile_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/main_layout.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App Router Configuration
///
/// Defines all routes and navigation logic for the app
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
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) =>
            MainLayout(currentIndex: 0, child: const DashboardScreen()),
      ),
      GoRoute(
        path: '/orders',
        name: 'orders',
        builder: (context, state) =>
            MainLayout(currentIndex: 1, child: const OrdersListScreen()),
      ),
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
          return OrderDetailScreen(orderId: orderId);
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
        path: '/customers',
        name: 'customers',
        builder: (context, state) =>
            MainLayout(currentIndex: 2, child: const CustomersListScreen()),
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
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) =>
            MainLayout(currentIndex: 3, child: const ProfileScreen()),
      ),
    ],
  );
});
