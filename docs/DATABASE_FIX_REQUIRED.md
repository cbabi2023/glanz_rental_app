# Database Fix Required for Missing Items Feature

## Problem
When processing order returns with missing items, the backend tries to set the order status to `completed_with_issues`, but the database constraint doesn't allow this status.

**Error:**
```
PostgrestException: new row for relation "orders" violates check constraint "orders_status_check"
Status being set: completed_with_issues
```

## Solution
The database constraint needs to be updated to include `completed_with_issues` and `flagged` statuses.

## Steps to Fix

1. **Open Supabase Dashboard**
   - Go to your Supabase project
   - Navigate to SQL Editor

2. **Run the Migration SQL**
   - Open the file `supabase/migrations/fix_order_status_constraint.sql` in this project
   - Copy and paste the SQL into the Supabase SQL Editor
   - Click "Run" to execute

3. **Verify the Fix**
   - The SQL will output the updated constraint definition
   - Make sure both `completed_with_issues` and `flagged` are in the list

## Alternative: Run SQL Directly

```sql
-- Drop the existing constraint
ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_status_check;

-- Add the new constraint with all required statuses
ALTER TABLE orders ADD CONSTRAINT orders_status_check 
  CHECK (status IN (
    'scheduled',
    'active',
    'pending_return',
    'completed',
    'completed_with_issues',  -- Added for orders with missing/damaged items
    'cancelled',
    'partially_returned',
    'flagged'  -- Added for flagged orders
  ));
```

## After Running the Fix

Once the database constraint is updated:
- The app will automatically work with missing items processing
- Returns with missing items will set the order status correctly
- Damage cost and description will be saved properly

## Current Workaround

Until the database is fixed, the app will:
- ✅ Process returned quantities successfully
- ❌ Skip processing missing items (to avoid the constraint error)
- Missing items will remain as "not yet returned" until the database is fixed

