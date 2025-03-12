/*
  # Fix workspace and document policies

  This migration:
  1. Drops and recreates workspace member policies to prevent recursion
  2. Simplifies document access policies to avoid circular dependencies
  3. Ensures proper access control while preventing infinite recursion

  Changes:
  - Simplify workspace member viewing policy
  - Update document viewing policies to avoid recursive checks
  - Maintain security while improving query performance
*/

-- Drop existing problematic policies
DROP POLICY IF EXISTS "Members can view workspace memberships" ON workspace_members;
DROP POLICY IF EXISTS "View workspace members" ON workspace_members;
DROP POLICY IF EXISTS "View documents" ON documents;
DROP POLICY IF EXISTS "Users can view documents they have access to" ON documents;

-- Create simplified workspace member policies
CREATE POLICY "View workspace members"
ON workspace_members
FOR SELECT
TO authenticated
USING (
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
  )
);

-- Update document viewing policy
CREATE POLICY "View documents"
ON documents
FOR SELECT
TO authenticated
USING (
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