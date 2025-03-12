/*
  # Fix workspace members policy recursion

  This migration:
  1. Drops the problematic policy that causes infinite recursion
  2. Creates a new, corrected policy for viewing workspace members
*/

-- Drop the problematic policy
DROP POLICY IF EXISTS "Members can view workspace memberships" ON workspace_members;

-- Create a new, corrected policy
CREATE POLICY "Members can view workspace memberships"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM workspace_members wm
    WHERE 
      wm.workspace_id = workspace_members.workspace_id 
      AND wm.user_id = auth.uid()
  )
);