-- Batch Insert Scraped Airbnb Properties
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

  -- PROPERTY 1: Hostify Stays, Lagoons Paradise 3 ensuite Villa
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Lagoons Paradise 3 ensuite Villa', 'Unwind with the whole family in this one-of-a-kind villa escape. Featuring 3 spacious bedrooms (2 king beds and 2 double beds) and 4 modern bathrooms, this home is designed for comfort and style. Enjoy your own heated private pool, soak in the stunning lagoon, and head up to the rooftop for breathtaking panoramas you won’t forget.', 'Hurghada, Red Sea Governorate, Egypt', 450.00, 3, 4, 6, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/426b7e4e-5920-41e6-89b5-7ca2fe6a74c4.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/1f09a808-c881-4bf4-8d9d-99d46eda2dfc.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/1173149d-186a-4bd7-ad74-b57d4498a200.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/c6c4f745-9d49-4d80-a6f0-55e01d586bc4.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1201424829004326414/original/70fe4583-04e4-44cd-9f7a-8b8359b3a971.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Heated private pool'), (v_property_id, 'Lagoon access'), (v_property_id, 'Rooftop terrace'), (v_property_id, 'Kitchen'), (v_property_id, 'Wifi');

  -- PROPERTY 2: Hostify Stays, Amazing 5 master suite &private pool
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Amazing 5 master suite &private pool', 'Gorgeous, spacious Villa with 5 large master suites, each with a private bathroom. Boasting a large bright shared living area. Continental breakfast is offered during your stay. Private pool is working and heated.', 'El Gouna, Red Sea, Egypt', 650.00, 5, 6, 10, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6NDk3MzE5MTQ%3D/original/0c8b8541-4ed9-45c6-bfab-58f44e981f43.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6NDk3MzE5MTQ%3D/original/2cb0aa6a-8fa8-415f-8368-60259c6f421c.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6NDk3MzE5MTQ%3D/original/e5d262d3-9dbe-46d2-900e-455c054cfdde.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-49731914/original/153522aa-9bfe-4784-be20-5aaf985d4856.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Heated private pool'), (v_property_id, 'Breakfast'), (v_property_id, 'Smart TV'), (v_property_id, 'Wifi'), (v_property_id, 'Kitchen');


  -- PROPERTY 3: Hostify Stays, Ancient sands apartment
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Ancient sands apartment', 'Charming apartment features a spacious living room, a serene bedroom with a king bed, and a private bathroom. Step outside to enjoy the refreshing outdoor pool or relax on the balcony overlooking the beautiful garden.', 'Ancient Sands, El Gouna, Hurghada, Egypt', 200.00, 1, 1, 2, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTIwMjgxNjkxMjY4Ng%3D%3D/original/dc2b2155-431d-4cdb-8694-5cc48e416b48.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTIwMjgxNjkxMjY4Ng%3D%3D/original/b1b855e2-5e17-4520-be2e-9cd1882c11df.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTIwMjgxNjkxMjY4Ng%3D%3D/original/10673fdc-9801-4941-a15c-ee5b89899796.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Outdoor pool'), (v_property_id, 'Balcony'), (v_property_id, 'Garden view'), (v_property_id, 'Wifi'), (v_property_id, 'AC');


  -- PROPERTY 4: Hostify Stays, Beautiful 3 master suite
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Beautiful 3 master suite', 'Beautiful townhouse with 3 bedrooms with en-suite bathrooms. Spacious, modern and fully air conditioned. Private backyard overlooking a secluded swimming pool, perfect for BBQ parties.', 'Mangroovy, El Gouna, Hurghada, Egypt', 400.00, 3, 3, 6, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-654798193009493642/original/ac32045e-1b1e-4a87-ae30-353322ccf8e7.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-654798193009493642/original/48586a77-e1f8-4cb6-961b-3c2869b60333.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-654798193009493642/original/6d8e3be7-dd92-4104-9fc1-31e435cabe59.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Private pool'), (v_property_id, 'BBQ grill'), (v_property_id, 'Satellite TV'), (v_property_id, 'AC'), (v_property_id, 'Modern Kitchen');


  -- PROPERTY 5: Hostify Stays, Cozy lagoons terrace one ensuite Apt
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Cozy lagoons terrace one ensuite Apt', 'Serene Desert & Sea Retreat. Well-appointed one bedroom apartment ideal for solo travelers or couples. Access to a shared pool and a beautiful lagoon. Private terrace overlooking calm lagoons.', 'El Gouna Town, Hurghada, Egypt', 180.00, 1, 1, 2, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1201421151875080576/original/1e8f294f-227d-4f18-a9d4-c1a00e752749.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1201421151875080576/original/23ce0134-6702-415f-96b5-06d841624b7e.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1201421151875080576/original/7af75e83-5076-43e8-92c0-9463771fd234.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Shared pool'), (v_property_id, 'Lagoon access'), (v_property_id, 'Private terrace'), (v_property_id, 'Wifi'), (v_property_id, 'AC');


  -- PROPERTY 6: Hostify Stays, Joubal Lagoons flowery apartment
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Joubal Lagoons flowery apartment', 'Stylish two-bedroom apartment features two king-sized beds, two modern bathrooms, and direct access to both a stunning lagoon and a refreshing pool. Private terrace offering beautiful lagoon views.', 'Joubal, El Gouna, Hurghada, Egypt', 280.00, 2, 2, 4, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTI0MTM5ODA3OTg4NDUxNjQ3MA%3D%3D/original/78c90e20-1048-435b-91d7-a2a8ce70bfe0.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTI0MTM5ODA3OTg4NDUxNjQ3MA%3D%3D/original/c1e518c2-fb81-4d05-86cb-80aa8faef7f6.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTI0MTM5ODA3OTg4NDUxNjQ3MA%3D%3D/original/524b0b23-736c-44ac-9161-b400eff3fe66.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Pool access'), (v_property_id, 'Lagoon access'), (v_property_id, 'Private terrace'), (v_property_id, 'Wifi'), (v_property_id, 'AC');


  -- PROPERTY 7: Hostify Stays, Joubal Lagoons Terrace
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Joubal Lagoons Terrace', 'Stylish one ensuite bedroom apartment features one king-sized bed, two modern bathrooms, and direct access to both a stunning lagoon and a refreshing pool. Enjoy open-plan living with a private terrace.', 'Joubal, El Gouna, Hurghada, Egypt', 220.00, 1, 2, 2, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTI2MzQyMjI4NjU1NA%3D%3D/original/bde0969d-e75e-493b-8c1d-fd8130c599ae.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-1221851263422286554/original/2632a115-0db7-4725-85b1-f618c52d7c1f.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/miso/Hosting-1221851263422286554/original/b2937305-e868-4ac7-b591-331120a4ea77.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Lagoon access'), (v_property_id, 'Shared pool'), (v_property_id, 'Private terrace'), (v_property_id, 'Wifi'), (v_property_id, 'AC');


  -- PROPERTY 8: Hostify Stays, Luxurious Sea View, F.Marina Apt.
  INSERT INTO properties (landlord_id, name, description, location, price_per_night, bedrooms, bathrooms, max_guests, status)
  VALUES (v_landlord_id, 'Hostify Stays, Luxurious Sea View, F.Marina Apt.', 'Stunning sea and marina views. Elegantly furnished, it features a spacious bedroom with a king-sized bed and two attached private bathrooms. Reception area is inviting, equipped with air conditioning and high-speed Wi-Fi.', 'Abu Tig Marina, El Gouna, Hurghada, Egypt', 320.00, 1, 2, 2, 'active')
  RETURNING id INTO v_property_id;

  INSERT INTO property_images (property_id, image_url, is_primary) VALUES
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTUwODk1NTMwNjcxNQ%3D%3D/original/3acd8228-a01d-4e83-a849-c5207b7ee620.jpeg?im_w=720', true),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTUwODk1NTMwNjcxNQ%3D%3D/original/4a9ce659-2e39-4560-a001-cc36a39c2bc1.jpeg?im_w=720', false),
  (v_property_id, 'https://a0.muscache.com/im/pictures/hosting/Hosting-U3RheVN1cHBseUxpc3Rpbmc6MTIyMTg1MTUwODk1NTMwNjcxNQ%3D%3D/original/52d77af7-d128-491e-8324-a34d425d2c92.jpeg?im_w=720', false);

  INSERT INTO property_amenities (property_id, amenity) VALUES
  (v_property_id, 'Sea view'), (v_property_id, 'Marina view'), (v_property_id, 'Wifi'), (v_property_id, 'AC'), (v_property_id, 'Elevator');

  RAISE NOTICE 'Batch insertion completed successfully.';
END $$;
