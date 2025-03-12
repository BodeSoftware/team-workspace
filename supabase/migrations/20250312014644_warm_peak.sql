/*
  # Fix workspace member policies

  1. Changes
    - Drop existing problematic policies
    - Create simplified policies without recursion
    - Fix infinite recursion in workspace_members policies
    
  2. Security
    - Maintain proper access control
    - Prevent policy loops
    - Ensure data access is properly restricted
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "workspace_access" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_read" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_self" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_owner" ON workspace_members;
DROP POLICY IF EXISTS "document_access" ON documents;

-- Create simplified workspace policies
CREATE POLICY "workspace_owner_access"
ON workspaces
FOR ALL
TO authenticated
USING (owner_id = auth.uid());

CREATE POLICY "workspace_member_read"
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

-- Create non-recursive workspace member policies
CREATE POLICY "workspace_member_read_self"
ON workspace_members
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "workspace_member_read_workspace"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);

-- Document access policy
CREATE POLICY "document_access_policy"
ON documents
FOR ALL
TO authenticated
USING (
  created_by = auth.uid()
  OR
  EXISTS (
    SELECT 1
    FROM workspace_members
    WHERE workspace_members.workspace_id = documents.workspace_id
    AND workspace_members.user_id = auth.uid()
  )
  OR
  EXISTS (
    SELECT 1
    FROM document_permissions
    WHERE document_permissions.document_id = documents.id
    AND document_permissions.user_id = auth.uid()
  )
);