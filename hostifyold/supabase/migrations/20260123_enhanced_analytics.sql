-- Enhanced Analytics with Booking Source Tracking and Property Ratings
CREATE OR REPLACE FUNCTION get_landlord_analytics(
  p_landlord_id UUID,
  p_start_date DATE DEFAULT DATE_TRUNC('year', CURRENT_DATE)::DATE,
  p_end_date DATE DEFAULT DATE_TRUNC('year', CURRENT_DATE)::DATE + INTERVAL '1 year' - INTERVAL '1 day'
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
  v_bookings_by_source JSONB;
  v_property_ratings JSONB;
  v_most_booked_property TEXT;
  v_most_booked_count INTEGER := 0;
  v_app_bookings INTEGER := 0;
  v_ical_bookings INTEGER := 0;
  v_total_days INTEGER;
  v_property_count INTEGER;
BEGIN
  -- Validate dates
  IF p_start_date IS NULL THEN p_start_date := DATE_TRUNC('year', CURRENT_DATE)::DATE; END IF;
  IF p_end_date IS NULL THEN p_end_date := DATE_TRUNC('year', CURRENT_DATE)::DATE + INTERVAL '1 year' - INTERVAL '1 day'; END IF;
  
  v_total_days := (p_end_date - p_start_date) + 1;
  IF v_total_days <= 0 THEN v_total_days := 1; END IF;

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
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date;

  -- 3. Average Rating (Overall for all properties)
  SELECT COALESCE(AVG(overall_rating), 0)
  INTO v_avg_rating
  FROM reviews r
  JOIN properties p ON r.property_id = p.id
  WHERE p.landlord_id = p_landlord_id;

  -- 4. Occupancy Rate
  IF v_property_count > 0 THEN
    SELECT 
      COALESCE((SUM(nights)::DECIMAL / (v_property_count * v_total_days)) * 100, 0)
    INTO v_occupancy_rate
    FROM bookings b
    JOIN properties p ON b.property_id = p.id
    WHERE p.landlord_id = p_landlord_id
      AND b.status IN ('confirmed', 'completed', 'active')
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date;
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
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY DATE_TRUNC('month', b.check_in)
    ORDER BY DATE_TRUNC('month', b.check_in)
  ) m;

  -- 6. Bookings by Unit WITH count
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
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY p.name
    ORDER BY booking_count DESC
    LIMIT 10
  ) u;

  -- 6b. Get Most Booked Property
  SELECT p.name, COUNT(*) INTO v_most_booked_property, v_most_booked_count
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date
  GROUP BY p.id, p.name
  ORDER BY COUNT(*) DESC
  LIMIT 1;

  -- 7. Bookings by Source (App vs iCal)
  SELECT 
    COUNT(*) FILTER (WHERE b.booking_source = 'hostify'),
    COUNT(*) FILTER (WHERE b.booking_source != 'hostify')
  INTO v_app_bookings, v_ical_bookings
  FROM bookings b
  JOIN properties p ON b.property_id = p.id
  WHERE p.landlord_id = p_landlord_id
    AND b.status IN ('confirmed', 'completed', 'active')
    AND b.check_in >= p_start_date AND b.check_in <= p_end_date;

  -- Build source breakdown
  v_bookings_by_source := jsonb_build_object(
    'app_bookings', v_app_bookings,
    'ical_bookings', v_ical_bookings
  );

  -- 8. Bookings by Nationality/Source
  SELECT jsonb_object_agg(COALESCE(nationality, 'Unknown'), count)
  INTO v_bookings_by_nationality
  FROM (
      SELECT 
        CASE 
          WHEN b.booking_source = 'airbnb' THEN 'Airbnb'
          WHEN b.booking_source = 'booking_com' THEN 'Booking.com'
          ELSE 'Hostify App' 
        END as nationality,
        COUNT(*) as count
      FROM bookings b
      JOIN properties p ON b.property_id = p.id
      WHERE p.landlord_id = p_landlord_id
        AND b.check_in >= p_start_date AND b.check_in <= p_end_date
      GROUP BY nationality
  ) n;
  
  -- 9. Bookings by Guest Type
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
        AND b.check_in >= p_start_date AND b.check_in <= p_end_date
      GROUP BY guest_type
  ) g;

  -- 10. Property Ratings (Average rating per property)
  SELECT jsonb_object_agg(property_name, avg_rating)
  INTO v_property_ratings
  FROM (
    SELECT 
      p.name as property_name,
      ROUND(COALESCE(AVG(r.overall_rating), 0), 1) as avg_rating
    FROM properties p
    LEFT JOIN reviews r ON r.property_id = p.id
    WHERE p.landlord_id = p_landlord_id AND p.status = 'active'
    GROUP BY p.id, p.name
    ORDER BY avg_rating DESC
  ) pr;

  RETURN jsonb_build_object(
    'total_revenue', v_total_revenue,
    'total_bookings', v_total_bookings,
    'occupancy_rate', ROUND(v_occupancy_rate, 1),
    'avg_rating', ROUND(v_avg_rating, 1),
    'revenue_by_month', COALESCE(v_revenue_by_month, '{}'::jsonb),
    'bookings_by_unit', COALESCE(v_bookings_by_unit, '{}'::jsonb),
    'bookings_by_nationality', COALESCE(v_bookings_by_nationality, '{}'::jsonb),
    'bookings_by_guest_type', COALESCE(v_bookings_by_guest_type, '{}'::jsonb),
    'bookings_by_source', v_bookings_by_source,
    'property_ratings', COALESCE(v_property_ratings, '{}'::jsonb),
    'most_booked_property', v_most_booked_property,
    'most_booked_count', v_most_booked_count,
    'app_bookings', v_app_bookings,
    'ical_bookings', v_ical_bookings
  );
END;
$$;
