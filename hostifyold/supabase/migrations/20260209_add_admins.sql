-- Migration to add admin users
-- Email: finance@hostifystays.com, Password: FinanceHostify
-- Email: hello@hostifystays.com, Password: HelloHello
-- Email: book@hostifystays.com, Password: AdminAdmin

DO $$
DECLARE
    v_finance_id UUID := gen_random_uuid();
    v_hello_id UUID := gen_random_uuid();
    v_book_id UUID := gen_random_uuid();
BEGIN
    -- 1. Create finance@hostifystays.com
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'finance@hostifystays.com') THEN
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, role, raw_user_meta_data, aud, confirmation_token)
        VALUES (
            v_finance_id, 
            'finance@hostifystays.com', 
            crypt('FinanceHostify', gen_salt('bf')), 
            now(), 
            'authenticated', 
            '{"full_name": "Finance Admin"}'::jsonb,
            'authenticated',
            encode(gen_random_bytes(32), 'hex')
        );
        
        -- Role assignment (user_profiles is handled by trigger on_auth_user_created)
        INSERT INTO public.user_roles (user_id, role, is_active)
        VALUES (v_finance_id, 'admin', true);
    END IF;

    -- 2. Create hello@hostifystays.com
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'hello@hostifystays.com') THEN
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, role, raw_user_meta_data, aud, confirmation_token)
        VALUES (
            v_hello_id, 
            'hello@hostifystays.com', 
            crypt('HelloHello', gen_salt('bf')), 
            now(), 
            'authenticated', 
            '{"full_name": "Hello Admin"}'::jsonb,
            'authenticated',
            encode(gen_random_bytes(32), 'hex')
        );
        
        INSERT INTO public.user_roles (user_id, role, is_active)
        VALUES (v_hello_id, 'admin', true);
    END IF;

    -- 3. Create book@hostifystays.com
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'book@hostifystays.com') THEN
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, role, raw_user_meta_data, aud, confirmation_token)
        VALUES (
            v_book_id, 
            'book@hostifystays.com', 
            crypt('AdminAdmin', gen_salt('bf')), 
            now(), 
            'authenticated', 
            '{"full_name": "Booking Admin"}'::jsonb,
            'authenticated',
            encode(gen_random_bytes(32), 'hex')
        );
        
        INSERT INTO public.user_roles (user_id, role, is_active)
        VALUES (v_book_id, 'admin', true);
    END IF;

END $$;
