-- 1. Update get_landlord_analytics to support Date Range
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

  -- 3. Average Rating
  SELECT COALESCE(AVG(overall_rating), 0)
  INTO v_avg_rating
  FROM reviews r
  JOIN properties p ON r.property_id = p.id
  WHERE p.landlord_id = p_landlord_id;

  -- 4. Occupancy Rate
  -- (Total Nights Booked / (Total Properties * Days in Range)) * 100
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

  -- 5. Revenue by Month (or Day if range is small, but keeping Month for chart consistency)
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
      AND b.check_in >= p_start_date AND b.check_in <= p_end_date
    GROUP BY p.name
    ORDER BY booking_count DESC
    LIMIT 10
  ) u;

  -- 7. Bookings by Nationality (Mocking logic via joined user_profiles if available, else 'Unknown' or 'External')
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
        AND b.check_in >= p_start_date AND b.check_in <= p_end_date
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
        AND b.check_in >= p_start_date AND b.check_in <= p_end_date
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


-- 2. Add Policies for Admins to access ALL user documents
-- Check policy existence before creating to prevent errors
DO $$
BEGIN
    -- Policy for user_documents table: Admin Select
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_documents' AND policyname = 'Admins can view all documents'
    ) THEN
        CREATE POLICY "Admins can view all documents" 
        ON user_documents FOR SELECT 
        USING (
            EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                AND user_profiles.role = 'admin'
            )
        );
    END IF;

    -- Policy for storage.objects: Admin Select
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Admins can view all document objects'
    ) THEN
        CREATE POLICY "Admins can view all document objects" 
        ON storage.objects FOR SELECT 
        USING (
            bucket_id = 'documents' AND
            EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                AND user_profiles.role = 'admin'
            )
        );
    END IF;

      -- Policy for storage.objects: Admin Insert (Upload on behalf)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Admins can upload document objects'
    ) THEN
        CREATE POLICY "Admins can upload document objects" 
        ON storage.objects FOR INSERT 
        WITH CHECK (
            bucket_id = 'documents' AND
            EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                AND user_profiles.role = 'admin'
            )
        );
    END IF;
    
     -- Policy for storage.objects: Admin Delete
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Admins can delete document objects'
    ) THEN
        CREATE POLICY "Admins can delete document objects" 
        ON storage.objects FOR DELETE 
        USING (
            bucket_id = 'documents' AND
            EXISTS (
                SELECT 1 FROM user_profiles
                WHERE user_profiles.id = auth.uid()
                AND user_profiles.role = 'admin'
            )
        );
    END IF;
END $$;
