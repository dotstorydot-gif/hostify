-- Enhanced Authentication Features
-- Google Sign-In, Email Verification, Password Reset, User Roles

-- 1. Add email verification fields to user_profiles
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS email_verification_token TEXT,
ADD COLUMN IF NOT EXISTS email_verification_sent_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS password_reset_token TEXT,
ADD COLUMN IF NOT EXISTS password_reset_sent_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS google_id TEXT UNIQUE;

-- 2. Create index for faster token lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_email_verification 
ON user_profiles(email_verification_token) WHERE email_verification_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_password_reset 
ON user_profiles(password_reset_token) WHERE password_reset_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_user_profiles_google_id 
ON user_profiles(google_id) WHERE google_id IS NOT NULL;

-- 3. Function to generate verification token
CREATE OR REPLACE FUNCTION generate_verification_token()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN encode(gen_random_bytes(32), 'hex');
END;
$$;

-- 4. Function to send email verification
CREATE OR REPLACE FUNCTION send_email_verification(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_token TEXT;
  v_email TEXT;
BEGIN
  -- Generate token
  v_token := generate_verification_token();
  
  -- Get user email
  SELECT email INTO v_email
  FROM auth.users
  WHERE id = p_user_id;
  
  -- Update user profile
  UPDATE user_profiles
  SET 
    email_verification_token = v_token,
    email_verification_sent_at = NOW()
  WHERE user_id = p_user_id;
  
  -- TODO: Send email via Edge Function or external service
  -- For now, return the token (in production, this should be sent via email)
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Verification email sent',
    'token', v_token, -- Remove this in production
    'email', v_email
  );
END;
$$;

-- 5. Function to verify email
CREATE OR REPLACE FUNCTION verify_email(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_sent_at TIMESTAMPTZ;
BEGIN
  -- Find user by token
  SELECT user_id, email_verification_sent_at
  INTO v_user_id, v_sent_at
  FROM user_profiles
  WHERE email_verification_token = p_token;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid verification token'
    );
  END IF;
  
  -- Check if token expired (24 hours)
  IF v_sent_at < NOW() - INTERVAL '24 hours' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Verification token expired'
    );
  END IF;
  
  -- Mark email as verified
  UPDATE user_profiles
  SET 
    email_verified = TRUE,
    email_verification_token = NULL,
    email_verification_sent_at = NULL
  WHERE user_id = v_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Email verified successfully'
  );
END;
$$;

-- 6. Function to request password reset
CREATE OR REPLACE FUNCTION request_password_reset(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_token TEXT;
BEGIN
  -- Find user by email
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = p_email;
  
  IF NOT FOUND THEN
    -- Don't reveal if email exists or not (security)
    RETURN jsonb_build_object(
      'success', true,
      'message', 'If the email exists, a reset link has been sent'
    );
  END IF;
  
  -- Generate reset token
  v_token := generate_verification_token();
  
  -- Update user profile
  UPDATE user_profiles
  SET 
    password_reset_token = v_token,
    password_reset_sent_at = NOW()
  WHERE user_id = v_user_id;
  
  -- TODO: Send email via Edge Function
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'If the email exists, a reset link has been sent',
    'token', v_token -- Remove in production
  );
END;
$$;

-- 7. Function to reset password
CREATE OR REPLACE FUNCTION reset_password(p_token TEXT, p_new_password TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_sent_at TIMESTAMPTZ;
BEGIN
  -- Find user by token
  SELECT user_id, password_reset_sent_at
  INTO v_user_id, v_sent_at
  FROM user_profiles
  WHERE password_reset_token = p_token;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Invalid reset token'
    );
  END IF;
  
  -- Check if token expired (1 hour)
  IF v_sent_at < NOW() - INTERVAL '1 hour' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Reset token expired'
    );
  END IF;
  
  -- Update password (Supabase handles hashing)
  UPDATE auth.users
  SET encrypted_password = crypt(p_new_password, gen_salt('bf'))
  WHERE id = v_user_id;
  
  -- Clear reset token
  UPDATE user_profiles
  SET 
    password_reset_token = NULL,
    password_reset_sent_at = NULL
  WHERE user_id = v_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Password reset successfully'
  );
END;
$$;

-- 8. Function to link Google account
CREATE OR REPLACE FUNCTION link_google_account(p_user_id UUID, p_google_id TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Check if Google ID already linked to another account
  IF EXISTS (SELECT 1 FROM user_profiles WHERE google_id = p_google_id AND user_id != p_user_id) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'This Google account is already linked to another user'
    );
  END IF;
  
  -- Link Google account
  UPDATE user_profiles
  SET google_id = p_google_id
  WHERE user_id = p_user_id;
  
  RETURN jsonb_build_object(
    'success', true,
    'message', 'Google account linked successfully'
  );
END;
$$;

-- 9. Grant execute permissions
GRANT EXECUTE ON FUNCTION send_email_verification(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION verify_email(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION request_password_reset(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION reset_password(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION link_google_account(UUID, TEXT) TO authenticated;

-- 10. Comments
COMMENT ON FUNCTION send_email_verification(UUID) IS 'Send email verification link to user';
COMMENT ON FUNCTION verify_email(TEXT) IS 'Verify user email with token';
COMMENT ON FUNCTION request_password_reset(TEXT) IS 'Request password reset link';
COMMENT ON FUNCTION reset_password(TEXT, TEXT) IS 'Reset password with token';
COMMENT ON FUNCTION link_google_account(UUID, TEXT) IS 'Link Google account to user profile';
