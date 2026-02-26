-- Add discount columns to properties table
-- Weekly discount: applied to bookings with 7+ nights
-- Monthly discount: applied to bookings with 28+ nights

ALTER TABLE properties 
ADD COLUMN IF NOT EXISTS weekly_discount_percent DECIMAL(5, 2) DEFAULT 15.0,
ADD COLUMN IF NOT EXISTS monthly_discount_percent DECIMAL(5, 2) DEFAULT 60.0;

COMMENT ON COLUMN properties.weekly_discount_percent IS 'Percentage discount for bookings of 7+ nights';
COMMENT ON COLUMN properties.monthly_discount_percent IS 'Percentage discount for bookings of 28+ nights';

-- Update the specific property with the requested discounts
UPDATE properties 
SET weekly_discount_percent = 15.0, 
    monthly_discount_percent = 60.0
WHERE ical_url = 'https://www.airbnb.com/calendar/ical/49731914.ics?t=a0407bea4fa14b77b07ac659a8d02da2';
