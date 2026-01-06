-- =====================================================
-- Supabase RPC Function: delete_order_items
-- =====================================================
-- This function bypasses RLS policies to delete order items.
-- Run this SQL in your Supabase SQL Editor (Dashboard > SQL Editor)
-- =====================================================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS delete_order_items(uuid, uuid[]);

-- Create the function with SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION delete_order_items(
  p_order_id uuid,
  p_item_ids uuid[]
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- This bypasses RLS
SET search_path = public
AS $$
DECLARE
  deleted_count integer;
  result json;
BEGIN
  -- Delete items that match both order_id and are in the item_ids array
  DELETE FROM order_items
  WHERE order_id = p_order_id
    AND id = ANY(p_item_ids);
  
  -- Get count of deleted rows
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  
  -- Return result as JSON
  result := json_build_object(
    'success', true,
    'deleted_count', deleted_count,
    'order_id', p_order_id,
    'item_ids', p_item_ids
  );
  
  RETURN result;
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object(
      'success', false,
      'error', SQLERRM,
      'order_id', p_order_id,
      'item_ids', p_item_ids
    );
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_order_items(uuid, uuid[]) TO authenticated;

-- Optional: Grant to anon if needed
-- GRANT EXECUTE ON FUNCTION delete_order_items(uuid, uuid[]) TO anon;

-- =====================================================
-- TEST: Run this to verify the function works
-- =====================================================
-- SELECT delete_order_items(
--   '39a85361-5c3f-429e-b538-4d9e3573dd12'::uuid,
--   ARRAY['bcc77325-6410-4917-99e8-56197fdfdfea']::uuid[]
-- );
