/*
  # Create workspaces for users

  1. Changes
    - Creates workspaces for all users who don't have one
    - Adds users as workspace members with admin role
    
  2. Security
    - Maintains proper access control
    - Uses secure default roles
*/

DO $$ 
DECLARE
  user_record RECORD;
  new_workspace_id uuid;
BEGIN
  -- Loop through all users in public.users who don't have a workspace
  FOR user_record IN 
    SELECT u.id 
    FROM public.users u
    WHERE NOT EXISTS (
      SELECT 1 
      FROM workspaces w 
      WHERE w.owner_id = u.id
    )
  LOOP
    -- Create default workspace
    INSERT INTO workspaces (name, description, owner_id)
    VALUES ('My Workspace', 'My personal workspace', user_record.id)
    RETURNING id INTO new_workspace_id;

    -- Add user as workspace member with admin role
    INSERT INTO workspace_members (workspace_id, user_id, role)
    VALUES (new_workspace_id, user_record.id, 'admin');
  END LOOP;
END $$;