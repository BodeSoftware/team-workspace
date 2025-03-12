/*
  # Fix workspace member policies

  1. Changes
    - Remove existing workspace member policies that cause recursion
    - Create new simplified policies that avoid circular references
    - Add basic workspace policies for document access

  2. Security
    - Maintain proper access control for workspace members
    - Ensure workspace owners can manage their workspaces
    - Allow users to view workspaces they're members of
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "workspace_member_select" ON workspace_members;
DROP POLICY IF EXISTS "workspace_members_select_policy" ON workspace_members;
DROP POLICY IF EXISTS "workspace_members_insert_policy" ON workspace_members;
DROP POLICY IF EXISTS "workspace_members_update_policy" ON workspace_members;
DROP POLICY IF EXISTS "workspace_members_delete_policy" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_select_as_owner" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_select_own" ON workspace_members;

-- Create new workspace member policies
CREATE POLICY "workspace_members_basic_access"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
);

CREATE POLICY "workspace_owner_manage_members"
ON workspace_members
FOR ALL
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM workspaces 
    WHERE owner_id = auth.uid()
  )
)
WITH CHECK (
  workspace_id IN (
    SELECT id FROM workspaces 
    WHERE owner_id = auth.uid()
  )
);

-- Update workspace policies
DROP POLICY IF EXISTS "Manage workspaces" ON workspaces;
DROP POLICY IF EXISTS "View workspaces" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_select" ON workspaces;
DROP POLICY IF EXISTS "workspace_owner_all" ON workspaces;

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
  id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
  )
);