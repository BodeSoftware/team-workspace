/*
  # Add document templates support

  1. New Tables
    - `document_templates`
      - `id` (uuid, primary key)
      - `title` (text)
      - `description` (text)
      - `content` (jsonb)
      - `created_by` (uuid, references users)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `document_templates` table
    - Add policies for:
      - Authenticated users can read all templates
      - Only admins can create/update templates
*/

CREATE TABLE IF NOT EXISTS document_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text,
  content jsonb,
  created_by uuid REFERENCES users(id) NOT NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE document_templates ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read templates
CREATE POLICY "Users can read templates"
  ON document_templates
  FOR SELECT
  TO authenticated
  USING (true);

-- Only admins can create templates
CREATE POLICY "Admins can create templates"
  ON document_templates
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- Only admins can update templates
CREATE POLICY "Admins can update templates"
  ON document_templates
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );