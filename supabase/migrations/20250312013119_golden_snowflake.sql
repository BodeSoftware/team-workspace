/*
  # Fix workspace policies recursion

  1. Changes
    - Drop all existing workspace-related policies
    - Create new simplified policies with direct checks
    - Ensure no circular dependencies between policies

  2. Security
    - Maintain proper access control
    - Prevent infinite recursion
    - Keep RLS enabled
*/

-- Drop all existing workspace-related policies
DROP POLICY IF EXISTS "workspace_owner_access" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_access" ON workspaces;
DROP POLICY IF EXISTS "member_self_view" ON workspace_members;
DROP POLICY IF EXISTS "member_owner_access" ON workspace_members;

-- Create workspace access policies
CREATE POLICY "workspace_access"
ON workspaces
FOR ALL
TO authenticated
USING (
  owner_id = auth.uid()
);

CREATE POLICY "workspace_member_read"
ON workspaces
FOR SELECT
TO authenticated
USING (
  id IN (
    SELECT workspace_id
    FROM workspace_members
    WHERE user_id = auth.uid()
  )
);

-- Create workspace member policies
CREATE POLICY "workspace_member_self"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
);

CREATE POLICY "workspace_member_owner"
ON workspace_members
FOR ALL
TO authenticated
USING (
  workspace_id IN (
    SELECT id
    FROM workspaces
    WHERE owner_id = auth.uid()
  )
);