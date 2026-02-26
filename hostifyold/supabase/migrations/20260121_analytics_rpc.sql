-- Create RPC for Landlord Analytics
CREATE OR REPLACE FUNCTION get_landlord_analytics(
  p_landlord_id UUID,
  p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_revenue DECIMAL(12, 2) := 0;
  v_total_bookings INTEGER := 0;
  v_occupancy_rate DECIMAL(5, 2) := 0;
  v_avg_rating DECIMAL(3, 2) := 0;
  v_revenue_by_month JSONB;
  v_bookings_by_nationality JSONB;
  v_bookings_by_unit JSONB;
  v_bookings_by_guest_type JSONB;
  v_total_days_in_year INTEGER := 365;
  v_property_count INTEGER;
BEGIN
  -- 1. Get Property Count for the landlord
  SELECT COUNT(*) INTO v_property_count 
  FROM properties 
  WHERE landlord_id = p_landlord_id AND status = 'active';

  -- 2. Total Revenue & Bookings (Confirmed/Completed only)
  SELECT 
    COALESCE(SUM(total_price), 0),
    COUNT(*)
  INTO v_total_revenue, v_total_bookings
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND EXTRACT(YEAR FROM b.check_in) = p_year;

  -- 3. Average Rating
  SELECT COALESCE(AVG(overall_rating), 0)
  INTO v_avg_rating
  FROM reviews r
  JOIN properties p ON r.property_id = p.id
  WHERE p.landlord_id = p_landlord_id;

  -- 4. Occupancy Rate
  -- (Total Nights Booked / (Total Properties * 365)) * 100
  IF v_property_count > 0 THEN
    SELECT 
      COALESCE((SUM(nights)::DECIMAL / (v_property_count * v_total_days_in_year)) * 100, 0)
    INTO v_occupancy_rate
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.status IN ('confirmed', 'completed', 'active')
      AND EXTRACT(YEAR FROM b.check_in) = p_year;
  END IF;

  -- 5. Revenue by Month
  SELECT jsonb_object_agg(to_char(month_date, 'Mon'), revenue)
  INTO v_revenue_by_month
  FROM (
    SELECT 
      DATE_TRUNC('month', b.check_in) as month_date,
      SUM(b.total_price) as revenue
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.status IN ('confirmed', 'completed', 'active')
      AND EXTRACT(YEAR FROM b.check_in) = p_year
    GROUP BY DATE_TRUNC('month', b.check_in)
    ORDER BY DATE_TRUNC('month', b.check_in)
  ) m;

  -- 6. Bookings by Unit
  SELECT jsonb_object_agg(name, booking_count)
  INTO v_bookings_by_unit
  FROM (
    SELECT 
      p.name,
      COUNT(*) as booking_count
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.status IN ('confirmed', 'completed', 'active')
      AND EXTRACT(YEAR FROM b.check_in) = p_year
    GROUP BY p.name
    ORDER BY booking_count DESC
    LIMIT 10
  ) u;

  -- 7. Bookings by Nationality (Mocking logic via joined user_profiles if available, else 'Unknown' or 'External')
  -- Note: Real nationality would require a profile field. For now using 'External' vs 'Internal' or mocking.
  SELECT jsonb_object_agg(COALESCE(nationality, 'Unknown'), count)
  INTO v_bookings_by_nationality
  FROM (
      SELECT 
        CASE 
          WHEN b.booking_source = 'airbnb' THEN 'Airbnb User'
          WHEN b.booking_source = 'booking_com' THEN 'Booking.com User'
          ELSE 'Hostify User' 
        END as nationality,
        COUNT(*) as count
      FROM bookings b
      JOIN properties p ON b.property_id = p.id
      WHERE p.landlord_id = p_landlord_id
        AND EXTRACT(YEAR FROM b.check_in) = p_year
      GROUP BY nationality
  ) n;
  
  -- 8. Bookings by Guest Type (Mock calculation based on guest count)
  SELECT jsonb_object_agg(guest_type, count)
  INTO v_bookings_by_guest_type
  FROM (
      SELECT 
        CASE 
           WHEN max_guests <= 2 THEN 'Couple'
           WHEN max_guests <= 4 THEN 'Small Family'
           ELSE 'Group/Large Family'
        END as guest_type,
        COUNT(*) as count
      FROM bookings b
      JOIN properties p ON b.property_id = p.id
      WHERE p.landlord_id = p_landlord_id
        AND EXTRACT(YEAR FROM b.check_in) = p_year
      GROUP BY guest_type
  ) g;


  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_bookings', v_total_bookings,
    'occupancy_rate', ROUND(v_occupancy_rate, 1),
    'avg_rating', ROUND(v_avg_rating, 1),
    'revenue_by_month', COALESCE(v_revenue_by_month, '{}'::jsonb),
    'bookings_by_unit', COALESCE(v_bookings_by_unit, '{}'::jsonb),
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
    'bookings_by_guest_type', COALESCE(v_bookings_by_guest_type, '{}'::jsonb)
  );
END;
$$;
