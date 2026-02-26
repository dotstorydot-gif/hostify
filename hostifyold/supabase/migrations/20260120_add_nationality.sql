-- Add nationality field to user_profiles
ALTER TABLE user_profiles 
ADD COLUMN nationality TEXT;

-- Add index for faster nationality-based queries
CREATE INDEX idx_user_profiles_nationality ON user_profiles(nationality);

-- Update existing users with default value (optional)
-- UPDATE user_profiles SET nationality = 'Not Specified' WHERE nationality IS NULL;
