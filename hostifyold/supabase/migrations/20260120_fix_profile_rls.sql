-- ============================================
-- FIX: Allow users to insert their own profile
-- ============================================

-- Explanation:
-- The initial RLS policies allowed SELECT and UPDATE on user_profiles,
-- but missed the INSERT policy. This causes the signup flow to fail
-- when the app tries to create the initial profile record.

CREATE POLICY "Users can insert own profile"
  ON public.user_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Verify the policy was created
-- SELECT * FROM pg_policies WHERE tablename = 'user_profiles';
