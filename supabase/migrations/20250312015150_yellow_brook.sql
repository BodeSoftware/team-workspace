/*
  # Fix workspace member policies

  1. Changes
    - Remove recursive policies from workspace_members table
    - Simplify policies to prevent infinite recursion
    - Add clear, non-recursive policies for workspace access

  2. Security
    - Maintain RLS protection
    - Ensure users can only access their own workspaces
    - Workspace owners can manage all members
    - Members can view workspace info they belong to
*/

-- Drop existing policies
DROP POLICY IF EXISTS "workspace_member_modify_as_owner" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_select_as_owner" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_select_own" ON workspace_members;

-- Create new, simplified policies
CREATE POLICY "workspace_members_select_policy"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR 
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_members_insert_policy"
ON workspace_members
FOR INSERT
TO authenticated
WITH CHECK (
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_members_update_policy"
ON workspace_members
FOR UPDATE
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
)
WITH CHECK (
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_members_delete_policy"
ON workspace_members
FOR DELETE
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);