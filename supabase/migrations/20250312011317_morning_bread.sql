/*
  # Initial Database Setup

  1. Development Setup
    - Creates development user
    - Sets up initial workspace
    - Adds development user as workspace admin

  2. Security
    - Drops existing policies
    - Creates new RLS policies for all tables
    - Implements proper access control
*/

-- Drop all existing policies first
DROP POLICY IF EXISTS "View workspaces" ON workspaces;
DROP POLICY IF EXISTS "Manage workspaces" ON workspaces;
DROP POLICY IF EXISTS "View documents" ON documents;
DROP POLICY IF EXISTS "Manage documents" ON documents;
DROP POLICY IF EXISTS "View workspace members" ON workspace_members;
DROP POLICY IF EXISTS "Manage workspace members" ON workspace_members;
DROP POLICY IF EXISTS "Dev: Allow all document operations" ON documents;
DROP POLICY IF EXISTS "Dev: Allow all workspace operations" ON workspaces;
DROP POLICY IF EXISTS "Dev: Allow all workspace member operations" ON workspace_members;
DROP POLICY IF EXISTS "Users can create documents" ON documents;
DROP POLICY IF EXISTS "Document creators can update their documents" ON documents;
DROP POLICY IF EXISTS "Users can view documents in their workspaces" ON documents;
DROP POLICY IF EXISTS "Workspace members can view workspaces" ON workspaces;
DROP POLICY IF EXISTS "Workspace owners can manage workspaces" ON workspaces;
DROP POLICY IF EXISTS "Workspace owners can manage members" ON workspace_members;
DROP POLICY IF EXISTS "Users can view their workspace memberships" ON workspace_members;

-- Create development user and workspace
DO $$ 
DECLARE
  dev_user_id uuid := '00000000-0000-0000-0000-000000000000';
  new_workspace_id uuid;
BEGIN
  -- Create development user
  INSERT INTO auth.users (id, email)
  VALUES (dev_user_id, 'dev@example.com')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO users (id, role, full_name)
  VALUES (dev_user_id, 'admin', 'Development User')
  ON CONFLICT (id) DO UPDATE
  SET role = 'admin';

  -- Create single workspace
  INSERT INTO workspaces (name, description, owner_id)
  VALUES (
    'Development Workspace',
    'Default workspace for development',
    dev_user_id
  )
  ON CONFLICT (name) DO UPDATE
  SET owner_id = dev_user_id
  RETURNING id INTO new_workspace_id;

  -- Add dev user as workspace member
  INSERT INTO workspace_members (workspace_id, user_id, role)
  VALUES (new_workspace_id, dev_user_id, 'admin')
  ON CONFLICT (workspace_id, user_id) DO UPDATE
  SET role = 'admin';
END $$;

-- Create new policies

-- Workspace policies
CREATE POLICY "View workspaces"
  ON workspaces
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_members.workspace_id = workspaces.id
    AND workspace_members.user_id = auth.uid()
  ));

CREATE POLICY "Manage workspaces"
  ON workspaces
  FOR ALL
  TO authenticated
  USING (owner_id = auth.uid());

-- Document policies
CREATE POLICY "View documents"
  ON documents
  FOR SELECT
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_members.workspace_id = documents.workspace_id
    AND workspace_members.user_id = auth.uid()
  ));

CREATE POLICY "Manage documents"
  ON documents
  FOR ALL
  TO authenticated
  USING (created_by = auth.uid());

-- Workspace member policies
CREATE POLICY "View workspace members"
  ON workspace_members
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "Manage workspace members"
  ON workspace_members
  FOR ALL
  TO authenticated
  USING (EXISTS (
    SELECT 1 FROM workspaces
    WHERE workspaces.id = workspace_members.workspace_id
    AND workspaces.owner_id = auth.uid()
  ));