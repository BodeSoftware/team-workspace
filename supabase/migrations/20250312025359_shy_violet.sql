/*
  # Add folder support to documents table

  1. Changes
    - Add `is_folder` column to documents table to distinguish between documents and folders
    - Update document policies to handle folders
    - Add index on parent_id for better performance

  2. Security
    - Maintain existing RLS policies
    - Folders follow the same security rules as documents
*/

-- Add is_folder column to documents table
ALTER TABLE documents
ADD COLUMN is_folder BOOLEAN DEFAULT false;

-- Add index for parent_id to improve performance of tree queries
CREATE INDEX IF NOT EXISTS documents_parent_id_idx ON documents(parent_id);

-- Update document policies to handle folders
DROP POLICY IF EXISTS "document_access" ON documents;

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