-- Add ical_url column to properties table
ALTER TABLE properties ADD COLUMN IF NOT EXISTS ical_url TEXT;

-- Add checking for valid URL format
ALTER TABLE properties ADD CONSTRAINT valid_ical_url CHECK (
  ical_url IS NULL OR ical_url ~* '^https?://.*\.ics(\?.*)?$'
);

-- Make guest_id nullable to support external bookings
ALTER TABLE bookings ALTER COLUMN guest_id DROP NOT NULL;

-- Make total_price nullable as iCalendar doesn't provide it
ALTER TABLE bookings ALTER COLUMN total_price DROP NOT NULL;

-- Make check_out nullable just in case (though iCal usually has it)
-- Keeping check_in/check_out NOT NULL for now as they are essential for booking.
