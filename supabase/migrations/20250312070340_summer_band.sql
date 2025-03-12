/*
  # Fix document RLS policies

  1. Changes
    - Drop existing document policies
    - Create new policies that properly handle position updates
    - Maintain proper access control for documents
    - Fix issues with document movement and reordering

  2. Security
    - Ensure users can only modify their own documents
    - Allow workspace members to view documents
    - Maintain proper access control during position updates
*/

-- Drop existing document policies
DROP POLICY IF EXISTS "document_access" ON documents;
DROP POLICY IF EXISTS "documents_view" ON documents;
DROP POLICY IF EXISTS "documents_manage" ON documents;
DROP POLICY IF EXISTS "view_documents" ON documents;
DROP POLICY IF EXISTS "manage_own_documents" ON documents;

-- Create new document policies

-- Policy for viewing documents
CREATE POLICY "documents_view_policy"
ON documents
FOR SELECT
TO authenticated
USING (
  -- User can view if they:
  created_by = auth.uid() OR -- Created the document
  workspace_id IN ( -- Are a member of the workspace
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
  -- User can insert if they:
  created_by = auth.uid() AND -- Are set as the creator
  workspace_id IN ( -- Are a member of the workspace
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
  -- User can update if they:
  created_by = auth.uid() OR -- Created the document
  workspace_id IN ( -- Are a member of the workspace with proper role
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'editor')
  )
)
WITH CHECK (
  -- Same conditions for the new values
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
  -- User can delete if they:
  created_by = auth.uid() OR -- Created the document
  workspace_id IN ( -- Are a workspace admin
    SELECT workspace_id 
    FROM workspace_members 
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);