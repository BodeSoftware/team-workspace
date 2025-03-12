/*
  # Disable email confirmation requirement

  This migration marks existing users as confirmed, allowing them to sign in
  without email verification.

  1. Changes
    - Updates auth.users table to mark all existing users as email confirmed
*/

-- Mark all existing users as confirmed
UPDATE auth.users 
SET email_confirmed_at = CURRENT_TIMESTAMP 
WHERE email_confirmed_at IS NULL;