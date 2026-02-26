-- Add favorites table and update search_properties RPC for full image support

-- 1. Create Favorites Table
CREATE TABLE IF NOT EXISTS public.favorites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    property_id UUID NOT NULL REFERENCES public.properties(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, property_id)
);

-- Enable RLS for favorites
ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own favorites"
    ON public.favorites
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- 2. Update search_properties RPC to return all images
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
  images JSONB, -- Added for carousel support
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
    COALESCE(
      (
        SELECT jsonb_agg(pi.image_url ORDER BY pi.is_primary DESC, pi.created_at DESC)
        FROM property_images pi
        WHERE pi.property_id = p.id
      ),
      '[]'::jsonb
    ) as images,
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
