/*
  # Add position column to documents table

  1. Changes
    - Add position column to documents table for ordering
    - Set initial position values based on creation date
    - Add index for better query performance

  2. Notes
    - Position column allows explicit ordering of documents
    - Default value ensures new documents are added at the end
    - Index improves performance of ORDER BY queries
*/

-- Add position column
ALTER TABLE documents 
ADD COLUMN position integer DEFAULT 0;

-- Update existing documents with position based on creation order
WITH numbered_docs AS (
  SELECT 
    id,
    ROW_NUMBER() OVER (
      PARTITION BY COALESCE(parent_id, '00000000-0000-0000-0000-000000000000')
      ORDER BY created_at ASC
    ) * 100 as new_position
  FROM documents
)
UPDATE documents d
SET position = nd.new_position
FROM numbered_docs nd
WHERE d.id = nd.id;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_documents_parent_position 
ON documents(parent_id, position);