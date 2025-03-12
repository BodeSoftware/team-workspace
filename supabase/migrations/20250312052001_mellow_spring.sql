/*
  # Fix documents position column

  1. Changes
    - Add position column to documents table if it doesn't exist
    - Set default position values for existing documents
    - Add index for better query performance

  2. Notes
    - Uses safe migration pattern to check for column existence
    - Maintains existing document order
    - Improves query performance with index
*/

-- Add position column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'documents' AND column_name = 'position'
  ) THEN
    -- Add position column
    ALTER TABLE documents ADD COLUMN position integer DEFAULT 0;

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
  END IF;
END $$;