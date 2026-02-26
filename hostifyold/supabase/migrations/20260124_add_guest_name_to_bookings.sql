-- Add guest_name column to bookings table to store name strings
-- This supports iCal imports and historical backfills where a guest UUID doesn't exist.

ALTER TABLE IF EXISTS public.bookings 
ADD COLUMN IF NOT EXISTS guest_name TEXT;

COMMENT ON COLUMN public.bookings.guest_name IS 'Stores the guest name as a string for external/historical bookings.';
