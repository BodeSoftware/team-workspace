/*
  # Fix recursive policies with simplified access control

  1. Changes
    - Remove all recursive policy dependencies
    - Implement direct access control without circular references
    - Simplify workspace and document access patterns

  2. Security
    - Maintain proper access control for all resources
    - Prevent policy recursion while keeping security intact
*/

-- Drop all existing policies
DROP POLICY IF EXISTS "workspace_members_view" ON workspace_members;
DROP POLICY IF EXISTS "workspace_members_manage" ON workspace_members;
DROP POLICY IF EXISTS "workspaces_view" ON workspaces;
DROP POLICY IF EXISTS "workspaces_manage" ON workspaces;
DROP POLICY IF EXISTS "documents_view" ON documents;
DROP POLICY IF EXISTS "documents_manage" ON documents;

-- Simple workspace access - no recursion
CREATE POLICY "workspace_access"
ON workspaces
FOR ALL
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- Workspace members policies - direct access
CREATE POLICY "workspace_members_access"
ON workspace_members
FOR ALL
TO authenticated
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);

-- Document access policies - simplified
CREATE POLICY "document_access"
ON documents
FOR ALL
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
  )
)
WITH CHECK (created_by = auth.uid());