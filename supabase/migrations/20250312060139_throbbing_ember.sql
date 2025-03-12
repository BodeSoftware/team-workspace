/*
  # Fix folder hierarchy ordering

  1. Changes
    - Modify position management to ensure folders appear before documents
    - Update position calculation to maintain proper hierarchy
    - Fix ordering within each parent level

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
  folder_offset integer := 0; -- Folders will have lower positions
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
    
    -- Set position based on type (folders get lower positions)
    IF NEW.is_folder THEN
      NEW.position := base_position + gap;
    ELSE
      -- Documents start after a large gap to ensure they're after folders
      SELECT COALESCE(MAX(position), 0) + 1000000 INTO base_position
      FROM documents
      WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
         OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id)
         AND is_folder = true;
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
    IF NEW.is_folder THEN
      SELECT COALESCE(MAX(position), 0) INTO base_position
      FROM documents
      WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
         OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id)
         AND is_folder = true;
      NEW.position := base_position + gap;
    ELSE
      -- Documents start after all folders
      SELECT COALESCE(MAX(position), 0) + 1000000 INTO base_position
      FROM documents
      WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
         OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id)
         AND is_folder = true;
      
      -- Then get the max position of existing documents
      SELECT COALESCE(MAX(position), base_position) INTO base_position
      FROM documents
      WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
         OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id)
         AND is_folder = false;
      
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
      ORDER BY created_at
    ) * 1000 as item_position
  FROM documents
)
UPDATE documents d
SET position = CASE 
  WHEN od.is_folder THEN od.item_position
  ELSE od.item_position + 1000000
END
FROM ordered_docs od
WHERE d.id = od.id;