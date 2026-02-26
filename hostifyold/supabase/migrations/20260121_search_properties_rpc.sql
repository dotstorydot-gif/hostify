-- Function to search properties with availability check
CREATE OR REPLACE FUNCTION search_properties(
  check_in_date DATE DEFAULT NULL,
  check_out_date DATE DEFAULT NULL,
  location_query TEXT DEFAULT NULL,
  min_guests INTEGER DEFAULT NULL,
  min_rooms INTEGER DEFAULT NULL
)
RETURNS SETOF properties
LANGUAGE sql
AS $$
  SELECT *
  FROM properties p
  WHERE
    -- Location Filter
    (location_query IS NULL OR p.location ILIKE '%' || location_query || '%')
    AND
    -- Capacity Filters
    (min_guests IS NULL OR p.max_guests >= min_guests)
    AND
    (min_rooms IS NULL OR p.bedrooms >= min_rooms)
    AND
    -- Availability Filter (Anti-Join on Overlapping Bookings)
    (
      check_in_date IS NULL OR check_out_date IS NULL OR
      NOT EXISTS (
        SELECT 1 FROM bookings b
        WHERE b.property_id = p.id
          AND b.status IN ('confirmed', 'active')
          AND b.check_in < check_out_date
          AND b.check_out > check_in_date
      )
    )
  ORDER BY created_at DESC;
$$;
