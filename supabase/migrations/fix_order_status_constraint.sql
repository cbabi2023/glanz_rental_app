-- Fix Order Status Constraint
-- This migration adds 'completed_with_issues' and 'flagged' to the allowed order statuses
-- 
-- Run this SQL in your Supabase SQL Editor to fix the constraint error

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

-- Verify the constraint was updated
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'orders'::regclass 
AND conname = 'orders_status_check';

