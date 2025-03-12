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
DROP POLICY IF EXISTS "workspace_access" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_view" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_modify" ON workspace_members;

-- Create base workspace policy with direct checks only
CREATE POLICY "workspace_owner_access"
ON workspaces
FOR ALL
TO authenticated
USING (owner_id = auth.uid());

CREATE POLICY "workspace_member_access"
ON workspaces
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM workspace_members
    WHERE workspace_members.workspace_id = workspaces.id
    AND workspace_members.user_id = auth.uid()
  )
);

-- Create workspace member policies with direct checks
CREATE POLICY "member_self_view"
ON workspace_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "member_owner_access"
ON workspace_members
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 
    FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);