/*
  # Fix document hierarchy and position management

  1. Changes
    - Improve position management for documents and folders
    - Fix folder hierarchy issues
    - Ensure proper ordering when moving items
    - Add position reordering on parent changes

  2. Security
    - Maintain existing RLS policies
    - Keep data integrity during moves
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
  max_position integer;
  gap integer := 1000;
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position for the parent_id
    SELECT COALESCE(MAX(position), 0) INTO max_position
    FROM documents
    WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
       OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id);
    
    -- Set position to be after the last item
    NEW.position := max_position + gap;
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- If parent hasn't changed and position hasn't changed, do nothing
    IF (OLD.parent_id IS NOT DISTINCT FROM NEW.parent_id AND OLD.position = NEW.position) THEN
      RETURN NEW;
    END IF;

    -- If moving to a new parent
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      -- Get the maximum position in the new parent
      SELECT COALESCE(MAX(position), 0) INTO max_position
      FROM documents
      WHERE (NEW.parent_id IS NULL AND parent_id IS NULL)
         OR (NEW.parent_id IS NOT NULL AND parent_id = NEW.parent_id);
      
      -- If no specific position provided, place at the end
      IF NEW.position IS NULL OR NEW.position > max_position THEN
        NEW.position := max_position + gap;
      ELSE
        -- Shift existing items to make room for the new position
        UPDATE documents
        SET position = position + gap
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
          AND position >= NEW.position;
      END IF;
    END IF;

    -- Reorder items in the old parent after moving
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      WITH reordered AS (
        SELECT 
          id,
          ROW_NUMBER() OVER (ORDER BY position) * gap as new_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM OLD.parent_id
      )
      UPDATE documents d
      SET position = r.new_position
      FROM reordered r
      WHERE d.id = r.id;
    END IF;

    RETURN NEW;
  END IF;

  -- For deletions (DELETE)
  IF TG_OP = 'DELETE' THEN
    -- Reorder remaining items in the same parent
    WITH reordered AS (
      SELECT 
        id,
        ROW_NUMBER() OVER (ORDER BY position) * gap as new_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM OLD.parent_id
        AND id != OLD.id
    )
    UPDATE documents d
    SET position = r.new_position
    FROM reordered r
    WHERE d.id = r.id;
    
    RETURN OLD;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create new trigger
CREATE TRIGGER documents_position_trigger
  BEFORE INSERT OR UPDATE OR DELETE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION manage_document_position();

-- Reorder all existing documents to ensure consistent positions
WITH reordered AS (
  SELECT 
    id,
    parent_id,
    ROW_NUMBER() OVER (
      PARTITION BY COALESCE(parent_id::text, 'root')
      ORDER BY position, created_at
    ) * 1000 as new_position
  FROM documents
)
UPDATE documents d
SET position = r.new_position
FROM reordered r
WHERE d.id = r.id;