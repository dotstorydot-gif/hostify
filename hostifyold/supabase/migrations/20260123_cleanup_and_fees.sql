-- 1. Wipe old "Imported" bookings so they can be re-synced with REAL Price logic
DELETE FROM bookings WHERE external_booking_id IS NOT NULL;

-- 2. Ensure Management Fee is 15% for ALL properties
-- First, ensure settings exist for all properties
INSERT INTO property_settings (property_id, management_fee_percentage)
SELECT id, 15
FROM properties
WHERE id NOT IN (SELECT property_id FROM property_settings);

-- Update existing to 15% (User requested "managment fees is 15%")
UPDATE property_settings SET management_fee_percentage = 15;

-- 3. Validation
-- Check that we have settings
SELECT count(*) FROM property_settings;
