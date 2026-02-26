-- Enable pgcrypto for password hashing if not already enabled
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

DO $$
DECLARE
    v_mohamed_id UUID;
    v_samia_id UUID;
    v_ahmed_id UUID;
    v_amr_id UUID;
    v_asmaa_id UUID;
    v_samy_id UUID;
begin
    -- 1. Create Users (Function to safely create/get user)
    -- We use a consistent password '123456' for ease of testing for them.

    -- Mohamed Ibrahim (Redsea.engineering88@yahoo.com)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'Redsea.engineering88@yahoo.com') THEN
        v_mohamed_id := gen_random_uuid();
        INSERT INTO auth.users (id, email, password, email_confirmed_at, role, raw_user_meta_data)
        VALUES (v_mohamed_id, 'Redsea.engineering88@yahoo.com', crypt('123456', gen_salt('bf')), now(), 'authenticated', '{"full_name": "Mohamed Ibrahim"}'::jsonb);
        
        INSERT INTO public.user_profiles (id, email, first_name, last_name, role, is_profile_completed)
        VALUES (v_mohamed_id, 'Redsea.engineering88@yahoo.com', 'Mohamed', 'Ibrahim', 'landlord', true);
    ELSE
        SELECT id INTO v_mohamed_id FROM auth.users WHERE email = 'Redsea.engineering88@yahoo.com';
    END IF;

    -- Samia Atef (samia.atif@hotmail.com)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'samia.atif@hotmail.com') THEN
        v_samia_id := gen_random_uuid();
        INSERT INTO auth.users (id, email, password, email_confirmed_at, role, raw_user_meta_data)
        VALUES (v_samia_id, 'samia.atif@hotmail.com', crypt('123456', gen_salt('bf')), now(), 'authenticated', '{"full_name": "Samia Atef"}'::jsonb);
        
        INSERT INTO public.user_profiles (id, email, first_name, last_name, role, is_profile_completed)
        VALUES (v_samia_id, 'samia.atif@hotmail.com', 'Samia', 'Atef', 'landlord', true);
    ELSE
        SELECT id INTO v_samia_id FROM auth.users WHERE email = 'samia.atif@hotmail.com';
    END IF;

    -- Ahmed Toofik (atoofik@hotmail.com)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'atoofik@hotmail.com') THEN
        v_ahmed_id := gen_random_uuid();
        INSERT INTO auth.users (id, email, password, email_confirmed_at, role, raw_user_meta_data)
        VALUES (v_ahmed_id, 'atoofik@hotmail.com', crypt('123456', gen_salt('bf')), now(), 'authenticated', '{"full_name": "Ahmed Toofik"}'::jsonb);
        
        INSERT INTO public.user_profiles (id, email, first_name, last_name, role, is_profile_completed)
        VALUES (v_ahmed_id, 'atoofik@hotmail.com', 'Ahmed', 'Toofik', 'landlord', true);
    ELSE
        SELECT id INTO v_ahmed_id FROM auth.users WHERE email = 'atoofik@hotmail.com';
    END IF;

    -- Amr Abou El Enien (amraboulenein@yahoo.com)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'amraboulenein@yahoo.com') THEN
        v_amr_id := gen_random_uuid();
        INSERT INTO auth.users (id, email, password, email_confirmed_at, role, raw_user_meta_data)
        VALUES (v_amr_id, 'amraboulenein@yahoo.com', crypt('123456', gen_salt('bf')), now(), 'authenticated', '{"full_name": "Amr Abou El Enien"}'::jsonb);
        
        INSERT INTO public.user_profiles (id, email, first_name, last_name, role, is_profile_completed)
        VALUES (v_amr_id, 'amraboulenein@yahoo.com', 'Amr', 'Abou El Enien', 'landlord', true);
    ELSE
        SELECT id INTO v_amr_id FROM auth.users WHERE email = 'amraboulenein@yahoo.com';
    END IF;

    -- Asmaa Elkhatib (asmaa.elkhatib@gmail.com)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'asmaa.elkhatib@gmail.com') THEN
        v_asmaa_id := gen_random_uuid();
        INSERT INTO auth.users (id, email, password, email_confirmed_at, role, raw_user_meta_data)
        VALUES (v_asmaa_id, 'asmaa.elkhatib@gmail.com', crypt('123456', gen_salt('bf')), now(), 'authenticated', '{"full_name": "Asmaa Elkhatib"}'::jsonb);
        
        INSERT INTO public.user_profiles (id, email, first_name, last_name, role, is_profile_completed)
        VALUES (v_asmaa_id, 'asmaa.elkhatib@gmail.com', 'Asmaa', 'Elkhatib', 'landlord', true);
    ELSE
        SELECT id INTO v_asmaa_id FROM auth.users WHERE email = 'asmaa.elkhatib@gmail.com';
    END IF;

    -- Samy Negm (samynegm@torath-co.com)
    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'samynegm@torath-co.com') THEN
        v_samy_id := gen_random_uuid();
        INSERT INTO auth.users (id, email, password, email_confirmed_at, role, raw_user_meta_data)
        VALUES (v_samy_id, 'samynegm@torath-co.com', crypt('123456', gen_salt('bf')), now(), 'authenticated', '{"full_name": "Samy Negm"}'::jsonb);
        
        INSERT INTO public.user_profiles (id, email, first_name, last_name, role, is_profile_completed)
        VALUES (v_samy_id, 'samynegm@torath-co.com', 'Samy', 'Negm', 'landlord', true);
    ELSE
        SELECT id INTO v_samy_id FROM auth.users WHERE email = 'samynegm@torath-co.com';
    END IF;


    -- 2. Assign Properties (Using ILIKE for partial matching against previously inserted data)
    
    -- Mohamed Ibrahim -> Joubal Flowery, Joubal Terrace, Ancient Sand
    UPDATE properties 
    SET landlord_id = v_mohamed_id 
    WHERE name ILIKE '%Joubal Flowery%' 
       OR name ILIKE '%Joubal Terrace%' 
       OR name ILIKE '%Ancient Sand%'
       OR name ILIKE '%Ancient Sands%';  -- Covering potential scraper naming

    -- Samia Atef -> Cozy Lagoons Terrace one ensuite apt
    UPDATE properties 
    SET landlord_id = v_samia_id 
    WHERE name ILIKE '%Cozy Lagoons%' 
       OR name ILIKE '%Cozy Lagoon%';

    -- Ahmed Toofik -> Sabina El Lagoons Paradise
    UPDATE properties 
    SET landlord_id = v_ahmed_id 
    WHERE name ILIKE '%Sabina El Lagoons%' 
       OR name ILIKE '%Sabina%';

    -- Amr Abou El Enien -> Townhome beautiful 3 master
    UPDATE properties 
    SET landlord_id = v_amr_id 
    WHERE name ILIKE '%Townhome beautiful%' 
       OR name ILIKE '%3 master%';

    -- Samy Negm (Managed) -> Six Ensuite Amazing 5 Master
    -- (Note: The user mentioned both Asmaa and Samy, identifying Samy as 'manage' and assigned. 
    -- We assign ownership to Samy for now. If Asmaa needs access, we'd need a co-hosting table 
    -- or shared login, but standard schema usually has 1 landlord_id).
    UPDATE properties 
    SET landlord_id = v_samy_id 
    WHERE name ILIKE '%Six Ensuite%' 
       OR name ILIKE '%5 Master%';

END $$;
