/*
  # Fix recursive workspace member policies

  This migration fixes the infinite recursion issue by:
  1. Dropping existing problematic policies
  2. Creating new simplified policies with direct checks
  3. Avoiding any nested subqueries that could cause recursion

  Changes:
  - Remove recursive workspace member policies
  - Create new simplified access policies
  - Use direct ownership and membership checks
*/

-- Drop existing policies
DROP POLICY IF EXISTS "workspace_member_access" ON workspace_members;
DROP POLICY IF EXISTS "document_access" ON documents;

-- Create workspace member policies with direct checks
CREATE POLICY "workspace_member_view"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  -- User is a member
  user_id = auth.uid()
  OR
  -- User owns the workspace
  EXISTS (
    SELECT 1 FROM workspaces 
    WHERE id = workspace_members.workspace_id 
    AND owner_id = auth.uid()
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
    WHERE id = workspace_members.workspace_id 
    AND owner_id = auth.uid()
  )
);

-- Create document access policy with direct checks
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
    WHERE workspace_id = documents.workspace_id
    AND user_id = auth.uid()
  )
  OR
  -- Has explicit permission
  EXISTS (
    SELECT 1 FROM document_permissions
    WHERE document_id = documents.id
    AND user_id = auth.uid()
  )
);