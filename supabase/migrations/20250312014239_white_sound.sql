/*
  # Create default workspace trigger

  1. Changes
    - Add trigger to automatically create a default workspace for new users
    - Add trigger to automatically add the user as a workspace member

  2. Security
    - Maintains existing RLS policies
    - Only creates workspace for authenticated users
*/

-- Function to create default workspace
CREATE OR REPLACE FUNCTION public.create_default_workspace()
RETURNS TRIGGER AS $$
DECLARE
  new_workspace_id uuid;
BEGIN
  -- Create default workspace
  INSERT INTO public.workspaces (name, description, owner_id)
  VALUES ('My Workspace', 'My personal workspace', NEW.id)
  RETURNING id INTO new_workspace_id;

  -- Add user as workspace member with admin role
  INSERT INTO public.workspace_members (workspace_id, user_id, role)
  VALUES (new_workspace_id, NEW.id, 'admin');

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_default_workspace();