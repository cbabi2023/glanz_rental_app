-- Migration: Add security_deposit column to orders table
-- Date: 2025-01-XX
-- Description: Adds security_deposit column to store security deposit amount for orders

-- Add security_deposit column to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS security_deposit NUMERIC(10, 2) DEFAULT NULL;

-- Add comment to column for documentation
COMMENT ON COLUMN orders.security_deposit IS 'Security deposit amount collected at the time of order creation. This is separate from the rental total and is refundable upon return of items in good condition.';


