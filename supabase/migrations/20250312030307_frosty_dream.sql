/*
  # Add is_folder column to documents table

  1. Changes
    - Add `is_folder` boolean column to documents table
    - Set default value to false
    - Make column non-nullable
    - Add index for performance optimization

  2. Notes
    - This helps distinguish between documents and folders
    - The index improves query performance when filtering by is_folder
    - Uses safe migration pattern to check for column existence
*/

-- Add is_folder column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'documents' AND column_name = 'is_folder'
  ) THEN
    ALTER TABLE documents ADD COLUMN is_folder boolean NOT NULL DEFAULT false;
    CREATE INDEX IF NOT EXISTS idx_documents_is_folder ON documents(is_folder);
  END IF;
END $$;