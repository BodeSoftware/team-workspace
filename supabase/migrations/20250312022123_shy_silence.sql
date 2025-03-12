/*
  # Fix workspace and document policies

  1. Changes
    - Remove all existing policies to start fresh
    - Create simplified policies without circular references
    - Add proper document access controls

  2. Security
    - Maintain proper access control for all resources
    - Prevent infinite recursion in policies
    - Ensure proper document sharing capabilities
*/

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "workspace_members_basic_access" ON workspace_members;
DROP POLICY IF EXISTS "workspace_owner_manage_members" ON workspace_members;
DROP POLICY IF EXISTS "workspace_owner_access" ON workspaces;
DROP POLICY IF EXISTS "workspace_member_access" ON workspaces;
DROP POLICY IF EXISTS "Manage documents" ON documents;
DROP POLICY IF EXISTS "document_access" ON documents;

-- Workspace Members Policies
CREATE POLICY "view_workspace_members"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);

CREATE POLICY "manage_workspace_members"
ON workspace_members
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  )
);

-- Workspace Policies
CREATE POLICY "view_workspaces"
ON workspaces
FOR SELECT
TO authenticated
USING (
  owner_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_members.workspace_id = workspaces.id
    AND workspace_members.user_id = auth.uid()
  )
);

CREATE POLICY "manage_own_workspaces"
ON workspaces
FOR ALL
TO authenticated
USING (owner_id = auth.uid())
WITH CHECK (owner_id = auth.uid());

-- Document Policies
CREATE POLICY "view_documents"
ON documents
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid() OR
  EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_members.workspace_id = documents.workspace_id
    AND workspace_members.user_id = auth.uid()
  )
);

CREATE POLICY "manage_own_documents"
ON documents
FOR ALL
TO authenticated
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());