/*
  # Fix folder hierarchy ordering

  1. Changes
    - Modify position management to prioritize folders over documents
    - Update position calculation to maintain folder/document grouping
    - Ensure folders always appear before documents at the same level

  2. Security
    - Maintain existing RLS policies
    - Keep existing document access controls
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS documents_position_trigger ON documents;
DROP FUNCTION IF EXISTS manage_document_position();

-- Create improved position management function
CREATE OR REPLACE FUNCTION manage_document_position()
RETURNS TRIGGER AS $$
DECLARE
  base_position integer;
  folder_offset integer := 1000000; -- Large offset to separate folders from documents
  gap integer := 1000;
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position for the parent_id, considering item type
    SELECT COALESCE(MAX(position), 0) INTO base_position
    FROM documents
    WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
       OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id)
       AND is_folder = NEW.is_folder;
    
    -- Set position based on type (folders get higher positions)
    IF NEW.is_folder THEN
      NEW.position := folder_offset + base_position + gap;
    ELSE
      NEW.position := base_position + gap;
    END IF;
    
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- If nothing relevant changed, do nothing
    IF (OLD.parent_id IS NOT DISTINCT FROM NEW.parent_id 
        AND OLD.position = NEW.position 
        AND OLD.is_folder = NEW.is_folder) THEN
      RETURN NEW;
    END IF;

    -- Get the maximum position for items of the same type in the new parent
    SELECT COALESCE(MAX(position), 0) INTO base_position
    FROM documents
    WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
       OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id)
       AND is_folder = NEW.is_folder;

    -- Set new position based on type
    IF NEW.is_folder THEN
      NEW.position := folder_offset + base_position + gap;
    ELSE
      NEW.position := base_position + gap;
    END IF;

    RETURN NEW;
  END IF;

  -- For deletions (DELETE)
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create new trigger
CREATE TRIGGER documents_position_trigger
  BEFORE INSERT OR UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION manage_document_position();

-- Reorder existing documents to ensure folders appear before documents
WITH ordered_docs AS (
  SELECT 
    id,
    parent_id,
    is_folder,
    ROW_NUMBER() OVER (
      PARTITION BY 
        CASE WHEN parent_id IS NULL THEN 'root'::text ELSE parent_id::text END,
        is_folder
      ORDER BY position, created_at
    ) * 1000 as item_position
  FROM documents
)
UPDATE documents d
SET position = CASE 
  WHEN od.is_folder THEN 1000000 + od.item_position
  ELSE od.item_position
END
FROM ordered_docs od
WHERE d.id = od.id;