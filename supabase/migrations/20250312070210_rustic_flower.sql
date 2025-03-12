/*
  # Fix document position handling

  1. Changes
    - Improve position management for documents
    - Fix null parent_id handling
    - Ensure proper ordering between folders and documents
    - Add proper position increment handling

  2. Security
    - Maintain existing RLS policies
    - Keep data integrity during position updates
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS documents_position_trigger ON documents;
DROP FUNCTION IF EXISTS manage_document_position();

-- Create improved position management function
CREATE OR REPLACE FUNCTION manage_document_position()
RETURNS TRIGGER AS $$
DECLARE
  max_position integer;
  position_increment integer := 1000;
  folder_position_base integer := 0;
  document_position_base integer := 1000000; -- Large gap to separate folders from documents
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position based on document type
    IF NEW.is_folder THEN
      SELECT COALESCE(MAX(position), folder_position_base) INTO max_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND is_folder = true;
      
      NEW.position := max_position + position_increment;
    ELSE
      SELECT COALESCE(MAX(position), document_position_base) INTO max_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND is_folder = false;
      
      NEW.position := max_position + position_increment;
    END IF;
    
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- If nothing relevant changed, return as is
    IF OLD.parent_id IS NOT DISTINCT FROM NEW.parent_id 
       AND OLD.position = NEW.position
       AND OLD.is_folder = NEW.is_folder THEN
      RETURN NEW;
    END IF;

    -- If parent changed or type changed, recalculate position
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id 
       OR OLD.is_folder != NEW.is_folder THEN
      -- Get max position based on document type
      IF NEW.is_folder THEN
        SELECT COALESCE(MAX(position), folder_position_base) INTO max_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = true;
        
        NEW.position := max_position + position_increment;
      ELSE
        SELECT COALESCE(MAX(position), document_position_base) INTO max_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = false;
        
        NEW.position := max_position + position_increment;
      END IF;
    END IF;

    RETURN NEW;
  END IF;

  -- For deletions (DELETE)
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create new BEFORE trigger
CREATE TRIGGER documents_position_trigger
  BEFORE INSERT OR UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION manage_document_position();

-- Reorder all existing documents
WITH reordered AS (
  SELECT 
    id,
    is_folder,
    ROW_NUMBER() OVER (
      PARTITION BY COALESCE(parent_id::text, 'root'), is_folder
      ORDER BY 
        CASE WHEN is_folder THEN 0 ELSE 1 END,
        position,
        created_at
    ) * 1000 as new_position
  FROM documents
)
UPDATE documents d
SET position = CASE 
  WHEN r.is_folder THEN r.new_position
  ELSE r.new_position + 1000000
END
FROM reordered r
WHERE d.id = r.id;