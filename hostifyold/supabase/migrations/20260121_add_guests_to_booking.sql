-- Add guests column to bookings table
ALTER TABLE public.bookings
ADD COLUMN guests INTEGER DEFAULT 1;

-- Add comment
COMMENT ON COLUMN public.bookings.guests IS 'Number of guests for this booking';
