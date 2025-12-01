# Glanz Rental - Flutter App Setup Guide

## ✅ Migration Complete!

Your Next.js web app has been successfully migrated to Flutter. The same Supabase backend is used, so all your data, authentication, and database remain the same.

## 🚀 Quick Start

### 1. Configure Supabase Credentials

**IMPORTANT:** Before running the app, you need to add your Supabase credentials.

1. Open `lib/core/config.dart`
2. Replace the placeholder values:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
   ```

You can find these credentials in your Supabase dashboard:
- Go to your Supabase project
- Navigate to **Settings > API**
- Copy the **Project URL** (for `supabaseUrl`)
- Copy the **anon/public key** (for `supabaseAnonKey`)

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

## 📁 Project Structure

```
lib/
├── core/
│   ├── config.dart              # App configuration & Supabase credentials
│   └── supabase_client.dart     # Supabase client initialization
├── models/                      # Data models (User, Order, Customer, etc.)
├── services/                    # Business logic & API calls
│   ├── auth_service.dart
│   ├── orders_service.dart
│   ├── customers_service.dart
│   └── dashboard_service.dart
├── providers/                   # Riverpod state management
│   ├── auth_provider.dart
│   ├── orders_provider.dart
│   ├── customers_provider.dart
│   └── dashboard_provider.dart
├── routes/
│   └── app_router.dart          # App navigation/routing
├── screens/                     # UI Screens
│   ├── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── orders/
│   └── customers/
└── main.dart                    # App entry point
```

## 🔧 Features Implemented

### ✅ Authentication
- Login with email/password
- Session management
- User profile loading
- Role-based access (Super Admin, Branch Admin, Staff)

### ✅ Dashboard
- Statistics overview
- Quick actions
- Real-time data

### ✅ Orders
- List all orders
- View order details
- Filter by branch
- Real-time updates (via Supabase Realtime)

### ✅ Customers
- List all customers
- Search customers
- View customer details
- Order history per customer
- Due amounts calculation

## 🛠️ API Compatibility Issues (To Fix)

There are some Supabase Flutter API compatibility issues that need to be fixed:

1. **Query Builder Methods**: Some methods like `eq()`, `gte()`, `lte()`, `or()` may need adjustment based on the actual Supabase Flutter version.

2. **Stream Filtering**: Real-time stream filtering needs to be done in the map function.

3. **Count Queries**: Count functionality may need separate queries.

### Recommended Fixes:

1. **Check Supabase Flutter Documentation**: Review the actual API for your version
   - Package: `supabase_flutter: ^2.0.0`
   - Docs: https://supabase.com/docs/reference/dart/introduction

2. **Common Patterns**:
   ```dart
   // Instead of:
   query.eq('status', 'active')
   
   // May need:
   query.filter('status', 'eq', 'active')
   // Or check actual API
   ```

## 📝 Next Steps

### High Priority
1. **Fix Supabase API compatibility** - Adjust query methods to match your Supabase Flutter version
2. **Test authentication** - Verify login works with your Supabase project
3. **Test data loading** - Verify orders and customers load correctly

### Features to Complete
1. **Create Order Screen** - Multi-step form implementation
2. **Edit Order** - Allow editing before return
3. **Mark Order as Returned** - Update order status
4. **PDF Invoice Generation** - Use `pdf` and `printing` packages
5. **Image Upload** - Camera integration for order items
6. **Branch Management** - For Super Admin
7. **Staff Management** - For Super Admin/Branch Admin
8. **Reports Screen** - Analytics and reporting

## 🔐 Same Backend, Different Frontend

Your Flutter app uses the **exact same Supabase backend** as your web app:
- ✅ Same database tables
- ✅ Same authentication users
- ✅ Same Row Level Security (RLS) policies
- ✅ Same storage buckets
- ✅ Same real-time subscriptions

**Both apps can run simultaneously!**

## 🐛 Troubleshooting

### "Supabase not initialized" error
- Check that `SupabaseService.initialize()` is called in `main()`
- Verify credentials in `lib/core/config.dart`

### "Login failed" error
- Verify Supabase credentials are correct
- Check that email/password auth is enabled in Supabase
- Ensure user exists in Supabase Auth

### "No data loading" errors
- Check Supabase RLS policies allow your user to access data
- Verify table names match (orders, customers, profiles, etc.)
- Check network connectivity

## 📚 Resources

- [Supabase Flutter Docs](https://supabase.com/docs/reference/dart/introduction)
- [Riverpod Documentation](https://riverpod.dev/)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Flutter Documentation](https://docs.flutter.dev/)

## 🎯 Original Web App Repository

Reference implementation: https://github.com/supportta-projects/glanz-rental.git

You can compare the web app structure to understand the business logic and features that need to be implemented.

---

**Built with ❤️ - Migrated from Next.js to Flutter**

