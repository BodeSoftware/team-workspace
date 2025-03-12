/*
  # Fix document position management

  1. Changes
    - Improve position management for upward swapping
    - Fix folder position handling
    - Ensure consistent ordering
    
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
  max_position integer;
  min_position integer;
  target_position integer;
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

    -- If moving to a new parent
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
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
    ELSE
      -- If just reordering within the same parent
      -- Get the target position
      target_position := NEW.position;

      -- Get the minimum and maximum positions for the type
      SELECT 
        COALESCE(MIN(position), CASE WHEN NEW.is_folder THEN folder_position_base ELSE document_position_base END),
        COALESCE(MAX(position), CASE WHEN NEW.is_folder THEN folder_position_base ELSE document_position_base END)
      INTO min_position, max_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND is_folder = NEW.is_folder
      AND id != NEW.id;

      -- Handle moving up (to a lower position)
      IF target_position < OLD.position THEN
        -- Shift items down to make room
        UPDATE documents
        SET position = position + position_increment
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = NEW.is_folder
        AND position >= target_position
        AND position < OLD.position
        AND id != NEW.id;

        NEW.position := target_position;
      END IF;

      -- Handle moving down (to a higher position)
      IF target_position > OLD.position THEN
        -- Shift items up to make room
        UPDATE documents
        SET position = position - position_increment
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
        AND is_folder = NEW.is_folder
        AND position <= target_position
        AND position > OLD.position
        AND id != NEW.id;

        NEW.position := target_position;
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