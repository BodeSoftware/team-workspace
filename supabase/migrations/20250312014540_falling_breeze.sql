/*
  # Create user and workspace triggers

  1. Changes
    - Creates trigger to automatically create public.users record when auth.users is created
    - Creates trigger to automatically create workspace and membership for new users
    - Ensures existing users have public.users records and workspaces
  
  2. Security
    - All triggers run with SECURITY DEFINER to ensure proper permissions
    - Proper error handling for edge cases
*/

-- First create trigger for public.users creation
CREATE OR REPLACE FUNCTION public.create_public_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, full_name, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    'viewer'
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Then create workspace creation trigger
CREATE OR REPLACE FUNCTION public.create_default_workspace()
RETURNS TRIGGER AS $$
DECLARE
  new_workspace_id uuid;
BEGIN
  -- Only create workspace if user exists in public.users
  IF EXISTS (SELECT 1 FROM public.users WHERE id = NEW.id) THEN
    -- Create default workspace
    INSERT INTO public.workspaces (name, description, owner_id)
    VALUES ('My Workspace', 'My personal workspace', NEW.id)
    RETURNING id INTO new_workspace_id;

    -- Add user as workspace member with admin role
    INSERT INTO public.workspace_members (workspace_id, user_id, role)
    VALUES (new_workspace_id, NEW.id, 'admin');
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create triggers
DROP TRIGGER IF EXISTS on_auth_user_created_public_user ON auth.users;
CREATE TRIGGER on_auth_user_created_public_user
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_public_user();

DROP TRIGGER IF EXISTS on_auth_user_created_workspace ON auth.users;
CREATE TRIGGER on_auth_user_created_workspace
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.create_default_workspace();

-- Handle existing users
DO $$ 
DECLARE
  auth_user RECORD;
  new_workspace_id uuid;
BEGIN
  -- First ensure all auth users have corresponding public.users records
  FOR auth_user IN 
    SELECT au.id, au.email, au.raw_user_meta_data
    FROM auth.users au
    WHERE NOT EXISTS (
      SELECT 1 
      FROM public.users u 
      WHERE u.id = au.id
    )
  LOOP
    -- Create the user record if it doesn't exist
    INSERT INTO public.users (id, full_name, role)
    VALUES (
      auth_user.id,
      COALESCE(auth_user.raw_user_meta_data->>'full_name', split_part(auth_user.email, '@', 1)),
      'viewer'
    )
    ON CONFLICT (id) DO NOTHING;
    
    -- Create default workspace if user doesn't have one
    IF NOT EXISTS (
      SELECT 1 
      FROM workspaces w 
      WHERE w.owner_id = auth_user.id
    ) THEN
      -- Create default workspace
      INSERT INTO workspaces (name, description, owner_id)
      VALUES ('My Workspace', 'My personal workspace', auth_user.id)
      RETURNING id INTO new_workspace_id;

      -- Add user as workspace member with admin role
      INSERT INTO workspace_members (workspace_id, user_id, role)
      VALUES (new_workspace_id, auth_user.id, 'admin');
    END IF;
  END LOOP;
END $$;