/*
  # Fix document RLS policies

  1. Changes
    - Drop existing document policies
    - Create new simplified policies without OLD/NEW references
    - Ensure proper access control for all document operations

  2. Security
    - Maintain proper access control
    - Allow workspace members to perform authorized actions
    - Keep existing permission model
*/

-- Drop existing document policies
DROP POLICY IF EXISTS "documents_view_policy" ON documents;
DROP POLICY IF EXISTS "documents_insert_policy" ON documents;
DROP POLICY IF EXISTS "documents_update_policy" ON documents;
DROP POLICY IF EXISTS "documents_delete_policy" ON documents;

-- Create simplified document policies

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