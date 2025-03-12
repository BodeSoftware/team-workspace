/*
  # Fix folder structure in documents table

  1. Changes
    - Drop existing is_folder column to avoid conflicts
    - Add is_folder column with proper constraints
    - Add index for performance optimization
    - Update document policies

  2. Security
    - Maintain existing RLS policies
    - Ensure proper access control for folders
*/

-- First drop the existing column and index if they exist
DROP INDEX IF EXISTS idx_documents_is_folder;
ALTER TABLE documents DROP COLUMN IF EXISTS is_folder;

-- Add is_folder column with proper constraint
ALTER TABLE documents 
ADD COLUMN is_folder BOOLEAN NOT NULL DEFAULT false;

-- Create index for better query performance
CREATE INDEX idx_documents_is_folder ON documents(is_folder);

-- Update document policies
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