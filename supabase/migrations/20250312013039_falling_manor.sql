/*
  # Fix workspace policies

  1. Changes
    - Drop existing problematic policies that cause recursion
    - Create simplified workspace access policies
    - Ensure direct access checks without circular dependencies

  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
    - Keep RLS enabled
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "workspace_view" ON workspaces;
DROP POLICY IF EXISTS "workspace_modify" ON workspaces;

-- Create simplified workspace access policies
CREATE POLICY "workspace_access"
ON workspaces
FOR ALL
TO authenticated
USING (
  -- Direct ownership check
  owner_id = auth.uid()
  OR
  -- Direct membership check without recursion
  EXISTS (
    SELECT 1 
    FROM workspace_members
    WHERE workspace_members.workspace_id = workspaces.id
    AND workspace_members.user_id = auth.uid()
  )
);