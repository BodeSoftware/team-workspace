/*
  # Fix recursive policies

  This migration fixes the infinite recursion issue by:
  1. Dropping all existing problematic policies
  2. Creating new simplified policies that avoid recursion
  3. Using direct user ID checks instead of nested queries

  Changes:
  - Remove all workspace member policies
  - Create new non-recursive policies
  - Simplify document access checks
*/

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Members can view workspace memberships" ON workspace_members;
DROP POLICY IF EXISTS "View workspace members" ON workspace_members;
DROP POLICY IF EXISTS "Manage workspace members" ON workspace_members;
DROP POLICY IF EXISTS "View documents" ON documents;

-- Create base workspace member policy
CREATE POLICY "workspace_member_access"
ON workspace_members
FOR ALL
TO authenticated
USING (
  -- Direct user check for their own membership
  user_id = auth.uid()
  OR 
  -- Owner check without recursion
  workspace_id IN (
    SELECT id FROM workspaces WHERE owner_id = auth.uid()
  )
);

-- Create document access policy
CREATE POLICY "document_access"
ON documents
FOR ALL
TO authenticated
USING (
  -- Created by user
  created_by = auth.uid()
  OR
  -- Direct workspace membership
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
  )
  OR
  -- Direct document permission
  id IN (
    SELECT document_id 
    FROM document_permissions 
    WHERE user_id = auth.uid()
  )
);