-- Make guest_id nullable in bookings table to support iCal/External sync
-- External bookings don't have a corresponding user_profile record initially.

ALTER TABLE IF EXISTS public.bookings 
ALTER COLUMN guest_id DROP NOT NULL;

-- Also ensure total_price can be updated (already is)
-- And ensure nights can be updated (already is)
