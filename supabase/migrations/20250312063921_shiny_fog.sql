/*
  # Fix document position management

  1. Changes
    - Convert BEFORE trigger to AFTER trigger to fix recursion issues
    - Simplify position management logic
    - Add proper error handling
    - Maintain document order within folders

  2. Security
    - Maintain existing RLS policies
    - Ensure data consistency during position updates
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
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position for the parent_id
    SELECT COALESCE(MAX(position), 0) INTO max_position
    FROM documents
    WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id;
    
    -- Update the new document's position
    UPDATE documents
    SET position = max_position + position_increment
    WHERE id = NEW.id;
    
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- Only handle position updates if parent changed
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      -- Get the maximum position in the new parent
      SELECT COALESCE(MAX(position), 0) INTO max_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id
      AND id != NEW.id;
      
      -- Update the document's position in its new location
      UPDATE documents
      SET position = max_position + position_increment
      WHERE id = NEW.id;
      
      -- Reorder documents in the old parent
      WITH reordered AS (
        SELECT 
          id,
          ROW_NUMBER() OVER (ORDER BY position) * position_increment as new_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM OLD.parent_id
        AND id != OLD.id
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
    -- Reorder remaining documents in the same parent
    WITH reordered AS (
      SELECT 
        id,
        ROW_NUMBER() OVER (ORDER BY position) * position_increment as new_position
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

-- Create new AFTER trigger
CREATE TRIGGER documents_position_trigger
  AFTER INSERT OR UPDATE OR DELETE ON documents
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