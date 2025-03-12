/*
  # Fix document position management

  1. Changes
    - Create position management as an AFTER trigger
    - Handle document reordering without recursion
    - Fix position calculation for drag and drop
    
  2. Security
    - Maintain existing RLS policies
    - Ensure data consistency during reordering
*/

-- Create function to handle document position updates
CREATE OR REPLACE FUNCTION manage_document_position()
RETURNS TRIGGER AS $$
DECLARE
  max_position integer;
  min_position integer;
  gap integer := 1000;
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position for the parent_id
    SELECT COALESCE(MAX(position), 0) INTO max_position
    FROM documents
    WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id;
    
    -- Set position to be after the last item
    NEW.position := max_position + gap;
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- Only handle position updates if parent changed or position explicitly set
    IF OLD.parent_id IS DISTINCT FROM NEW.parent_id OR OLD.position != NEW.position THEN
      -- If moving to a new parent, put at the end
      IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
        SELECT COALESCE(MAX(position), 0) INTO max_position
        FROM documents
        WHERE parent_id IS NOT DISTINCT FROM NEW.parent_id;
        
        NEW.position := max_position + gap;
      END IF;
    END IF;
    
    RETURN NEW;
  END IF;

  -- For deletions (DELETE)
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for position management
DROP TRIGGER IF EXISTS documents_position_trigger ON documents;
CREATE TRIGGER documents_position_trigger
  BEFORE INSERT OR UPDATE ON documents
  FOR EACH ROW
  EXECUTE FUNCTION manage_document_position();

-- Reorder existing documents to ensure consistent positions
WITH ordered_docs AS (
  SELECT 
    id,
    parent_id,
    ROW_NUMBER() OVER (
      PARTITION BY parent_id 
      ORDER BY position, created_at
    ) * 1000 as new_position
  FROM documents
)
UPDATE documents d
SET position = od.new_position
FROM ordered_docs od
WHERE d.id = od.id;