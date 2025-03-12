/*
  # Fix document RLS policies for position updates

  1. Changes
    - Drop existing document policies
    - Create new policies that properly handle position updates
    - Fix issues with document movement and reordering

  2. Security
    - Ensure users can only modify documents in their workspaces
    - Allow workspace members with proper roles to update positions
*/

-- Drop existing document policies
DROP POLICY IF EXISTS "documents_view_policy" ON documents;
DROP POLICY IF EXISTS "documents_insert_policy" ON documents;
DROP POLICY IF EXISTS "documents_update_policy" ON documents;
DROP POLICY IF EXISTS "documents_delete_policy" ON documents;

-- Create new document policies

-- Policy for viewing documents
CREATE POLICY "documents_view_policy"
ON documents
FOR SELECT
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
  )
);

-- Policy for inserting documents
CREATE POLICY "documents_insert_policy"
ON documents
FOR INSERT
TO authenticated
WITH CHECK (
  created_by = auth.uid() AND
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
  )
);

-- Policy for updating documents
CREATE POLICY "documents_update_policy"
ON documents
FOR UPDATE
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'editor')
  )
);

-- Policy for deleting documents
CREATE POLICY "documents_delete_policy"
ON documents
FOR DELETE
TO authenticated
USING (
  created_by = auth.uid() OR
  workspace_id IN (
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);