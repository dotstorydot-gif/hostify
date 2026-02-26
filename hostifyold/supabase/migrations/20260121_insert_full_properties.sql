-- Full Batch Insert for .Hostify Properties (With Reviews, Prices, iCal, Rules)

DO $$
DECLARE
  v_landlord_id UUID;
  v_property_id UUID;
BEGIN
  -- 1. Find a user to assign the properties to
  SELECT user_id INTO v_landlord_id FROM user_roles WHERE role IN ('landlord', 'admin') LIMIT 1;
  IF v_landlord_id IS NULL THEN
    SELECT id INTO v_landlord_id FROM user_profiles LIMIT 1;
  END IF;

  IF v_landlord_id IS NULL THEN
    RAISE NOTICE 'No users found. Skipping batch insertion.';
    RETURN;
  END IF;

  RAISE NOTICE 'Assigning properties to Landlord ID: %', v_landlord_id;

  -- ==================================================================================
  -- PROPERTY 1: Hostify Boutique Stays exclusive six-Ensuite villa
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Boutique Stays exclusive six-Ensuite villa', 
    'Discover your perfect getaway at this modern, family-friendly ensuite villa in Gouna. With 6 beautifully designed ensuite rooms and 13 beds, this spacious retreat comfortably accommodates up to 14 guests. Enjoy the convenience of Wi-Fi, air conditioning, and a private pool, all while having direct access to the beach.', 
    'Hurghada, Egypt', 
    19226.00, 
    6, 7, 14, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "14 guests maximum", "No smoking", "No parties or events"]',
    'https://www.airbnb.com/calendar/ical/1205577888115430184.ics?t=c23a2077f3d141f2a3534db94823f6c5'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/e868e8cb-a998-4c60-b1cc-41e7d7dd4f9c.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1205577888115430184/original/53eb0e8d-88b1-4bff-9ef6-f1b1b1810b84.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/7f4059c0-ace3-4a35-875c-a45a8176ffd9.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIwNTU3Nzg4ODExNTQzMDE4NA%3D%3D/original/05587a77-6788-4202-b500-e87275c0e4d8.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Beach access'), (v_property_id, 'Kitchen'), (v_property_id, 'Wifi'), (v_property_id, 'Pool'), (v_property_id, 'AC');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Dolgorsuren', 5.0, 'Thank you for the stay, we really appreciate it', '2025-11-01', 'airbnb', 'published'),
  (v_property_id, 'Jeewan', 5.0, 'Hostify''s team is responsive and goes out of their way... property is well looked after and very spacious.', '2025-04-15', 'airbnb', 'published'),
  (v_property_id, 'Reem', 5.0, 'Amazing place for a girls trip, everything was super clean & the host was super supportive.', '2025-04-10', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 2: Hostify Stays, Beautiful 3 master suite
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Beautiful 3 master suite', 
    'Beautiful townhouse with 3 bedrooms with en-suite bathrooms. Spacious, modern and fully air conditioned. Private backyard overlooking a secluded swimming pool, perfect for BBQ parties.', 
    'Mangroovy, El Gouna, Hurghada, Egypt', 
    4392.00, 
    3, 3, 6, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "6 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/654798193009493642.ics?t=d53177f96e3b4136ab00d209f53b0777'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-654798193009493642/original/ac32045e-1b1e-4a87-ae30-353322ccf8e7.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-654798193009493642/original/48586a77-e1f8-4cb6-961b-3c2869b60333.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-654798193009493642/original/6d8e3be7-dd92-4104-9fc1-31e435cabe59.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Private pool'), (v_property_id, 'BBQ grill'), (v_property_id, 'Satellite TV'), (v_property_id, 'AC'), (v_property_id, 'Modern Kitchen');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Ahmed', 5.0, 'I had a wonderful stay... impeccably clean, and the host was extremely helpful.', '2025-07-20', 'airbnb', 'published'),
  (v_property_id, 'Abdulkarim', 5.0, 'The place was amazing, the host was super respectful and helpful, best place to stay in Gouna.', '2025-06-15', 'airbnb', 'published'),
  (v_property_id, 'Walaa', 5.0, 'Love the place and definitely will come back', '2025-08-01', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 3: Hostify Stays, Lagoons Paradise 3 ensuite Villa
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Lagoons Paradise 3 ensuite Villa', 
    'Unwind with the whole family in this one-of-a-kind villa escape. Featuring 3 spacious bedrooms and 4 modern bathrooms. Enjoy your own heated private pool, soak in the stunning lagoon, and head up to the rooftop for breathtaking panoramas.', 
    'Hurghada, Red Sea Governorate, Egypt', 
    4392.00, 
    3, 4, 6, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "6 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/1201424829004326414.ics?t=71802124739c4d33bf2fc68b0aa9c5e0'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/426b7e4e-5920-41e6-89b5-7ca2fe6a74c4.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/1f09a808-c881-4bf4-8d9d-99d46eda2dfc.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/1173149d-186a-4bd7-ad74-b57d4498a200.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Heated private pool'), (v_property_id, 'Lagoon access'), (v_property_id, 'Rooftop terrace'), (v_property_id, 'Kitchen'), (v_property_id, 'Wifi');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Sandy', 5.0, 'The place is absolutely perfect', '2025-09-10', 'airbnb', 'published'),
  (v_property_id, 'Nada', 5.0, 'Definitely not the last, i will back for sure', '2025-06-25', 'airbnb', 'published'),
  (v_property_id, 'Menna', 4.0, 'The house was exactly as described... entrance was stunning, and the heated pool was clean.', '2024-11-15', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 4: Hostify Stays, Amazing 5 master suite &private pool
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Amazing 5 master suite &private pool', 
    'Gorgeous, spacious Villa with 5 large master suites, each with a private bathroom. Boasting a large bright shared living area. Continental breakfast is offered during your stay. Private pool is working and heated.', 
    'El Gouna, Red Sea, Egypt', 
    19226.00, 
    5, 6, 12, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "12 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/49731914.ics?t=a0407bea4fa14b77b07ac659a8d02da2'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6NDk3MzE5MTQ%3D/original/0c8b8541-4ed9-45c6-bfab-58f44e981f43.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6NDk3MzE5MTQ%3D/original/2cb0aa6a-8fa8-415f-8368-60259c6f421c.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-49731914/original/153522aa-9bfe-4784-be20-5aaf985d4856.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Heated private pool'), (v_property_id, 'Breakfast'), (v_property_id, 'Smart TV'), (v_property_id, 'Wifi'), (v_property_id, 'Kitchen');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Ali Mohamed', 5.0, 'Great place! Host was very helpful, they even provided breakfast everyday... 100% recommend', '2025-04-20', 'airbnb', 'published'),
  (v_property_id, 'Omar', 5.0, 'Great hospitality', '2025-11-05', 'airbnb', 'published'),
  (v_property_id, 'Salma', 5.0, 'Amazing stay! The host was more than helpful.', '2025-05-12', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 5: Hostify Stays, Ancient sands apartment
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Ancient sands apartment', 
    'Charming apartment features a spacious living room, a serene bedroom with a king bed, and a private bathroom. Step outside to enjoy the refreshing outdoor pool or relax on the balcony overlooking the beautiful garden.', 
    'Ancient Sands, El Gouna, Hurghada, Egypt', 
    3000.00, 
    1, 1, 2, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "2 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/1221851202816912686.ics?t=28c6ed3e8cf24b18a05dc2ccf8d8c045'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTIwMjgxNjkxMjY4Ng%3D%3D/original/dc2b2155-431d-4cdb-8694-5cc48e416b48.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTIwMjgxNjkxMjY4Ng%3D%3D/original/b1b855e2-5e17-4520-be2e-9cd1882c11df.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTIwMjgxNjkxMjY4Ng%3D%3D/original/10673fdc-9801-4941-a15c-ee5b89899796.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Outdoor pool'), (v_property_id, 'Balcony'), (v_property_id, 'Garden view'), (v_property_id, 'Wifi'), (v_property_id, 'AC');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Sherif', 5.0, 'Very good service and place', '2025-03-20', 'airbnb', 'published'),
  (v_property_id, 'Seif', 4.0, 'Felt like im in jail or something with all the rules... Gouna is more fresh than this.', '2025-11-20', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 6: Hostify Stays, Cozy lagoons terrace one ensuite Apt
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Cozy lagoons terrace one ensuite Apt', 
    'Serene Desert & Sea Retreat. Well-appointed one bedroom apartment ideal for solo travelers or couples. Access to a shared pool and a beautiful lagoon.', 
    'El Gouna Town, Hurghada, Egypt', 
    3000.00, 
    1, 1, 2, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "2 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/1201421151875080576.ics?t=01b50ea5250f4a17bb20da5d35ddac1b'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1201421151875080576/original/1e8f294f-227d-4f18-a9d4-c1a00e752749.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1201421151875080576/original/23ce0134-6702-415f-96b5-06d841624b7e.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1201421151875080576/original/7af75e83-5076-43e8-92c0-9463771fd234.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Shared pool'), (v_property_id, 'Lagoon access'), (v_property_id, 'Private terrace'), (v_property_id, 'Wifi'), (v_property_id, 'AC');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Rana', 5.0, 'Everything was perfect really enjoyed', '2026-01-10', 'airbnb', 'published'),
  (v_property_id, 'Yomna', 5.0, 'Great Stay. The breakfast was a cute gesture', '2025-11-25', 'airbnb', 'published'),
  (v_property_id, 'Nicola', 5.0, 'Very nice apartment... espectacular view of the lagoon from the balcony.', '2026-01-05', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 7: Hostify Stays, Joubal Lagoons flowery apartment
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Joubal Lagoons flowery apartment', 
    'Stylish two-bedroom apartment features two king-sized beds, two modern bathrooms, and direct access to both a stunning lagoon and a refreshing pool. Private terrace offering beautiful lagoon views.', 
    'Joubal, El Gouna, Hurghada, Egypt', 
    5000.00, 
    2, 2, 4, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "4 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/1241398079884516470.ics?t=3a26a8163ccc4515927a953c16795442'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTI0MTM5ODA3OTg4NDUxNjQ3MA%3D%3D/original/78c90e20-1048-435b-91d7-a2a8ce70bfe0.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTI0MTM5ODA3OTg4NDUxNjQ3MA%3D%3D/original/c1e518c2-fb81-4d05-86cb-80aa8faef7f6.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTI0MTM5ODA3OTg4NDUxNjQ3MA%3D%3D/original/524b0b23-736c-44ac-9161-b400eff3fe66.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Pool access'), (v_property_id, 'Lagoon access'), (v_property_id, 'Private terrace'), (v_property_id, 'Wifi'), (v_property_id, 'AC');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Kazem', 5.0, 'Excellent stay. Hosts are great, highly communicative and accommodating.', '2025-09-15', 'airbnb', 'published'),
  (v_property_id, 'Lobna', 5.0, 'Spacious and very well furnished... Host is very responsive, friendly and helpful.', '2025-06-18', 'airbnb', 'published'),
  (v_property_id, 'Tarek', 5.0, 'Hostify was a great host... place was clean and close to the Marina.', '2025-04-22', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 8: Hostify Stays, Joubal Lagoons Terrace
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Joubal Lagoons Terrace', 
    'Stylish one ensuite bedroom apartment features one king-sized bed, two modern bathrooms, and direct access to both a stunning lagoon and a refreshing pool. Enjoy open-plan living with a private terrace.', 
    'Joubal, El Gouna, Hurghada, Egypt', 
    3000.00, 
    1, 2, 2, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "2 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/1221851263422286554.ics?t=a26d9369451d48fe8c515a781508cabb'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTI2MzQyMjI4NjU1NA%3D%3D/original/bde0969d-e75e-493b-8c1d-fd8130c599ae.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1221851263422286554/original/2632a115-0db7-4725-85b1-f618c52d7c1f.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1221851263422286554/original/b2937305-e868-4ac7-b591-331120a4ea77.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Lagoon access'), (v_property_id, 'Shared pool'), (v_property_id, 'Private terrace'), (v_property_id, 'Wifi'), (v_property_id, 'AC');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'May', 5.0, 'Really like the location, hygiene, pool with lagoon view, and nice staff.', '2025-10-10', 'airbnb', 'published'),
  (v_property_id, 'Laura', 5.0, 'Loved my stay... service was top tier, host always easily reachable.', '2025-12-05', 'airbnb', 'published'),
  (v_property_id, 'Mina', 5.0, 'Communication was smooth and professional... place exactly as described.', '2025-05-18', 'airbnb', 'published');


  -- ==================================================================================
  -- PROPERTY 9: Hostify Stays, Luxurious Sea View, F.Marina Apt.
  -- ==================================================================================
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status, house_rules, ical_url)
  VALUES (v_landlord_id, 
    'Hostify Stays, Luxurious Sea View, F.Marina Apt.', 
    'Stunning sea and marina views. Elegantly furnished, it features a spacious bedroom with a king-sized bed and two attached private bathrooms. Reception area is inviting, equipped with air conditioning and high-speed Wi-Fi.', 
    'Abu Tig Marina, El Gouna, Hurghada, Egypt', 
    3000.00, 
    1, 2, 2, 
    'active', 
    '["Check-in after 3:00 PM", "Checkout before 11:00 AM", "2 guests maximum"]',
    'https://www.airbnb.com/calendar/ical/1221851508955306715.ics?t=791e63a09fb2437bb03cd6a6ef5fd3e4'
  ) RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTUwODk1NTMwNjcxNQ%3D%3D/original/3acd8228-a01d-4e83-a849-c5207b7ee620.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTUwODk1NTMwNjcxNQ%3D%3D/original/4a9ce659-2e39-4560-a001-cc36a39c2bc1.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTUwODk1NTMwNjcxNQ%3D%3D/original/52d77af7-d128-491e-8324-a34d425d2c92.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Sea view'), (v_property_id, 'Marina view'), (v_property_id, 'Wifi'), (v_property_id, 'AC'), (v_property_id, 'Elevator');

  INSERT INTO reviews (property_id, guest_name, overall_rating, review_text, review_date, source, status) VALUES
  (v_property_id, 'Aleksandra', 5.0, 'Perfect location... perfect marina view and the host replies in few minutes.', '2026-01-12', 'airbnb', 'published'),
  (v_property_id, 'Hanan', 5.0, 'Outstanding location in the new marina... unit was clean and well arranged.', '2025-12-20', 'airbnb', 'published'),
  (v_property_id, 'Julia', 5.0, 'Beautiful and modern flat... communication was super easy and responsive.', '2025-09-08', 'airbnb', 'published');

  RAISE NOTICE 'Full batch insertion completed successfully.';
END $$;
