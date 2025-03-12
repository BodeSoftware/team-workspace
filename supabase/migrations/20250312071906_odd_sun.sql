/*
  # Fix document position management

  1. Changes
    - Improve position handling for upward moves
    - Fix folder/document separation
    - Prevent documents from leaving folders during reordering
    
  2. Security
    - Maintain existing RLS policies
    - Keep document access controls
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS documents_position_trigger ON documents;
DROP FUNCTION IF EXISTS manage_document_position();

-- Create improved position management function
CREATE OR REPLACE FUNCTION manage_document_position()
RETURNS TRIGGER AS $$
DECLARE
  base_position integer;
  target_position integer;
  folder_offset integer := 1000000; -- Large offset to separate folders from documents
  gap integer := 1000;
  min_position integer;
  max_position integer;
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

    -- Get the target position
    target_position := NEW.position;

    -- If moving to a new parent
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      -- Calculate new position in target parent
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
    ELSE
      -- Moving within the same parent
      -- Get min and max positions for the type
      SELECT 
        COALESCE(MIN(position), CASE WHEN NEW.is_folder THEN 0 ELSE folder_offset END),
        COALESCE(MAX(position), CASE WHEN NEW.is_folder THEN folder_offset - gap ELSE folder_offset * 2 END)
      INTO min_position, max_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND is_folder = NEW.is_folder
      AND id != NEW.id;

      -- Handle moving up (to a lower position)
      IF target_position < OLD.position THEN
        -- Update positions of items between target and old position
        UPDATE documents
        SET position = position + gap
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = NEW.is_folder
        AND position >= target_position
        AND position < OLD.position
        AND id != NEW.id;

        NEW.position := target_position;
      END IF;

      -- Handle moving down (to a higher position)
      IF target_position > OLD.position THEN
        -- Update positions of items between old and target position
        UPDATE documents
        SET position = position - gap
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = NEW.is_folder
        AND position <= target_position
        AND position > OLD.position
        AND id != NEW.id;

        NEW.position := target_position;
      END IF;

      -- Ensure folders stay before documents
      IF NEW.is_folder AND NEW.position >= folder_offset THEN
        NEW.position := max_position + gap;
      ELSIF NOT NEW.is_folder AND NEW.position < folder_offset THEN
        NEW.position := folder_offset + gap;
      END IF;
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