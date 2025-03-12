/*
  # Fix document position trigger

  1. Changes
    - Replace AFTER trigger with BEFORE trigger to prevent recursion
    - Simplify position management logic
    - Fix position calculation for drag and drop operations

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
    
    -- Set the new position directly
    NEW.position := max_position + position_increment;
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- If nothing relevant changed, return as is
    IF OLD.parent_id IS NOT DISTINCT FROM NEW.parent_id 
       AND OLD.position = NEW.position THEN
      RETURN NEW;
    END IF;

    -- If parent changed, move to end of new parent
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      SELECT COALESCE(MAX(position), 0) INTO max_position
      FROM documents
      WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id;
      
      NEW.position := max_position + position_increment;
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