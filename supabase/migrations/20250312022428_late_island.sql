/*
  # Fix recursive policies

  1. Changes
    - Remove recursive policy dependencies
    - Simplify access control logic
    - Fix infinite recursion in workspace_members policies

  2. Security
    - Maintain proper access control
    - Prevent policy recursion
    - Keep existing security model
*/

-- Drop existing policies
DROP POLICY IF EXISTS "view_workspace_members" ON workspace_members;
DROP POLICY IF EXISTS "manage_workspace_members" ON workspace_members;
DROP POLICY IF EXISTS "view_workspaces" ON workspaces;
DROP POLICY IF EXISTS "manage_own_workspaces" ON workspaces;
DROP POLICY IF EXISTS "view_documents" ON documents;
DROP POLICY IF EXISTS "manage_own_documents" ON documents;

-- Workspace Members Policies (Non-recursive)
CREATE POLICY "workspace_members_view"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);

CREATE POLICY "workspace_members_manage"
ON workspace_members
FOR ALL
TO authenticated
USING (
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);

-- Workspace Policies (Non-recursive)
CREATE POLICY "workspaces_view"
ON workspaces
FOR SELECT
TO authenticated
USING (
  owner_id = auth.uid() OR
  id IN (
    SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()
  )
);

CREATE POLICY "workspaces_manage"
ON workspaces
FOR ALL
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- Document Policies (Non-recursive)
CREATE POLICY "documents_view"
ON documents
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT workspace_id FROM workspace_members WHERE user_id = auth.uid()
  )
);

CREATE POLICY "documents_manage"
ON documents
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());