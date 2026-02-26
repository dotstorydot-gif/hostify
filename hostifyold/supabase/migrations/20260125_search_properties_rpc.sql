-- Create search_properties RPC function for property search with availability filtering
-- This function searches for properties based on location, dates, and guest requirements
-- It excludes properties that are already booked during the requested dates

CREATE OR REPLACE FUNCTION public.search_properties(
  check_in_date DATE DEFAULT NULL,
  check_out_date DATE DEFAULT NULL,
  location_query TEXT DEFAULT NULL,
  min_guests INTEGER DEFAULT 1,
  min_rooms INTEGER DEFAULT 1
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  description TEXT,
  location TEXT,
  price_per_night NUMERIC,
  bedrooms INTEGER,
  bathrooms INTEGER,
  max_guests INTEGER,
  amenities JSONB,
  image TEXT,
  rating NUMERIC,
  landlord_id UUID,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.name,
    p.description,
    p.location,
    p.price_per_night,
    p.bedrooms,
    p.bathrooms,
    p.max_guests,
    COALESCE(
      (
        SELECT jsonb_agg(pa.amenity)
        FROM property_amenities pa
        WHERE pa.property_id = p.id
      ),
      '[]'::jsonb
    ) as amenities,
    (
        SELECT image_url
        FROM property_images pi
        WHERE pi.property_id = p.id
        ORDER BY pi.is_primary DESC, pi.created_at DESC
        LIMIT 1
    ) as image,
    (
        SELECT COALESCE(AVG(r.overall_rating), 0)
        FROM reviews r
        WHERE r.property_id = p.id
    ) as rating,
    p.landlord_id,
    p.created_at,
    p.updated_at
  FROM properties p
  WHERE 
    -- Location filter (if provided)
    (location_query IS NULL OR p.location ILIKE '%' || location_query || '%')
    
    -- Guest capacity filter
    AND p.max_guests >= min_guests
    
    -- Bedroom filter
    AND p.bedrooms >= min_rooms
    
    -- Availability filter: exclude properties with overlapping bookings
    AND (
      check_in_date IS NULL 
      OR check_out_date IS NULL
      OR NOT EXISTS (
        SELECT 1 
        FROM bookings b
        WHERE b.property_id = p.id
          AND b.status IN ('confirmed', 'pending')
          AND (
            -- Check for date overlap
            (b.check_in <= check_out_date AND b.check_out >= check_in_date)
          )
      )
    )
  ORDER BY rating DESC, p.created_at DESC;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.search_properties TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_properties TO anon;

COMMENT ON FUNCTION public.search_properties IS 'Search for available properties based on location, dates, and guest requirements. Automatically excludes booked properties during the requested dates.';
