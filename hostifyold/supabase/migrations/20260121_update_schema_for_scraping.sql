-- Update schema to support Scraped Data better

-- 1. Add House Rules to Properties (as a JSONB array)
ALTER TABLE properties ADD COLUMN IF NOT EXISTS house_rules JSONB DEFAULT '[]'::jsonb;

-- 2. Allow Reviews without a registered guest (for external reviews)
ALTER TABLE reviews ALTER COLUMN guest_id DROP NOT NULL;

-- 3. Add 'source' to reviews to distinguish external ones
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'hostify' CHECK (source IN ('hostify', 'airbnb', 'booking_com'));

-- 4. Add 'review_date' separate from created_at
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS review_date DATE DEFAULT CURRENT_DATE;

-- 5. Ensure ical_url column exists (if not added by previous migration)
ALTER TABLE properties ADD COLUMN IF NOT EXISTS ical_url TEXT;

-- 6. Add 'date_scraped' to track when external data was fetched
ALTER TABLE properties ADD COLUMN IF NOT EXISTS last_scraped_at TIMESTAMPTZ;
