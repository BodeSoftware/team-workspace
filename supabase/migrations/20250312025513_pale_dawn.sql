/*
  # Add folder support to documents table

  1. Changes
    - Add is_folder column to documents table
    - Add index for better performance
    - Update document policies to handle folders

  2. Security
    - Maintain existing RLS policies
    - Folders follow the same security rules as documents
*/

-- Add is_folder column to documents table
ALTER TABLE documents
ADD COLUMN IF NOT EXISTS is_folder BOOLEAN DEFAULT false;

-- Add index for better performance
CREATE INDEX IF NOT EXISTS idx_documents_is_folder ON documents(is_folder);

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