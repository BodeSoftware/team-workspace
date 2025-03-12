/*
  # Disable email confirmation requirement

  This migration:
  1. Marks all existing users as confirmed
  2. Ensures new users are automatically confirmed
*/

-- Mark all existing users as confirmed
UPDATE auth.users 
SET email_confirmed_at = CURRENT_TIMESTAMP 
WHERE email_confirmed_at IS NULL;

-- Create a trigger to automatically confirm new users
CREATE OR REPLACE FUNCTION public.auto_confirm_email()
RETURNS TRIGGER AS $$
BEGIN
  NEW.email_confirmed_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS confirm_user_email ON auth.users;
CREATE TRIGGER confirm_user_email
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_email();