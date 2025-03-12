/*
  # Create users and workspaces for auth users

  1. Changes
    - Creates public.users records for existing auth.users
    - Creates default workspaces for users who don't have one
    - Adds users as workspace members with admin role
  
  2. Notes
    - Ensures users exist in public.users table before creating workspaces
    - Safe to run multiple times
*/

DO $$ 
DECLARE
  auth_user RECORD;
  new_workspace_id uuid;
BEGIN
  -- First ensure all auth users have corresponding public.users records
  FOR auth_user IN 
    SELECT au.id, au.email
    FROM auth.users au
    WHERE NOT EXISTS (
      SELECT 1 
      FROM public.users u 
      WHERE u.id = au.id
    )
  LOOP
    -- Create the user record if it doesn't exist
    INSERT INTO public.users (id, full_name, role)
    VALUES (auth_user.id, split_part(auth_user.email, '@', 1), 'viewer')
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