# Glanz Rental App

A Flutter-based rental management application for managing orders, customers, inventory, and branches.

## Quick Start

See [docs/SETUP.md](docs/SETUP.md) for setup instructions.

## Documentation

All documentation is available in the `docs/` folder:

- **[SETUP.md](docs/SETUP.md)** - Setup and installation guide
- **[PUBLISH_GUIDE.md](docs/PUBLISH_GUIDE.md)** - Guide for publishing the app
- **[PUSH_TO_GITHUB.md](docs/PUSH_TO_GITHUB.md)** - Instructions for pushing code to GitHub
- **[APP_ICON_SETUP.md](docs/APP_ICON_SETUP.md)** - App icon configuration guide
- **[IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md)** - Implementation details and plans
- **[FLUTTER_UPDATE_REPORT_2024-12-02.md](docs/FLUTTER_UPDATE_REPORT_2024-12-02.md)** - Flutter update report
- **[DATABASE_FIX_REQUIRED.md](docs/DATABASE_FIX_REQUIRED.md)** - Database migration requirements

## Database Migrations

SQL migration files are located in `supabase/migrations/`:

- `add_security_deposit_column.sql` - Adds security deposit columns to orders table
- `fix_order_status_constraint.sql` - Fixes order status constraint
- `supabase_delete_order_items.sql` - RPC function for deleting order items

## Getting Started

This project uses Flutter. For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/).

## Project Structure

```
lib/
├── core/           # Core utilities (Supabase client, logger, config)
├── models/         # Data models
├── providers/      # Riverpod state providers
├── routes/         # App routing
├── screens/        # UI screens
├── services/       # Business logic services
└── widgets/        # Reusable widgets

docs/               # Documentation files
supabase/
└── migrations/     # SQL migration files
```

