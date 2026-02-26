-- Production Cleanup Script
-- Clears all dummy/transactional data while preserving Properties and Users.

BEGIN;

-- 1. Bookings
-- Deletes all bookings. If you have historical data you want to keep, exclude them here.
-- For a fresh production start, we wipe everything.
DELETE FROM bookings;

-- 2. Expenses
DELETE FROM expenses;

-- 3. Notifications
DELETE FROM notifications;

-- 4. Reviews
DELETE FROM reviews;

-- 5. Pricing Rules
-- Wipes any test holiday rules created during development.
DELETE FROM property_pricing_rules;

-- 6. Integrity Checks (Optional - just ensuring no orphans remain)
-- These should return 0 rows if FKs are working.
DO $$
BEGIN
    -- Check for orphaned bookings (should be impossible due to FKs)
    IF EXISTS (SELECT 1 FROM bookings WHERE property_id NOT IN (SELECT id FROM properties)) THEN
        RAISE EXCEPTION 'Orphaned bookings found!';
    END IF;
END $$;

COMMIT;
