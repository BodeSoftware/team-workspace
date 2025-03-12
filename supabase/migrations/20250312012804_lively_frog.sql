/*
  # Fix workspace policies

  1. Changes
    - Drop existing problematic policies
    - Create new workspace policies with non-recursive checks
    - Add separate policies for different operations

  2. Security
    - Maintain RLS security while avoiding recursion
    - Ensure proper access control for workspace operations
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "workspace_member_view" ON workspace_members;
DROP POLICY IF EXISTS "workspace_member_modify" ON workspace_members;
DROP POLICY IF EXISTS "document_access" ON documents;

-- Create workspace policies with non-recursive checks
CREATE POLICY "workspace_view"
ON workspaces
FOR SELECT
TO authenticated
USING (
  -- User is the owner
  owner_id = auth.uid()
  OR
  -- User is a member (direct check)
  EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_members.workspace_id = workspaces.id
    AND workspace_members.user_id = auth.uid()
  )
);

CREATE POLICY "workspace_modify"
ON workspaces
FOR ALL
TO authenticated
USING (
  -- Only owners can modify workspaces
  owner_id = auth.uid()
);

-- Re-create workspace member policies
CREATE POLICY "workspace_member_view"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  -- User can view their own memberships
  user_id = auth.uid()
  OR
  -- User is the workspace owner
  EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_member_modify"
ON workspace_members
FOR ALL
TO authenticated
USING (
  -- Only workspace owners can modify members
  EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);

-- Re-create document access policy
CREATE POLICY "document_access"
ON documents
FOR ALL
TO authenticated
USING (
  -- Document creator
  created_by = auth.uid()
  OR
  -- Workspace member (direct check)
  EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_members.workspace_id = documents.workspace_id
    AND workspace_members.user_id = auth.uid()
  )
  OR
  -- Has explicit permission
  EXISTS (
    SELECT 1 FROM document_permissions
    WHERE document_permissions.document_id = documents.id
    AND document_permissions.user_id = auth.uid()
  )
);