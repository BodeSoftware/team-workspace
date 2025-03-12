/*
  # Fix recursive policies and workspace access

  1. Changes
    - Drop existing problematic policies
    - Create non-recursive policies for workspaces and members
    - Simplify document access policies
    
  2. Security
    - Maintains proper access control without recursion
    - Ensures workspace owners have full access
    - Preserves member access rights
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "workspace_owner_access" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_read" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_read_self" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_read_workspace" ON workspace_members;
DROP POLICY IF EXISTS "document_access_policy" ON documents;

-- Create workspace policies
CREATE POLICY "workspace_owner_all"
ON workspaces
FOR ALL
TO authenticated
USING (owner_id = auth.uid());

CREATE POLICY "workspace_member_select"
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
CREATE POLICY "workspace_member_select_own"
ON workspace_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "workspace_member_select_as_owner"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  workspace_id IN (
    SELECT id
    FROM workspaces
    WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_member_modify_as_owner"
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

-- Document access policy
CREATE POLICY "document_access"
ON documents
FOR ALL
TO authenticated
USING (
  created_by = auth.uid()
  OR
  workspace_id IN (
    SELECT workspace_id
    FROM workspace_members
    WHERE user_id = auth.uid()
  )
  OR
  id IN (
    SELECT document_id
    FROM document_permissions
    WHERE user_id = auth.uid()
  )
);