-- Insert the scraped Airbnb property
DO $$
DECLARE
  v_landlord_id UUID;
  v_property_id UUID;
BEGIN
  -- 1. Find a user to assign the property to (first landlord, or admin, or just any user)
  SELECT user_id INTO v_landlord_id FROM user_roles WHERE role IN ('landlord', 'admin') LIMIT 1;
  
  -- Fallback: If no role entry found, pick any user from profiles
  IF v_landlord_id IS NULL THEN
    SELECT id INTO v_landlord_id FROM user_profiles LIMIT 1;
  END IF;

  -- If still null (empty DB), we can't insert
  IF v_landlord_id IS NULL THEN
    RAISE NOTICE 'No users found in database. Skipping property insertion.';
    RETURN;
  END IF;

  -- 2. Insert Property
  INSERT INTO properties (
    landlord_id,
    name,
    description,
    location,
    price_per_night,
    bedrooms,
    bathrooms,
    max_guests,
    ical_url, -- Added iCal URL
    status
  ) VALUES (
    v_landlord_id,
    'Hostify Boutique Stays exclusive six-Ensuite villa',
    'Discover your perfect getaway at this modern, family-friendly ensuite villa in Gouna. With 6 beautifully designed ensuite rooms and 13 beds, this spacious retreat comfortably accommodates up to 14 guests. Enjoy the convenience of Wi-Fi, air conditioning, and a private pool, all while having direct access to the beach. Ideal for families and large groups, this villa combines luxury with comfort for an unforgettable stay. Other things to note: Kindly note that the shared pool is currently not working as it is under under construction. However, the private pool is working and heated.',
    'Hurghada, Egypt',
    500.00, -- Placeholder price, update as needed
    6,
    7, -- Rounded up from 6.5
    14,
    'https://www.airbnb.com/calendar/ical/1205577888115430184.ics?t=c23a2077f3d141f2a3534db94823f6c5', -- User provided iCal
    'active'
  ) RETURNING id INTO v_property_id;

  -- 3. Insert Images
  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/e868e8cb-a998-4c60-b1cc-41e7d7dd4f9c.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1205577888115430184/original/53eb0e8d-88b1-4bff-9ef6-f1b1b1810b84.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/7f4059c0-ace3-4a35-875c-a45a8176ffd9.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/05587a77-6788-4202-b500-e87275c0e4d8.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/47ff4265-35a3-43b6-93dd-925ea4981576.jpeg?im_w=720', false);

  -- 4. Insert Amenities
  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Beach access'),
  (v_property_id, 'Kitchen'),
  (v_property_id, 'Wifi'),
  (v_property_id, 'Dedicated workspace'),
  (v_property_id, 'Pool');

  RAISE NOTICE 'Property inserted successfully with ID: %', v_property_id;
END $$;
