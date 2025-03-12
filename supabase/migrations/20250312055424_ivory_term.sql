/*
  # Fix document position handling for null parent_id

  1. Changes
    - Drop existing trigger and function
    - Create new position management function with proper null handling
    - Fix parent_id comparison for root-level documents
    - Add proper type handling for UUID comparisons

  2. Security
    - Maintain existing RLS policies
    - Keep data consistency during position updates
*/

-- Drop existing trigger and function
DROP TRIGGER IF EXISTS documents_position_trigger ON documents;
DROP FUNCTION IF EXISTS manage_document_position();

-- Create improved position management function
CREATE OR REPLACE FUNCTION manage_document_position()
RETURNS TRIGGER AS $$
DECLARE
  max_position integer;
  gap integer := 1000;
BEGIN
  -- For new documents (INSERT)
  IF TG_OP = 'INSERT' THEN
    -- Get the maximum position for the parent_id with proper null handling
    SELECT COALESCE(MAX(position), 0) INTO max_position
    FROM documents
    WHERE COALESCE(parent_id::text, '') = COALESCE(NEW.parent_id::text, '');
    
    -- Set position to be after the last item
    NEW.position := max_position + gap;
    RETURN NEW;
  END IF;

  -- For updates (UPDATE)
  IF TG_OP = 'UPDATE' THEN
    -- Only handle position updates if parent changed or position explicitly set
    IF COALESCE(OLD.parent_id::text, '') = COALESCE(NEW.parent_id::text, '') 
       AND OLD.position = NEW.position THEN
      RETURN NEW;
    END IF;

    -- Get the maximum position for the target parent with proper null handling
    SELECT COALESCE(MAX(position), 0) INTO max_position
    FROM documents
    WHERE COALESCE(parent_id::text, '') = COALESCE(NEW.parent_id::text, '');

    -- If no explicit position set or moving to new parent, put at end
    IF NEW.position IS NULL 
       OR COALESCE(OLD.parent_id::text, '') != COALESCE(NEW.parent_id::text, '') THEN
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

-- Reorder existing documents with proper null handling
WITH ordered_docs AS (
  SELECT 
    id,
    parent_id,
    ROW_NUMBER() OVER (
      PARTITION BY COALESCE(parent_id::text, '')
      ORDER BY position, created_at
    ) * 1000 as new_position
  FROM documents
)
UPDATE documents d
SET position = od.new_position
FROM ordered_docs od
WHERE d.id = od.id;