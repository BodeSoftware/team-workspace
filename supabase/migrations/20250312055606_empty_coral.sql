/*
  # Fix document drag and drop functionality

  1. Changes
    - Drop existing trigger and function
    - Create improved position management function with proper null handling
    - Fix parent_id comparison logic
    - Add better position calculation for drag and drop operations

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
  min_position integer;
  gap integer := 1000;
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position for the parent_id with proper null handling
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
      
      -- Place at the end of the new parent
      NEW.position := max_position + gap;
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

-- Reorder existing documents
WITH ordered_docs AS (
  SELECT 
    id,
    parent_id,
    ROW_NUMBER() OVER (
      PARTITION BY CASE 
        WHEN parent_id IS NULL THEN 'root'::text 
        ELSE parent_id::text 
      END
      ORDER BY position, created_at
    ) * 1000 as new_position
  FROM documents
)
UPDATE documents d
SET position = od.new_position
FROM ordered_docs od
WHERE d.id = od.id;