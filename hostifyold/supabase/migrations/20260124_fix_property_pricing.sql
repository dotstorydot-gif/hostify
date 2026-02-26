-- Fix Property Base Price and Recalculate Booking Prices
-- This corrects the revenue calculation issue where 9 nights showed $173,034 instead of $2,250

-- Step 1: Update the property's base price to the correct nightly rate
UPDATE properties 
SET price_per_night = 250.00
WHERE ical_url = 'https://www.airbnb.com/calendar/ical/49731914.ics?t=a0407bea4fa14b77b07ac659a8d02da2';

-- Step 2: Recalculate booking prices for all bookings with missing or zero prices
-- This uses the corrected $250/night rate
UPDATE bookings
SET total_price = nights * 250.00
WHERE property_id = (
    SELECT id FROM properties 
    WHERE ical_url = 'https://www.airbnb.com/calendar/ical/49731914.ics?t=a0407bea4fa14b77b07ac659a8d02da2'
)
AND (total_price IS NULL OR total_price = 0 OR total_price > 100000);

-- Step 3: Apply discounts to bookings (7+ nights get 15% off, 28+ nights get 60% off)
-- Only apply to future bookings (2026 onwards) to preserve historical accuracy
UPDATE bookings
SET total_price = CASE
    WHEN nights >= 28 THEN nights * 250.00 * 0.40  -- 60% discount = pay 40%
    WHEN nights >= 7 THEN nights * 250.00 * 0.85   -- 15% discount = pay 85%
    ELSE nights * 250.00
END
WHERE property_id = (
    SELECT id FROM properties 
    WHERE ical_url = 'https://www.airbnb.com/calendar/ical/49731914.ics?t=a0407bea4fa14b77b07ac659a8d02da2'
)
AND check_in >= '2026-01-01'
AND booking_source IN ('airbnb', 'booking_com', 'hostify');

-- Verification query - check January 2026 bookings
SELECT 
    guest_name,
    check_in,
    check_out,
    nights,
    total_price,
    ROUND(total_price / nights, 2) as price_per_night
FROM bookings
WHERE property_id = (
    SELECT id FROM properties 
    WHERE ical_url = 'https://www.airbnb.com/calendar/ical/49731914.ics?t=a0407bea4fa14b77b07ac659a8d02da2'
)
AND check_in >= '2026-01-01' 
AND check_in < '2026-02-01'
ORDER BY check_in;
