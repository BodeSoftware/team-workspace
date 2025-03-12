/*
  # Fix document position stack overflow

  1. Changes
    - Simplify position management to prevent recursion
    - Use direct position updates without cascading changes
    - Maintain folder/document separation with fixed offsets
    
  2. Security
    - Maintain existing RLS policies
    - Keep document access controls
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS documents_position_trigger ON documents;
DROP FUNCTION IF EXISTS manage_document_position();

-- Create simplified position management function
CREATE OR REPLACE FUNCTION manage_document_position()
RETURNS TRIGGER AS $$
DECLARE
  base_position integer;
  folder_offset integer := 1000000; -- Large offset to separate folders from documents
  gap integer := 1000;
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Calculate position based on document type
    IF NEW.is_folder THEN
      SELECT COALESCE(MAX(position), 0) INTO base_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND is_folder = true;
      
      NEW.position := base_position + gap;
    ELSE
      SELECT COALESCE(MAX(position), folder_offset) INTO base_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND is_folder = false;
      
      NEW.position := base_position + gap;
    END IF;
    
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- If nothing changed, return as is
    IF OLD.parent_id IS NOT DISTINCT FROM NEW.parent_id 
       AND OLD.position = NEW.position
       AND OLD.is_folder = NEW.is_folder THEN
      RETURN NEW;
    END IF;

    -- If moving to a new parent or changing type
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id 
       OR OLD.is_folder != NEW.is_folder THEN
      -- Calculate new position
      IF NEW.is_folder THEN
        SELECT COALESCE(MAX(position), 0) INTO base_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = true;
        
        NEW.position := base_position + gap;
      ELSE
        SELECT COALESCE(MAX(position), folder_offset) INTO base_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = false;
        
        NEW.position := base_position + gap;
      END IF;
    END IF;

    -- Ensure position respects folder/document separation
    IF NEW.is_folder AND NEW.position >= folder_offset THEN
      NEW.position := NEW.position - folder_offset;
    ELSIF NOT NEW.is_folder AND NEW.position < folder_offset THEN
      NEW.position := NEW.position + folder_offset;
    END IF;

    RETURN NEW;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create new trigger
CREATE TRIGGER documents_position_trigger
  BEFORE INSERT OR UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION manage_document_position();

-- Reorder existing documents
WITH ordered_docs AS (
  SELECT 
    id,
    parent_id,
    is_folder,
    ROW_NUMBER() OVER (
      PARTITION BY parent_id, is_folder
      ORDER BY position, created_at
    ) * 1000 as new_position
  FROM documents
)
UPDATE documents d
SET position = CASE 
  WHEN od.is_folder THEN od.new_position
  ELSE od.new_position + 1000000
END
FROM ordered_docs od
WHERE d.id = od.id;